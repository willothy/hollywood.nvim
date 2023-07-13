local M = {}

---@class Hollywood.Action
---@field title string
---@field type string
---@field source string
local Action = {}
Action.__index = Action
Action.__classname = "Hollywood.Action"

---@param cx string
---@param msg? string
function Action:error(cx, msg)
	local err = string.format("[%s:%s] %s", self.__classname, cx, msg or "Not implemented")
	vim.api.nvim_err_writeln(err)
end

---@param data table
---@return Hollywood.Action
function Action:new(data)
	return setmetatable(data, self)
end

---@param name string
function Action:extend(name)
	local cls = {}
	cls.__index = cls
	cls.__classname = name
	cls.__super = self
	return setmetatable(cls, self)
end

---@return Hollywood.ActionInfo
function Action:describe()
	return {
		title = self.title,
		type = self.type,
		source = self.source,
	}
end

function Action:display()
	local info = self:describe()
	return {
		text = string.format("name: %s\nsource: `%s`\ntype: %s", info.title, info.source, info.type),
		syntax = "",
	}
end

---@param f fun(fmt: { syntax: string, text: string })
function Action:info(f)
	f(self:display())
end

function Action:preview()
	self:error("preview")
end

function Action:execute()
	self:error("execute")
end

---@class Hollywood.CodeAction : Hollywood.Action
---@field edit table
local CodeAction = Action:extend("Hollywood.CodeAction")

function CodeAction:execute()
	if self.edit then
		vim.lsp.util.apply_workspace_edit(self.edit, "utf-8")
	elseif self.data then
		vim.lsp.util.apply_text_edits(self.edit, vim.api.nvim_get_current_buf(), "utf-8")
	end
end

---@class Hollywood.Command : Hollywood.Action
---@field command string
---@field args table
local Command = Action:extend("Hollywood.Command")

function Command:execute()
	vim.lsp.buf.execute_command({
		command = self.command,
		arguments = self.args,
	})
end

---@class Hollywood.Context
---@field cancel fun() Used to cancel async lsp requests
---@field cache_data Hollywood.Action[]
---@field cache_size integer
local Context = {
	cancel = nil,
	cache_data = {},
	cache_size = 0,
}

function Context:cache_clear()
	self.cache_data = {}
	self.cache_size = 0
end

---@return boolean
function Context:cache_is_empty()
	return self.cache_size == 0
end

function Context:cache_save(action)
	table.insert(self.cache_data, action)
	self.cache_size = self.cache_size + 1
end

---@param winnr window
---@param bufnr buffer
---@param line? integer
function Context:make_params(winnr, bufnr, line)
	local ctx = {}
	ctx.diagnostics = vim.diagnostic.get(bufnr, { line = line })
	local params = vim.lsp.util.make_range_params(winnr)
	-- local cursor = vim.api.nvim_win_get_cursor(winnr)
	-- params = vim.lsp.util.make_given_range_params(cursor, cursor, bufnr)
	params.context = ctx
	return params
end

function Context:fetch(background)
	if self.cancel then
		self.cancel()
		self.cancel = nil
	end

	local winnr = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	local line = vim.api.nvim_win_get_cursor(winnr)[1]
	local params = self:make_params(winnr, bufnr, line)

	self.cancel = vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, function(data)
		self:cache_clear()

		for client_id, actions in pairs(data) do
			local client = vim.lsp.get_client_by_id(client_id)

			if client.name == "rust_analyzer" then
				vim.print(actions)
			end
			if actions.result and #actions.result > 0 then
				for _, action in ipairs(actions.result) do
					if action.edit or action.data then
						self:cache_save(CodeAction:new({
							title = action.title,
							type = action.kind,
							source = client.name,
							edit = action.edit,
							data = action.data,
						}))
					elseif action.command then
						self:cache_save(Command:new({
							title = action.title,
							type = action.kind,
							source = client.name,
							command = action.command.command,
							args = action.command.arguments,
						}))
					end
				end
			else
				vim.notify("No code actions available")
			end
		end
		if not background and not self:cache_is_empty() then
			self:show()
		end
	end)
end

function Context:show()
	local Layout = require("nui.layout")
	local Menu = require("nui.menu")
	local Popup = require("nui.popup")
	local event = require("nui.utils.autocmd").event

	local nui_preview = Popup(vim.tbl_deep_extend("force", M.config.info, {
		size = nil,
		border = {
			text = {
				top = "Preview",
			},
		},
	}))

	local nui_info = Popup(vim.tbl_deep_extend("force", M.config.info, {
		size = nil,
		border = {
			text = {
				top = "Info",
			},
		},
	}))

	local nui_select = Menu(
		vim.tbl_deep_extend("force", M.config.select, {
			position = 0,
			size = nil,
			border = {
				text = {
					top = "Code Actions",
				},
			},
		}),
		{
			lines = vim.tbl_map(function(action)
				return Menu.item(action.title, { action = action })
			end, self.cache_data),
			keymap = M.config.keymap,
			on_change = function(item)
				item.action:info(function(info)
					if nui_info.bufnr == nil then
						return
					end

					info = info or { syntax = "", text = "info not available" }

					vim.api.nvim_buf_set_lines(nui_info.bufnr, 0, -1, false, vim.split(info.text, "\n"))

					vim.api.nvim_buf_set_option(nui_info.bufnr, "syntax", info.syntax)
				end)
				-- item.action:preview(function(preview)
				-- if nui_preview.bufnr == nil then
				-- 	return
				-- end
				--
				-- preview = preview or { syntax = "", text = "preview not available" }
				--
				-- vim.api.nvim_buf_set_lines(nui_preview.bufnr, 0, -1, false, vim.split(preview.text, "\n"))
				--
				-- vim.api.nvim_buf_set_option(nui_preview.bufnr, "syntax", preview.syntax)
				-- end)
			end,
			on_submit = function(item)
				item.action:execute()
			end,
		}
	)

	nui_select:map("n", "<MouseMove>", function()
		local ok, mouse = pcall(vim.fn.getmousepos)
		if not ok then
			return
		end
		local row = mouse.line
		local node = nui_select.tree:get_node(row)
		if node then
			vim.api.nvim_win_set_cursor(nui_select.winid, { row, 0 })
			nui_select._.on_change(node)
		end
	end)

	nui_select:map("n", "<LeftMouse>", nui_select.menu_props.on_submit)

	local layout = Layout(
		vim.tbl_deep_extend("force", M.config.layout, {
			size = {
				height = "40%",
				width = "30%",
			},
			min_height = 15,
		}),
		Layout.Box({
			Layout.Box(nui_select, { grow = 1, min_height = 2, max_height = 3 }),
			Layout.Box(nui_info, { size = { height = 5 }, min_height = 3, max_height = 3 }),
			Layout.Box(nui_preview, { size = "50%" }),
		}, { dir = M.config.dir })
	)

	layout:mount()
	nui_select:on(event.BufLeave, function()
		layout:hide()
		layout:unmount()
	end)
end

function M.code_actions()
	Context:fetch()
end

M.config = {
	dir = "col",
	keymap = {
		close = { "q" },
	},
	layout = {
		position = {
			row = 1,
			col = 1,
		},
		min_width = 10,
		min_height = 5,
		relative = "cursor",
	},
	info = {
		border = {
			style = "rounded",
			padding = { 0, 0 },
		},
		focusable = false,
	},
	select = {
		border = {
			style = "rounded",
			padding = { 0, 0 },
		},
		win_options = {
			scrolloff = 0,
		},
	},
}

return M

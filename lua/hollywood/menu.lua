---@class Hollywood.Menu
---@field actions Hollywood.Action[]
---@field private win window
---@field private buf buffer
local Menu = {}
Menu.__index = Menu

---@param actions Hollywood.Action[]?
function Menu:new(actions, title)
	return setmetatable({
		actions = actions or {},
		title = title or "Actions",
	}, self)
end

function Menu:open()
	if self.buf == nil or not vim.api.nvim_buf_is_valid(self.buf) then
		self.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "BufLeave" }, {
			once = true,
			buffer = self.buf,
			callback = function()
				self.buf = nil
				self:close()
			end,
		})
		vim.keymap.set("n", "<CR>", function()
			self:execute()
		end, { buffer = self.buf })
		vim.keymap.set("n", "q", function()
			self:close()
		end, { buffer = self.buf })
		vim.keymap.set("n", "<Esc>", function()
			self:close()
		end, { buffer = self.buf })
	end
	local width = self:render()
	self.win = vim.api.nvim_open_win(self.buf, false, {
		border = {
			{ "▀", "HollywoodFloatBorder" }, -- top left
			{ "▀", "HollywoodFloatBorder" }, -- top
			{ "▀", "HollywoodFloatBorder" }, -- top right
			{ " ", "HollywoodFloatBorder" }, -- right
			{ "▄", "HollywoodFloatBorder" }, -- bottom right
			{ "▄", "HollywoodFloatBorder" }, -- bottom
			{ "▄", "HollywoodFloatBorder" }, -- bottom left
			{ " ", "HollywoodFloatBorder" }, -- left
		},
		focusable = true,
		title = " Code Actions",
		relative = "cursor",
		width = width,
		height = #self.actions,
		row = 1,
		col = 0,
	})
end

function Menu:set_title(title)
	self.title = title
	if self:is_open() then
		vim.api.nvim_win_set_config(self.win, { title = title })
	end
end

---@return integer width
function Menu:render()
	if not self.buf then
		return 0
	end
	local lines = {}
	for _, action in ipairs(self.actions) do
		table.insert(lines, action:entry())
	end
	return vim.iter(lines):enumerate():fold(40, function(width, i, line)
		---@cast line NuiLine
		line:render(self.buf, require("hollywood.state").ns, i)
		return math.max(width, line:width())
	end)
end

function Menu:execute()
	if self.win == nil or not vim.api.nvim_win_is_valid(self.win) then
		return
	end
	local line = vim.api.nvim_win_get_cursor(self.win)[1]
	local action = self.actions[line]
	if not action then
		return
	end
	action:execute()
	self:close()
end

function Menu:close()
	if self.win ~= nil and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end
	self.win = nil
end

function Menu:add(action)
	table.insert(self.actions, action)
	self:render()
end

function Menu:clear()
	self.actions = {}
	self:render()
end

function Menu:is_open()
	return self.win and vim.api.nvim_win_is_valid(self.win)
end

function Menu:window()
	if self:is_open() then
		return self.win
	end
end

function Menu:focus()
	if self:is_open() then
		vim.api.nvim_set_current_win(self.win)
	end
end

return Menu

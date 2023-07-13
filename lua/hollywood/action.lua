local Line = require("nui.line")
local Text = require("nui.text")

---@class Hollywood.Action
---@field title string
---@field source string
---@field task thread
local Action = {}
Action.__index = Action

---@param title string
---@param source string
---@param fn fun() | thread
---@return Hollywood.Action
function Action:new(title, source, fn)
	vim.validate({
		title = { title, "string" },
		source = { source, "string" },
		task = { fn, { "function", "thread" } },
	})
	if type(fn) == "function" then
		fn = coroutine.create(fn)
	end
	---@type Hollywood.Action
	local o = {
		title = title,
		source = source,
		task = fn,
	}
	return setmetatable(o, self)
end

---@return NuiLine
function Action:entry()
	return Line({ Text(self.title, "Keyword") })
end

---@return NuiLine[]
function Action:info()
	return {
		Line({ Text(self.title, "Keyword") }),
		Line({ Text(self.source, "Normal") }),
	}
end

function Action:execute()
	local ok, err = coroutine.resume(self.task)
	if not ok then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end
	local status = coroutine.status(self.task)
	if status == "dead" then
		self.task = nil
		return
	end
	-- "poll" the coroutine until it's done
	vim.defer_fn(function()
		self:execute()
	end, 10)
end

return Action

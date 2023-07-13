local Menu = require("hollywood.menu")
local Action = require("hollywood.action")
local State = require("hollywood.state")

local M = {}

function M.code_actions()
	if State.menu:is_open() then
		if State.menu:window() ~= vim.api.nvim_get_current_win() then
			State.menu:focus()
		end
		return
	end
	-- TODO: fetch code actions, asynchronously add to menu
end

function M.build_actions()
	-- TODO: fetch actions from Overseer, asynchronously add to menu
end

function M.setup()
	vim.api.nvim_set_hl(0, "HollywoodFloatBorder", {
		fg = "#262840",
		bg = "#222439",
	})
	State.ns = vim.api.nvim_create_namespace("hollywood")

	State.menu = Menu:new()
end

return M

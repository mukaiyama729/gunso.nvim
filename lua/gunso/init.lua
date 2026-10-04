local config = require("gunso.config")
local state = require("gunso.state")
local panel = require("gunso.panel")
local renderer = require("gunso.renderer")
local hook = require("gunso.hook")

local M = {}

-- ---------------------------------------
-- highlight
-- ---------------------------------------

local function setup_highlights()
	vim.api.nvim_set_hl(0, "GunsoNormal", {
		bg = "NONE",
		default = true,
	})

	vim.api.nvim_set_hl(0, "GunsoBorder", {
		link = "FloatBorder",
		default = true,
	})
end

-- ---------------------------------------
-- 最大X
-- ---------------------------------------

local function get_bounds()
	local current = panel.get_current_panel()

	if not current then
		return 0, 0
	end

	local min_x = 0
	local max_x = math.max(min_x, current.width - config.options.image.width)

	return min_x, max_x
end

-- ---------------------------------------
-- 一歩進む
-- ---------------------------------------

function M.step()
	if not state.enabled or #config.options.frames == 0 then
		return
	end

	--
	-- 次の画像
	--
	state.frame = (state.frame or 1) + 1

	if state.frame > #config.options.frames then
		state.frame = 1
	end

	--
	-- 移動
	--
	local min_x, max_x = get_bounds()
	state.x = math.min(max_x, math.max(min_x, state.x + (config.options.move_step or 1) * (state.direction or 1)))

	renderer.render_current()
end

-- ---------------------------------------
-- reset
-- ---------------------------------------

function M.reset()
	state.key_count = 0
	state.frame = 1
	state.x = 0
	state.y = 0
	state.direction = 1

	if state.enabled then
		renderer.render_current()
	end
end

-- ---------------------------------------
-- enable
-- ---------------------------------------

function M.enable()
	if state.enabled then
		return
	end

	state.enabled = true
	hook.setup(M.step)

	renderer.render_current()
end

-- ---------------------------------------
-- disable
-- ---------------------------------------

function M.disable()
	if not state.enabled then
		return
	end

	hook.stop()
	renderer.clear_all()
	panel.close_all_panels()

	state.enabled = false
end

-- ---------------------------------------
-- toggle
-- ---------------------------------------

function M.toggle()
	if state.enabled then
		M.disable()
	else
		M.enable()
	end
end

-- ---------------------------------------
-- commands
-- ---------------------------------------

local function setup_commands()
	pcall(vim.api.nvim_del_user_command, "GunsoToggle")
	pcall(vim.api.nvim_del_user_command, "GunsoStep")
	pcall(vim.api.nvim_del_user_command, "GunsoReset")

	vim.api.nvim_create_user_command("GunsoToggle", function()
		M.toggle()
	end, {})

	vim.api.nvim_create_user_command("GunsoStep", function()
		M.step()
	end, {})

	vim.api.nvim_create_user_command("GunsoReset", function()
		M.reset()
	end, {})
end

-- ---------------------------------------
-- autocmd
-- ---------------------------------------

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("Gunso", {
		clear = true,
	})

	--
	-- 起動後
	--
	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,

		callback = function()
			if not state.enabled then
				return
			end

			vim.schedule(function()
				renderer.render_current()
			end)
		end,
	})

	--
	-- Tabを離れる直前
	--
	-- Kitty等のterminal imageが
	-- 古いTabから残らないよう一度clear。
	--
	vim.api.nvim_create_autocmd("TabLeave", {
		group = group,

		callback = function()
			if state.enabled then
				renderer.clear_current()
			end
		end,
	})

	--
	-- 新しいTabへ移動
	--
	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,

		callback = function()
			if not state.enabled then
				return
			end

			vim.schedule(function()
				renderer.render_current()
			end)
		end,
	})

	--
	-- Tabを閉じた
	--
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,

		callback = function()
			vim.schedule(function()
				renderer.cleanup_closed_tabs()
			end)
		end,
	})

	--
	-- terminal resize
	--
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,

		callback = function()
			if not state.enabled then
				return
			end

			if #config.options.frames == 0 then
				return
			end

			vim.schedule(function()
				panel.relayout_current()

				local min_x, max_x = get_bounds()

				if state.x > max_x then
					state.x = max_x
				end

				if state.x < min_x then
					state.x = min_x
				end

				renderer.render_current()
			end)
		end,
	})

	--
	-- colorscheme変更
	--
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,

		callback = setup_highlights,
	})

	--
	-- 終了
	--
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,

		callback = function()
			hook.stop()
			renderer.clear_all()
		end,
	})
end

-- ---------------------------------------
-- setup
-- ---------------------------------------

function M.setup(opts)
	config.setup(opts)

	require("image").setup({
		backend = config.resolve_image_backend(),
		processor = config.options.image.processor,
	})

	setup_highlights()
	setup_commands()
	setup_autocmds()

	if state.enabled then
		hook.setup(M.step)
	else
		hook.stop()
	end

	--
	-- Lazyをreloadした場合など、
	-- 既にVimEnter済みなら即描画。
	--
	if vim.v.vim_did_enter == 1 then
		vim.schedule(function()
			if not state.enabled then
				return
			end

			renderer.render_current()
		end)
	end
end

return M

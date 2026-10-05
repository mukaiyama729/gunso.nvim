local M = {}

M.defaults = {
	panel = {
		row = 2,
		col = 5,

		width = 6,
		height = 3,

		border = "rounded",

		zindex = 2,
	},

	image = {
		backend = "auto",
		processor = "magick_cli",
		width = 5,
		height = 3,
		y = 0,
		max_height_window_percentage = 100,
	},

	move_step = 0,
	panel_move_step = 0,

	keys_per_step = 1,

	frames = {
		"walk_1.png",
		"walk_2.png",
		"walk_3.png",
	},
}

M.options = {}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, options or {})
end

local supported_backends = {
	kitty = true,
	sixel = true,
	ueberzug = true,
}

local function env(name)
	return (vim.env[name] or ""):lower()
end

local function supports_kitty_graphics_protocol()
	local term = env("TERM")
	local term_program = env("TERM_PROGRAM")
	local iterm_session_id = vim.env.ITERM_SESSION_ID

	return vim.env.KITTY_WINDOW_ID ~= nil
		or term:find("kitty", 1, true) ~= nil
		or term == "xterm-ghostty"
		or term_program == "ghostty"
		or term_program == "iterm.app"
		or (iterm_session_id ~= nil and iterm_session_id ~= "")
end

local function is_sixel_terminal()
	local term = env("TERM")
	local term_program = env("TERM_PROGRAM")

	return term_program == "wezterm"
		or term:find("wezterm", 1, true) ~= nil
		or term:match("^foot") ~= nil
		or term:match("^contour") ~= nil
		or term:match("^mlterm") ~= nil
end

local function has_sixel_encoder()
	local command

	if vim.fn.executable("magick") == 1 then
		command = "magick"
	elseif vim.fn.executable("convert") == 1 then
		command = "convert"
	else
		return false
	end

	for _, line in ipairs(vim.fn.systemlist({ command, "-list", "format" })) do
		if line:match("^%s*SIX") then
			return true
		end
	end

	return false
end

function M.resolve_image_backend()
	local requested = M.options.image.backend or "auto"

	if requested ~= "auto" then
		if supported_backends[requested] then
			return requested
		end

		vim.notify_once("Gunso: unknown image backend: " .. tostring(requested), vim.log.levels.WARN)
	end

	-- iTerm2 supports Kitty's graphics protocol. Check it before the Sixel
	-- heuristics because it commonly reports TERM=xterm-256color.
	if supports_kitty_graphics_protocol() then
		return "kitty"
	end

	-- ueberzug works independently of the terminal graphics protocol.
	if vim.fn.executable("ueberzug") == 1 then
		return "ueberzug"
	end

	if is_sixel_terminal() and has_sixel_encoder() then
		return "sixel"
	end

	vim.notify_once(
		"Gunso: no image backend detected; using kitty. Set image.backend to 'sixel' or 'ueberzug' for this terminal.",
		vim.log.levels.WARN
	)
	return "kitty"
end

return M

local config = require("gunso.config")
local state = require("gunso.state")

local M = {}

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_tab(tab)
  return tab and vim.api.nvim_tabpage_is_valid(tab)
end

local function get_or_create_shared_buf()
  local shared_buf = state.buffer

  if valid_buf(shared_buf) then
    return shared_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "gunso"
  vim.bo[buf].modifiable = true

  local lines = {}

  local height = config.options.panel.height

  for _ = 1, height do
    table.insert(lines, "")
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  state.buffer = buf

  return buf
end

local function cal_panel_size()
  local opts = config.options.panel
  local available_width = math.max(1, vim.o.columns - opts.col)
  local available_height = math.max(1, vim.o.lines - opts.row)

  local width = math.min(available_width, opts.width)
  local height = math.min(available_height, opts.height)

  return width, height
end

local function cal_panel_position()
  local opts = config.options.panel
  local row = math.max(0, vim.o.lines - vim.o.cmdheight - opts.row)
  local col = math.max(0, vim.o.columns - opts.col)

  return row, col
end

function M.create_current_panel()
  local tab = vim.api.nvim_get_current_tabpage()
  local width, height = cal_panel_size()
  local row, col = cal_panel_position()

  local buf = get_or_create_shared_buf()
  local opts = config.options.panel

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    anchor = "SE",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = opts.border,
    focusable = false,
    zindex = opts.zindex,
    noautocmd = true,
  })
  vim.wo[win].wrap = false

  vim.wo[win].winhl = "Normal:GunsoNormal,FloatBorder:GunsoBorder"

  local panel = {
    tab = tab,
    win = win,
    buf = buf,
    width = width,
    height = height,
    position = {
      row = row,
      col = col,
    },
    images = {},
    visible_frame = nil,
  }

  state.panels[tab] = panel
  return panel
end

function M.get_current_panel()
  local tab = vim.api.nvim_get_current_tabpage()
  local current = state.panels[tab]

  if not valid_tab(tab) then
    return M.create_current_panel()
  end

  if not current or not valid_win(current.win) or not valid_buf(current.buf) then
    if current and valid_win(current.win) then
      pcall(vim.api.nvim_win_close, current.win, true)
    end

    state.panels[tab] = nil
    return M.create_current_panel()
  end

  return current
end

function M.peek_current_panel()
  local tab = vim.api.nvim_get_current_tabpage()

  if not valid_tab(tab) then
    return nil
  end

  local current = state.panels[tab]

  if not current or not valid_win(current.win) or not valid_buf(current.buf) then
    return nil
  end

  return current
end

function M.relayout_current()
  local current = M.get_current_panel()

  if not current then
    return nil
  end

  local width, height = cal_panel_size()
  local row, col = cal_panel_position()

  vim.api.nvim_win_set_config(current.win, {
    relative = "editor",
    anchor = "SE",
    row = row,
    col = col,
    width = width,
    height = height,
  })

  current.width = width
  current.height = height
  current.position = {
    row = row,
    col = col,
  }

  return current
end

function M.remove_win(tab)
  local current = state.panels[tab]

  if not current then
    return nil
  end

  if valid_win(current.win) then
    pcall(vim.api.nvim_win_close, current.win, true)
  end

  state.panels[tab] = nil
  return current
end

function M.close_all_panels()
  local tabs = {}

  for tab, _ in pairs(state.panels) do
    table.insert(tabs, tab)
  end

  for _, tab in ipairs(tabs) do
    M.remove_win(tab)
  end
end

function M.move_panel()
  local current = M.get_current_panel()
  if not current or not valid_win(current.win) then
    return
  end

  local row = current.position.row - (config.options.panel_move_step or 0)
  if row < 1 then
    row = config.panel.row
  end

  vim.api.nvim_win_set_config(current.win, {
    relative = "editor",
    anchor = "SE",
    row = row,
    col = current.position.col,
  })

  current.position.row = row
end

return M

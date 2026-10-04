local config = require("gunso.config")
local state = require("gunso.state")
local panel_api = require("gunso.panel")

local image_api = require("image")

local M = {}

-- ---------------------------------------
-- plugin root
-- ---------------------------------------

local function plugin_root()
  local source = debug.getinfo(1, "S").source

  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end

  -- renderer.lua
  -- lua/gunso/
  -- lua/
  -- gunso/ (plugin root)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local ROOT = plugin_root()
local ASSETS = ROOT .. "/assets"
local RENDER_POLL_INTERVAL_MS = 10
local MAX_TRANSFORM_WAIT_ATTEMPTS = 300
local MAX_BACKEND_WAIT_ATTEMPTS = 20

-- ---------------------------------------
-- image path
-- ---------------------------------------

local function frame_path(frame)
  local filename = config.options.frames[frame]

  if type(filename) ~= "string" or filename == "" then
    return nil
  end

  if filename:sub(1, 1) == "/" then
    return filename
  end

  return ASSETS .. "/" .. filename
end

-- ---------------------------------------
-- image取得
-- ---------------------------------------

local function get_image(panel, frame)
  if panel.images[frame] then
    return panel.images[frame]
  end

  local path = frame_path(frame)

  if not path then
    vim.notify_once("Gunso: no frame configured for index " .. frame, vim.log.levels.WARN)
    return nil
  end

  if vim.fn.filereadable(path) ~= 1 then
    vim.notify_once("Gunso: image not found: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local image_opts = config.options.image

  local img = image_api.from_file(path, {
    window = panel.win,

    buffer = panel.buf,

    inline = false,

    with_virtual_padding = false,

    x = state.x,

    y = image_opts.y,

    width = image_opts.width,

    height = image_opts.height,

    max_height_window_percentage = image_opts.max_height_window_percentage,
  })

  if not img then
    vim.notify_once("Gunso: failed to load image: " .. path, vim.log.levels.ERROR)
    return nil
  end

  panel.images[frame] = img

  return img
end

local function clear_image(panel, frame)
  local img = panel.images[frame]

  if not img then
    return
  end

  pcall(function()
    img:clear(true)
  end)
end

local function cancel_pending_render(panel)
  local frame = panel.pending_frame

  if frame and frame ~= panel.visible_frame then
    clear_image(panel, frame)
  end

  panel.pending_frame = nil
end

-- ---------------------------------------
-- panelの画像を消す
-- ---------------------------------------

function M.clear_panel(panel)
  if not panel then
    return
  end

  panel.render_generation = (panel.render_generation or 0) + 1
  panel.pending_frame = nil

  local images = panel.images
  panel.images = {}

  for _, img in pairs(images) do
    pcall(function()
      img:clear()
    end)
  end

  panel.visible_frame = nil
end

function M.clear_current()
  local panel = panel_api.peek_current_panel()

  if not panel then
    return
  end

  panel.render_generation = (panel.render_generation or 0) + 1
  cancel_pending_render(panel)

  if panel.visible_frame then
    clear_image(panel, panel.visible_frame)
  end

  panel.visible_frame = nil
end

function M.clear_all()
  for _, panel in pairs(state.panels) do
    M.clear_panel(panel)
  end
end

-- ---------------------------------------
-- 描画
-- ---------------------------------------

function M.render_current()
  if not state.enabled or #config.options.frames == 0 then
    return
  end

  local panel = panel_api.get_current_panel()

  if not panel then
    return
  end

  local image_opts = config.options.image
  local frame = state.frame

  panel.render_generation = (panel.render_generation or 0) + 1
  local generation = panel.render_generation

  -- A newer request supersedes a frame whose transform has not finished yet.
  if panel.pending_frame and panel.pending_frame ~= frame then
    cancel_pending_render(panel)
  end

  local img = get_image(panel, frame)

  if not img then
    return
  end

  img:render({
    x = state.x,

    y = image_opts.y,

    width = image_opts.width,

    height = image_opts.height,
  })

  local transform_wait_attempts = 0
  local backend_wait_attempts = 0

  local function finish_render()
    if panel.render_generation ~= generation or not state.enabled then
      return
    end

    if img.is_rendered then
      if panel.visible_frame and panel.visible_frame ~= frame then
        clear_image(panel, panel.visible_frame)
      end

      panel.visible_frame = frame
      panel.pending_frame = nil
      return
    end

    if img.pending_transform_key then
      transform_wait_attempts = transform_wait_attempts + 1

      if transform_wait_attempts < MAX_TRANSFORM_WAIT_ATTEMPTS then
        panel.pending_frame = frame
        vim.defer_fn(finish_render, RENDER_POLL_INTERVAL_MS)
        return
      end
    else
      -- Some backends (such as Sixel) finish painting shortly after render() returns.
      backend_wait_attempts = backend_wait_attempts + 1

      if backend_wait_attempts < MAX_BACKEND_WAIT_ATTEMPTS then
        panel.pending_frame = frame
        vim.defer_fn(finish_render, RENDER_POLL_INTERVAL_MS)
        return
      end
    end

    if panel.pending_frame == frame then
      if frame ~= panel.visible_frame then
        clear_image(panel, frame)
      end
      panel.pending_frame = nil
    end
  end

  finish_render()
end

-- ---------------------------------------
-- 閉じられたTabをcleanup
-- ---------------------------------------

function M.cleanup_closed_tabs()
  local alive = {}

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    alive[tab] = true
  end

  local dead = {}

  for tab, current in pairs(state.panels) do
    if not alive[tab] then
      M.clear_panel(current)

      table.insert(dead, tab)
    end
  end

  for _, tab in ipairs(dead) do
    panel_api.remove_win(tab)
  end
end

return M

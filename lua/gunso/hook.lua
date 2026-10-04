local config = require("gunso.config")
local state = require("gunso.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("gunso")

function M.setup(on_step)
  vim.on_key(nil, namespace, nil)

  vim.on_key(function(_, typed)
    if typed == "" then
      return
    end

    local current_mode = vim.api.nvim_get_mode().mode

    if current_mode == "v" or current_mode == "V" or current_mode == "\22" then
      return
    end

    state.key_count = state.key_count + 1

    local keys_per_step = math.max(1, config.options.keys_per_step or 1)

    if state.key_count < keys_per_step then
      return
    end

    state.key_count = 0

    on_step()
  end, namespace)
end

function M.stop()
  vim.on_key(nil, namespace, nil)
  state.key_count = 0
end

return M

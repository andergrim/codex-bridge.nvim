local config = require("codex_bridge.config")
local context = require("codex_bridge.context")
local keymaps = require("codex_bridge.keymaps")
local server = require("codex_bridge.server")
local state = require("codex_bridge.state")

local M = {}

function M.setup(opts)
  config.setup(opts)
  keymaps.setup()
end

function M.start_session(opts)
  server.start(opts or {})
end

function M.start_resume_session(session, opts)
  opts = opts or {}
  opts.resume_id = session
  server.start(opts)
end

local function prompt_user(callback)
  vim.ui.input({ prompt = "Codex prompt: " }, function(input)
    if not input or input == "" then
      return
    end
    callback(input)
  end)
end

function M.send(opts)
  opts = opts or {}

  local function do_send(prompt)
    local selection = context.selection(opts)
    local payload = context.format(prompt, selection)
    server.send(payload)
  end

  if opts.prompt and opts.prompt ~= "" then
    do_send(opts.prompt)
    return
  end

  prompt_user(do_send)
end

function M.stop()
  server.stop()
end

function M.status()
  return state.get()
end

function M.statusline()
  return state.statusline()
end

function M.on_status_change(listener)
  return state.on_change(listener)
end

return M

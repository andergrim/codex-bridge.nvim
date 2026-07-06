local M = {}

local state = {
  status = "stopped",
  message = nil,
  server_job_id = nil,
  terminal_job_id = nil,
  socket_path = nil,
  thread_id = nil,
  turn_id = nil,
  busy = false,
  cwd = nil,
  thread_status = nil,
  last_notification = nil,
  last_error = nil,
}

local listeners = {}

local function snapshot()
  return vim.deepcopy(state)
end

local function notify()
  local current = snapshot()
  for _, listener in ipairs(listeners) do
    pcall(listener, current)
  end
end

function M.update(patch)
  state = vim.tbl_extend("force", state, patch or {})
  notify()
end

function M.get()
  return snapshot()
end

function M.on_change(listener)
  table.insert(listeners, listener)
  return function()
    for i, existing in ipairs(listeners) do
      if existing == listener then
        table.remove(listeners, i)
        return
      end
    end
  end
end

function M.statusline()
  if state.status == "stopped" then
    return "Codex: stopped"
  end

  if state.busy then
    return "Codex: busy"
  end

  if state.status == "error" then
    return "Codex: error"
  end

  return "Codex: " .. state.status
end

return M

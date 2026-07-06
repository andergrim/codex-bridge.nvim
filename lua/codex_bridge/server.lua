local config = require("codex_bridge.config")
local state = require("codex_bridge.state")
local rpc_mod = require("codex_bridge.rpc")
local terminal = require("codex_bridge.terminal")

local uv = vim.uv or vim.loop

local M = {
  rpc = nil,
}

local function notify_error(message)
  state.update({ status = "error", busy = false, last_error = message, message = message })
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR, { title = "codex-bridge.nvim" })
  end)
end

local function socket_path()
  local cfg = config.get()
  local dir = cfg.socket_dir or vim.fn.stdpath("run")
  vim.fn.mkdir(dir, "p")
  return dir .. "/codex-bridge-" .. vim.fn.getpid() .. ".sock"
end

local function remote_url(path)
  return "unix://" .. path
end

local function wait_for_socket(path, timeout_ms, callback)
  local started = uv.now()
  local timer = uv.new_timer()

  timer:start(20, 50, function()
    if uv.fs_stat(path) then
      timer:stop()
      timer:close()
      vim.schedule(function()
        callback(true)
      end)
      return
    end

    if uv.now() - started > timeout_ms then
      timer:stop()
      timer:close()
      vim.schedule(function()
        callback(false)
      end)
    end
  end)
end

local function launch_terminal(path, resume_id)
  local cfg = config.get()
  if not cfg.terminal.enabled then
    return nil
  end

  local cmd = terminal.resolve(cfg.terminal)
  if not cmd then
    notify_error("could not find a supported terminal executable")
    return nil
  end

  if resume_id and resume_id ~= "" then
    vim.list_extend(cmd, { cfg.codex_cmd, "resume", "--remote", remote_url(path), resume_id })
  else
    vim.list_extend(cmd, { cfg.codex_cmd, "--remote", remote_url(path) })
  end

  local job_id = vim.fn.jobstart(cmd, { detach = true })
  if job_id <= 0 then
    notify_error("failed to launch Codex terminal: " .. table.concat(cmd, " "))
    return nil
  end

  state.update({ terminal_job_id = job_id })
  return job_id
end

local function handle_notification(message)
  local method = message.method
  local params = message.params or {}
  state.update({ last_notification = method })

  if method == "turn/started" then
    local turn = params.turn or {}
    state.update({ status = "busy", busy = true, turn_id = turn.id })
  elseif method == "turn/completed" or method == "turn/failed" or method == "turn/cancelled" then
    state.update({ status = "ready", busy = false, turn_id = nil })
  elseif method == "thread/status/changed" then
    local thread_status = params.status or {}
    if thread_status.type == "active" then
      state.update({ status = "busy", busy = true, thread_status = thread_status.type })
    elseif thread_status.type == "idle" then
      state.update({ status = "ready", busy = false, turn_id = nil, thread_status = thread_status.type })
    elseif thread_status.type == "systemError" then
      state.update({ status = "error", busy = false, turn_id = nil, thread_status = thread_status.type })
    else
      state.update({ thread_status = thread_status.type })
    end
  elseif method == "error" then
    state.update({
      status = "error",
      busy = false,
      turn_id = nil,
      last_error = params.message or vim.inspect(params),
      message = params.message or vim.inspect(params),
    })
  elseif method == "thread/started" then
    local thread = params.thread or {}
    if thread.id then
      state.update({ thread_id = thread.id })
    end
  end
end

local function initialize_rpc(path, callback)
  local cfg = config.get()
  M.rpc = rpc_mod.Rpc.new(path, {
    on_notification = handle_notification,
    on_error = notify_error,
    on_close = function()
      if state.get().status ~= "stopped" then
        state.update({ status = "stopped", busy = false, message = "Codex app-server connection closed" })
      end
    end,
  })

  M.rpc:connect(function()
    M.rpc:request("initialize", {
      clientInfo = {
        name = cfg.client_name,
        title = cfg.client_title,
        version = cfg.client_version,
      },
      capabilities = {
        experimentalApi = true,
      },
    }, function(err)
      if err then
        notify_error("Codex initialize failed: " .. (err.message or vim.inspect(err)))
        return
      end

      M.rpc:notify("initialized", {})
      callback()
    end)
  end)
end

local function start_thread(opts)
  local cfg = config.get()
  opts = opts or {}

  if opts.resume_id then
    M.rpc:request("thread/resume", {
      threadId = opts.resume_id,
    }, function(err, result)
      if err then
        notify_error("Codex resume failed: " .. (err.message or vim.inspect(err)))
        return
      end
      local thread = result and result.thread or {}
      state.update({ status = "ready", busy = false, thread_id = thread.id or opts.resume_id })
    end)
    return
  end

  local params = {
    cwd = state.get().cwd or cfg.cwd or vim.fn.getcwd(),
  }
  if cfg.model then
    params.model = cfg.model
  end
  if cfg.cwd then
    params.cwd = cfg.cwd
  end

  M.rpc:request("thread/start", params, function(err, result)
    if err then
      notify_error("Codex thread start failed: " .. (err.message or vim.inspect(err)))
      return
    end
    local thread = result and result.thread or {}
    state.update({ status = "ready", busy = false, thread_id = thread.id })
  end)
end

function M.start(opts)
  opts = opts or {}
  local current = state.get()
  if current.status ~= "stopped" and current.status ~= "error" then
    if opts.open_terminal ~= false and current.socket_path then
      launch_terminal(current.socket_path, opts.resume_id)
    end
    return
  end

  local cfg = config.get()
  local path = socket_path()
  local cwd = cfg.cwd or vim.fn.getcwd()
  local listen = remote_url(path)
  local cmd = { cfg.codex_cmd, "app-server", "--listen", listen }

  state.update({
    status = "starting",
    busy = false,
    socket_path = path,
    cwd = cwd,
    thread_id = nil,
    turn_id = nil,
    thread_status = nil,
    last_notification = nil,
    last_error = nil,
    message = "Starting Codex app-server",
  })

  local job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    on_exit = function(_, code)
      local current_state = state.get()
      if current_state.server_job_id == job_id and current_state.status ~= "stopped" then
        state.update({
          status = code == 0 and "stopped" or "error",
          busy = false,
          message = "Codex app-server exited with code " .. code,
        })
      end
    end,
    on_stderr = function(_, data)
      local lines = vim.tbl_filter(function(line)
        return line ~= ""
      end, data or {})
      if #lines > 0 then
        state.update({ message = table.concat(lines, "\n") })
      end
    end,
  })

  if job_id <= 0 then
    notify_error("failed to start Codex app-server: " .. table.concat(cmd, " "))
    return
  end

  state.update({ server_job_id = job_id })

  wait_for_socket(path, 5000, function(ok)
    if not ok then
      notify_error("timed out waiting for Codex app-server socket: " .. path)
      return
    end

    initialize_rpc(path, function()
      start_thread({ resume_id = opts.resume_id })
      if opts.open_terminal ~= false then
        launch_terminal(path, opts.resume_id)
      end
    end)
  end)
end

function M.send(text)
  local current = state.get()

  if not M.rpc or current.status == "stopped" then
    notify_error("Codex session is not started")
    return
  end

  if current.busy then
    vim.notify("Codex is busy; wait for the active turn to finish.", vim.log.levels.WARN, {
      title = "codex-bridge.nvim",
    })
    return
  end

  if not current.thread_id then
    notify_error("Codex thread is not ready")
    return
  end

  state.update({ status = "busy", busy = true })
  M.rpc:request("turn/start", {
    threadId = current.thread_id,
    input = {
      { type = "text", text = text },
    },
  }, function(err, result)
    if err then
      notify_error("Codex turn failed to start: " .. (err.message or vim.inspect(err)))
      return
    end
    local turn = result and result.turn or {}
    state.update({ turn_id = turn.id })
  end)
end

function M.stop()
  local current = state.get()
  if M.rpc then
    M.rpc:close()
    M.rpc = nil
  end
  if current.server_job_id then
    pcall(vim.fn.jobstop, current.server_job_id)
  end
  if current.socket_path then
    pcall(vim.fn.delete, current.socket_path)
  end
  state.update({
    status = "stopped",
    busy = false,
    server_job_id = nil,
    terminal_job_id = nil,
    socket_path = nil,
    thread_id = nil,
    turn_id = nil,
    thread_status = nil,
    last_notification = nil,
    message = nil,
  })
end

return M

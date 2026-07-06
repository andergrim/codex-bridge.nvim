-- codex-bridge.nvim - Codex session bridge for Neovim
-- Copyright (C) 2026 Kristoffer Andergrim
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.local M = {}

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

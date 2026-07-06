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
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local websocket = require("codex_bridge.websocket")

local M = {}

local Rpc = {}
Rpc.__index = Rpc

local function params_object(params)
  if params == nil or vim.tbl_isempty(params) then
    return vim.empty_dict()
  end
  return params
end

function Rpc.new(socket_path, opts)
  opts = opts or {}
  return setmetatable({
    socket_path = socket_path,
    next_id = 1,
    pending = {},
    ws = nil,
    on_notification = opts.on_notification,
    on_error = opts.on_error,
    on_close = opts.on_close,
  }, Rpc)
end

function Rpc:connect(on_ready)
  self.ws = websocket.connect(self.socket_path, {
    on_open = function()
      if on_ready then
        on_ready()
      end
    end,
    on_message = function(raw)
      self:_handle(raw)
    end,
    on_error = function(err)
      if self.on_error then
        self.on_error(err)
      end
    end,
    on_close = function()
      if self.on_close then
        self.on_close()
      end
    end,
  })
end

function Rpc:_handle(raw)
  local ok, message = pcall(vim.json.decode, raw)
  if not ok then
    if self.on_error then
      self.on_error("invalid JSON-RPC message: " .. tostring(message))
    end
    return
  end

  if message.id ~= nil then
    local pending = self.pending[message.id]
    self.pending[message.id] = nil
    if pending then
      pending(message.error, message.result)
    end
    return
  end

  if self.on_notification then
    self.on_notification(message)
  end
end

function Rpc:notify(method, params)
  if not self.ws then
    return false, "not connected"
  end
  return self.ws:send_text(vim.json.encode({ method = method, params = params_object(params) }))
end

function Rpc:request(method, params, callback)
  if not self.ws then
    return false, "not connected"
  end

  local id = self.next_id
  self.next_id = self.next_id + 1
  self.pending[id] = callback or function() end

  return self.ws:send_text(vim.json.encode({
    id = id,
    method = method,
    params = params_object(params),
  }))
end

function Rpc:close()
  if self.ws then
    self.ws:close()
  end
end

M.Rpc = Rpc

return M

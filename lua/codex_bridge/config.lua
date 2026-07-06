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

M.defaults = {
  codex_cmd = "codex",
  socket_dir = vim.fn.stdpath("run"),
  client_name = "codex_bridge_nvim",
  client_title = "codex-bridge.nvim",
  client_version = "0.1.0",
  model = nil,
  cwd = nil,
  terminal = {
    enabled = true,
    command = nil,
  },
  prompt = {
    include_file_on_empty_selection = true,
  },
  keymaps = {
    enabled = true,
    prefix = "<leader>c",
    start = "s",
    start_headless = "S",
    resume = "r",
    send = "c",
    stop = "x",
    status = "i",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M

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

local config = require("codex_bridge.config")

local M = {
  installed = false,
}

local descriptions = {
  group = "Codex",
  start = "Codex: Start session",
  start_headless = "Codex: Start session without terminal",
  resume = "Codex: Resume session",
  send_file = "Codex: Send current file",
  send_selection = "Codex: Send selection",
  stop = "Codex: Stop session",
  status = "Codex: Inspect status",
}

local function lhs(prefix, key)
  if not key or key == "" then
    return nil
  end
  return prefix .. key
end

local function map(mode, key, rhs, desc)
  if not key then
    return
  end
  vim.keymap.set(mode, key, rhs, {
    desc = desc,
    silent = true,
  })
end

local function visual_line_range()
  local mode = vim.fn.mode()
  local start_line
  local end_line

  if mode == "v" or mode == "V" or mode == "\22" then
    start_line = vim.fn.line("v")
    end_line = vim.fn.line(".")
  else
    start_line = vim.fn.line("'<")
    end_line = vim.fn.line("'>")
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line
end

local function register_which_key(prefix)
  local ok, which_key = pcall(require, "which-key")
  if not ok then
    return
  end

  if type(which_key.add) == "function" then
    which_key.add({
      { prefix, group = descriptions.group, mode = { "n", "v" } },
    })
    return
  end

  if type(which_key.register) == "function" then
    which_key.register({
      [prefix] = { name = descriptions.group },
    }, { mode = { "n", "v" } })
  end
end

function M.setup()
  local cfg = config.get()
  local maps = cfg.keymaps or {}

  if maps.enabled == false or M.installed then
    return
  end

  local prefix = maps.prefix or "<leader>c"
  local bridge = require("codex_bridge")

  register_which_key(prefix)

  map("n", lhs(prefix, maps.start), function()
    bridge.start_session({ open_terminal = true })
  end, descriptions.start)

  map("n", lhs(prefix, maps.start_headless), function()
    bridge.start_session({ open_terminal = false })
  end, descriptions.start_headless)

  map("n", lhs(prefix, maps.resume), function()
    vim.ui.input({ prompt = "Codex thread id: " }, function(input)
      if input and input ~= "" then
        bridge.start_resume_session(input, { open_terminal = true })
      end
    end)
  end, descriptions.resume)

  map("n", lhs(prefix, maps.send), function()
    bridge.send()
  end, descriptions.send_file)

  map("v", lhs(prefix, maps.send), function()
    local line1, line2 = visual_line_range()
    bridge.send({ line1 = line1, line2 = line2, range = 2 })
  end, descriptions.send_selection)

  map("n", lhs(prefix, maps.stop), function()
    bridge.stop()
  end, descriptions.stop)

  map("n", lhs(prefix, maps.status), function()
    vim.print(bridge.status())
  end, descriptions.status)

  M.installed = true
end

return M

local config = require("codex_bridge.config")

local M = {}

local function get_lines(line1, line2)
  return vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
end

local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(name, ":.")
end

local function filetype()
  return vim.bo.filetype ~= "" and vim.bo.filetype or "text"
end

function M.selection(opts)
  opts = opts or {}
  local cfg = config.get()

  local line1 = opts.line1 or 1
  local line2 = opts.line2 or vim.api.nvim_buf_line_count(0)
  local range = opts.range or 0

  if range == 0 and cfg.prompt.include_file_on_empty_selection then
    line1 = 1
    line2 = vim.api.nvim_buf_line_count(0)
  end

  local lines = get_lines(line1, line2)
  return {
    file = current_file(),
    filetype = filetype(),
    line1 = line1,
    line2 = line2,
    text = table.concat(lines, "\n"),
  }
end

function M.format(prompt, selection)
  return table.concat({
    "User prompt:",
    prompt,
    "",
    "Context:",
    "File: " .. selection.file,
    "Range: " .. selection.line1 .. "-" .. selection.line2,
    "",
    "```" .. selection.filetype,
    selection.text,
    "```",
  }, "\n")
end

return M

local M = {}

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

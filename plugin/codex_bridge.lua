if vim.g.loaded_codex_bridge == 1 then
  return
end

vim.g.loaded_codex_bridge = 1

local codex_bridge = require("codex_bridge")

vim.api.nvim_create_user_command("CodexStartSession", function(opts)
  codex_bridge.start_session({ open_terminal = not opts.bang })
end, {
  bang = true,
  desc = "Start a Codex app-server session. Use ! to skip opening the terminal.",
})

vim.api.nvim_create_user_command("CodexStartResumeSession", function(opts)
  local session = opts.args ~= "" and opts.args or nil
  codex_bridge.start_resume_session(session, { open_terminal = not opts.bang })
end, {
  nargs = "?",
  bang = true,
  complete = "file",
  desc = "Start Codex and resume a session/thread id. Use ! to skip opening the terminal.",
})

vim.api.nvim_create_user_command("CodexSend", function(opts)
  codex_bridge.send({
    prompt = opts.args ~= "" and opts.args or nil,
    line1 = opts.line1,
    line2 = opts.line2,
    range = opts.range,
  })
end, {
  nargs = "*",
  range = true,
  desc = "Send the current buffer or visual selection to Codex with a prompt.",
})

vim.api.nvim_create_user_command("CodexStopSession", function()
  codex_bridge.stop()
end, {
  desc = "Stop the plugin-owned Codex app-server session.",
})

vim.api.nvim_create_user_command("CodexStatus", function()
  vim.print(codex_bridge.status())
end, {
  desc = "Print codex-bridge.nvim state.",
})

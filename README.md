# codex-bridge.nvim

Neovim plugin for sending the current file or selection to a
plugin-owned Codex app-server session.

## Requirements

- Neovim 0.12 or newer
- `codex` on `$PATH`

## Setup

```lua
require("codex_bridge").setup({
  terminal = {
    -- nil means auto-detect from $TERM, then fall back to common executables.
    command = nil,
  },
  keymaps = {
    enabled = true,
    prefix = "<leader>c",
  },
})
```

## Commands

- `:CodexStartSession` starts `codex app-server --listen unix://...` and opens
  a terminal running `codex --remote unix://...`.
- `:CodexStartSession!` starts the app-server without opening a terminal.
- `:CodexStartResumeSession {session_id}` resumes a known Codex session/thread
  id and opens the terminal with `codex resume --remote ...`.
- `:CodexSend {prompt}` sends the current file or visual selection with a
  prompt.
- `:CodexStopSession` stops the plugin-owned app-server.
- `:CodexStatus` prints current plugin state.

## Terminal Detection

By default, `codex-bridge.nvim` reads `$TERM` and maps common terminal names to
the command needed to launch an external `codex --remote` TUI. It currently
knows about popular terminal emulators, including Alacritty, Kitty, WezTerm, Ghostty, Foot, Contour, Rio, Xterm,
URxvt, tmux, and screen. If `$TERM` is too generic, it falls back to common
installed terminal executables.

Override the command explicitly:

```lua
require("codex_bridge").setup({
  terminal = {
    command = { "alacritty", "-e" },
  },
})
```

## Default keymaps

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>cs` | Normal | Start session and open terminal |
| `<leader>cS` | Normal | Start session without opening a terminal |
| `<leader>cr` | Normal | Resume a session by thread id |
| `<leader>cc` | Normal | Send current file |
| `<leader>cc` | Visual | Send selection |
| `<leader>cx` | Normal | Stop session |
| `<leader>ci` | Normal | Inspect status |

Disable defaults:

```lua
require("codex_bridge").setup({
  keymaps = {
    enabled = false,
  },
})
```

Override defaults:

```lua
require("codex_bridge").setup({
  keymaps = {
    prefix = "<leader>a",
    send = "s",
  },
})
```

## Statusline

```lua
require("codex_bridge").statusline()
```

For custom statusline integrations, use:

```lua
local state = require("codex_bridge").status()
```

or subscribe:

```lua
require("codex_bridge").on_status_change(function(state)
  -- state.status, state.busy, state.thread_id, state.socket_path, ...
end)
```

### Lualine

Simple integration:

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      require("codex_bridge").statusline,
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
```

Custom component:

```lua
local function codex_status()
  local state = require("codex_bridge").status()
  if state.status == "stopped" then
    return ""
  end
  return state.busy and "  busy" or "  " .. state.status
end

require("lualine").setup({
  sections = {
    lualine_x = {
      codex_status,
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
```

## Notes

If `which-key.nvim` is installed, `codex-bridge.nvim` registers the configured
keymap prefix as a `Codex` group so the prefix is labelled in the popup. This is
only a small metadata injection; the actual mappings are still regular Neovim
keymaps with `desc` fields, and `which-key` is not required.

The plugin uses Codex's Unix socket app-server transport, which is WebSocket
over a local Unix socket. The Codex app-server protocol is still evolving, so
the JSON-RPC code is intentionally isolated in `lua/codex_bridge/rpc.lua` and
`lua/codex_bridge/websocket.lua`.

local M = {}

local term_commands = {
  alacritty = { "alacritty", "-e" },
  ["xterm-kitty"] = { "kitty" },
  kitty = { "kitty" },
  wezterm = { "wezterm", "start", "--" },
  ["wezterm-gui"] = { "wezterm", "start", "--" },
  ghostty = { "ghostty", "-e" },
  foot = { "foot" },
  contour = { "contour", "spawn" },
  rio = { "rio", "-e" },
  xterm = { "xterm", "-e" },
  ["xterm-256color"] = { "xterm", "-e" },
  ["rxvt-unicode"] = { "urxvt", "-e" },
  ["screen"] = { "xterm", "-e" },
  ["screen-256color"] = { "xterm", "-e" },
  ["tmux"] = { "xterm", "-e" },
  ["tmux-256color"] = { "xterm", "-e" },
}

local executable_fallbacks = {
  { "alacritty", "-e" },
  { "kitty" },
  { "wezterm", "start", "--" },
  { "ghostty", "-e" },
  { "foot" },
  { "gnome-terminal", "--" },
  { "konsole", "-e" },
  { "xfce4-terminal", "-e" },
  { "xterm", "-e" },
}

local function is_executable(cmd)
  return vim.fn.executable(cmd[1]) == 1
end

local function normalize_term(term)
  term = (term or ""):lower()
  term = term:gsub("^%s+", ""):gsub("%s+$", "")
  return term
end

local function from_term(term)
  term = normalize_term(term)
  if term == "" then
    return nil
  end

  if term_commands[term] then
    return vim.deepcopy(term_commands[term]), "$TERM"
  end

  if term:find("alacritty", 1, true) then
    return vim.deepcopy(term_commands.alacritty), "$TERM"
  end
  if term:find("kitty", 1, true) then
    return vim.deepcopy(term_commands.kitty), "$TERM"
  end
  if term:find("wezterm", 1, true) then
    return vim.deepcopy(term_commands.wezterm), "$TERM"
  end
  if term:find("ghostty", 1, true) then
    return vim.deepcopy(term_commands.ghostty), "$TERM"
  end
  if term:find("foot", 1, true) then
    return vim.deepcopy(term_commands.foot), "$TERM"
  end

  return nil
end

local function from_installed_terminal()
  for _, cmd in ipairs(executable_fallbacks) do
    if is_executable(cmd) then
      return vim.deepcopy(cmd), "executable"
    end
  end
end

function M.resolve(terminal_config)
  terminal_config = terminal_config or {}

  if type(terminal_config.command) == "function" then
    return terminal_config.command()
  end

  if type(terminal_config.command) == "table" then
    return vim.deepcopy(terminal_config.command), "config"
  end

  if type(terminal_config.command) == "string" and terminal_config.command ~= "" then
    return { terminal_config.command }, "config"
  end

  local cmd, source = from_term(vim.env.TERM)
  if cmd and is_executable(cmd) then
    return cmd, source
  end

  return from_installed_terminal()
end

return M

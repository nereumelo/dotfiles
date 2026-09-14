-- Windows WezTerm (managed by bootstrap.ps1)
-- Targets WSL distro "arch" (wsl -l). Do not use Linux/WSLg wezterm.

local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "Tokyo Night"
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
})
config.font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }

-- Domain name is "WSL:" + the name from `wsl -l` (must be "arch").
config.wsl_domains = {
  {
    name = "WSL:arch",
    distribution = "arch",
    default_cwd = "~",
  },
}
config.default_domain = "WSL:arch"

return config

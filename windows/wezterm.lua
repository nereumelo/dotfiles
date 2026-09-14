-- Windows WezTerm (managed by bootstrap.ps1)
-- Targets WSL distro "arch" (wsl -l). Do not use Linux/WSLg wezterm.

local wezterm = require("wezterm")
local act = wezterm.action
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

-- Copy on mouse-up (Windows clipboard). Ctrl+C copies if there is a
-- selection, otherwise SIGINT. Ctrl+V pastes.
config.keys = {
  {
    key = "c",
    mods = "CTRL",
    action = wezterm.action_callback(function(window, pane)
      local text = window:get_selection_text_for_pane(pane)
      if text and text ~= "" then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
      else
        window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
      end
    end),
  },
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
}

-- Copy on select. Ctrl+click (and click on a hyperlink) opens in the
-- Windows default browser. Defining mouse_bindings replaces WezTerm
-- defaults, so OpenLinkAtMouseCursor must be listed explicitly.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.Multiple({
      act.OpenLinkAtMouseCursor,
      act.CompleteSelection("ClipboardAndPrimarySelection"),
    }),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()

return config

-- Environment variables
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland")

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- Noctalia-generated color scheme (Lua syntax, generated via user template)
-- pcall: silently ok if file doesn't exist yet — noctalia generates it after startup
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/noctalia-colors.lua")

-- Monitors
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })
hl.monitor({ output = "DP-1", mode = "2560x1440@239.97Hz", position = "auto", scale = 1.25 })
-- Catch-all for any unconfigured monitor (DP-1, external docks, projectors, etc.)
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto" })

-- Autostart (runs once on initial start only)
hl.on("hyprland.start", function()
  -- Symlink noctalia config to repo for live hot-reload (like Hyprland)
  hl.exec_cmd(
    "mkdir -p $HOME/.config/noctalia $HOME/.config/hypr && "
      .. "ln -sf $HOME/dotfiles/dynamic/noctalia/settings.json $HOME/.config/noctalia/settings.json && "
      .. "ln -sf $HOME/dotfiles/dynamic/noctalia/user-templates.toml $HOME/.config/noctalia/user-templates.toml"
  )
  hl.exec_cmd("kime")
  hl.exec_cmd("noctalia-shell")
  hl.exec_cmd("wl-paste --watch cliphist store")
end)

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "korean:ralt_hangul,korean:rctrl_hanja",
  },
  general = {
    gaps_in = 8,
    gaps_out = 16,
    border_size = 2,
    layout = "master",
  },
  animations = {
    enabled = false,
  },
  master = {
    new_status = "slave",
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = "rgb(000000)",
    close_special_on_empty = true,
  },
  binds = {
    hide_special_on_workspace_change = true,
  },
})

-- Keybinds
-- Launcher
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("noctalia-shell ipc call launcher toggle"))
hl.bind("SUPER + EQUAL", hl.dsp.exec_cmd("rofi -show calc -modi calc -no-show-match -no-sort"))

-- Clipboard manager: list history with rofi, decode selection, copy to clipboard
hl.bind(
  "SUPER + V",
  hl.dsp.exec_cmd("sh -c 'cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy'")
)

-- Window management
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + RETURN", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(
  "SUPER + SHIFT + S",
  hl.dsp.exec_cmd(
    "[float] sh -c 'QT_SCALE_FACTOR=$(hyprctl monitors -j | jq -r \".[] | select(.focused) | 1/.scale\") exec flameshot gui -s -c'"
  )
)
-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- Mouse: drag floating windows (Super + left click), resize (Super + right click)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus (Super + Arrow)
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "down" }))

-- Move window (Super + Shift + Arrow)
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.move({ direction = "down" }))

-- Resize window (Super + Ctrl + Arrow)
hl.bind("SUPER + CTRL + LEFT", hl.dsp.window.resize({ x = -20, y = 0 }), { repeating = true })
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.window.resize({ x = 20, y = 0 }), { repeating = true })
hl.bind("SUPER + CTRL + UP", hl.dsp.window.resize({ x = 0, y = -20 }), { repeating = true })
hl.bind("SUPER + CTRL + DOWN", hl.dsp.window.resize({ x = 0, y = 20 }), { repeating = true })

-- Workspaces 1-9
for i = 1, 9 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Window rules
hl.window_rule({
  match = { class = "xdg-desktop-portal-gtk" },
  max_size = { 10000, 600 },
})

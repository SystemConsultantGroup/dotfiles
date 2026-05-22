-- Environment variables
env("MOZ_ENABLE_WAYLAND", "1")
env("GDK_DPI_SCALE", "1")

env("XCURSOR_THEME", "Bibata-Modern-Ice")
env("XCURSOR_SIZE", "24")
env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
env("HYPRCURSOR_SIZE", "24")

-- Monitors
monitor("DP-1", "highrr", "auto", 1.25)
monitor("eDP-1", "preferred", "auto", 1.25)

-- Autostart
exec("kime")
exec("waybar")

-- Global config
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "korean:ralt_hangul,korean:rctrl_hanja",
  },
  general = {
    gaps_in = 8,
    gaps_out = 16,
    border_size = 2,
    col = {
      active_border = "rgb(dddddd)",
      inactive_border = "rgb(444444)",
    },
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
  },
})

-- Keybinds
-- Launcher
hl.bind("SUPER + RETURN", hl.dsp.exec("alacritty"))
hl.bind("SUPER + R", hl.dsp.exec("rofi -show drun"))
hl.bind("SUPER + EQUAL", hl.dsp.exec("rofi -show calc -modi calc -no-show-match -no-sort"))

-- Window management
hl.bind("SUPER + Q", hl.dsp.killactive())
hl.bind("ALT + RETURN", hl.dsp.fullscreen())
hl.bind("SUPER + SHIFT + S", hl.dsp.exec("flameshot gui"))
hl.bind("SUPER + P", hl.dsp.exec("pavucontrol"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec("brightnessctl set 5%+"), { held = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec("brightnessctl set 5%-"), { held = true })

-- Focus (Super + Arrow)
hl.bind("SUPER + LEFT", hl.dsp.movefocus("l"))
hl.bind("SUPER + RIGHT", hl.dsp.movefocus("r"))
hl.bind("SUPER + UP", hl.dsp.movefocus("u"))
hl.bind("SUPER + DOWN", hl.dsp.movefocus("d"))

-- Move window (Super + Shift + Arrow)
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.movewindow("l"))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.movewindow("r"))
hl.bind("SUPER + SHIFT + UP", hl.dsp.movewindow("u"))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.movewindow("d"))

-- Resize window (Super + Ctrl + Arrow)
hl.bind("SUPER + CTRL + LEFT", hl.dsp.resizeactive(-20, 0), { held = true })
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.resizeactive(20, 0), { held = true })
hl.bind("SUPER + CTRL + UP", hl.dsp.resizeactive(0, -20), { held = true })
hl.bind("SUPER + CTRL + DOWN", hl.dsp.resizeactive(0, 20), { held = true })

-- Workspaces 1-5
hl.bind("SUPER + 1", hl.dsp.workspace(1))
hl.bind("SUPER + 2", hl.dsp.workspace(2))
hl.bind("SUPER + 3", hl.dsp.workspace(3))
hl.bind("SUPER + 4", hl.dsp.workspace(4))
hl.bind("SUPER + 5", hl.dsp.workspace(5))

-- Move to workspace 1-5
hl.bind("SUPER + SHIFT + 1", hl.dsp.movetoworkspace(1))
hl.bind("SUPER + SHIFT + 2", hl.dsp.movetoworkspace(2))
hl.bind("SUPER + SHIFT + 3", hl.dsp.movetoworkspace(3))
hl.bind("SUPER + SHIFT + 4", hl.dsp.movetoworkspace(4))
hl.bind("SUPER + SHIFT + 5", hl.dsp.movetoworkspace(5))

-- Window rules
-- Constrain GTK file chooser dialogs to a reasonable size
hl.window_rule({
  match = { class = "xdg-desktop-portal-gtk" },
  max_size = { 900, 600 },
  min_size = { 500, 350 },
})

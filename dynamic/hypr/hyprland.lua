-- Environment variables
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_DPI_SCALE", "1")

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- Monitors
hl.monitor({ output = "DP-1",  mode = "highrr",     position = "auto", scale = 1.25 })
hl.monitor({ output = "eDP-1", mode = "preferred",  position = "auto", scale = 1.25 })

-- Autostart
hl.on("hyprland.start", function()
  hl.exec_cmd("kime")
  hl.exec_cmd("waybar")
end)

-- Input
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "korean:ralt_hangul,korean:rctrl_hanja",
  },
})

-- General
hl.config({
  general = {
    gaps_in = 8,
    gaps_out = 16,
    border_size = 2,
    resize_on_border = true,
    col = {
      active_border = "rgb(dddddd)",
      inactive_border = "rgb(444444)",
    },
    layout = "master",
  },
})

-- Animations
hl.config({
  animations = {
    enabled = false,
  },
})

-- Master layout
hl.config({
  master = {
    new_status = "slave",
  },
})

-- Misc
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = "rgb(000000)",
  },
})

-- Keybinds
-- Launcher
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + R",       hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("SUPER + EQUAL",   hl.dsp.exec_cmd("rofi -show calc -modi calc -no-show-match -no-sort"))

-- Window management
hl.bind("SUPER + Q",           hl.dsp.window.close())
hl.bind("ALT + RETURN",        hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind("SUPER + SHIFT + S",   hl.dsp.exec_cmd("flameshot gui"))
hl.bind("SUPER + P",           hl.dsp.exec_cmd("pavucontrol"))

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"),   { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),   { repeating = true })

-- Focus (Super + Arrow)
hl.bind("SUPER + LEFT",   hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + RIGHT",  hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + UP",     hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + DOWN",   hl.dsp.focus({ direction = "down" }))

-- Move window (Super + Shift + Arrow)
hl.bind("SUPER + SHIFT + LEFT",  hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + UP",    hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + DOWN",  hl.dsp.window.move({ direction = "down" }))

-- Resize window (Super + Ctrl + Arrow)
hl.bind("SUPER + CTRL + LEFT",  hl.dsp.window.resize({ x = -20, y = 0 }),   { repeating = true })
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.window.resize({ x = 20, y = 0 }),    { repeating = true })
hl.bind("SUPER + CTRL + UP",    hl.dsp.window.resize({ x = 0, y = -20 }),   { repeating = true })
hl.bind("SUPER + CTRL + DOWN",  hl.dsp.window.resize({ x = 0, y = 20 }),    { repeating = true })

-- Workspaces 1-5
for i = 1, 5 do
  hl.bind("SUPER + " .. i,      hl.dsp.focus({ workspace = i }))
  hl.bind("SUPER + SHIFT + " .. i,  hl.dsp.window.move({ workspace = i }))
end

-- Window rules
hl.window_rule({
  match = { class = "xdg-desktop-portal-gtk" },
  max_size = { 1000, 700 },
  min_size = { 500, 350 },
})

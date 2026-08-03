{
  pkgs,
  ...
}:
let
  swayConfig = pkgs.writeText "sway-config" ''
    set $mod Mod4

    include ~/.config/sway/noctalia

    gaps inner 16
    default_border pixel 2
    output DP-2 mode 2560x1440@239.97Hz scale 1.0

    bindsym $mod+Return exec alacritty
    bindsym $mod+r exec noctalia msg panel-toggle launcher
    bindsym $mod+v exec noctalia msg panel-toggle clipboard
    bindsym $mod+q kill
    bindsym $mod+Shift+q exit
    bindsym Mod1+Return fullscreen toggle
    bindsym $mod+Shift+s exec flameshot gui -s -c
    bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+
    bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
    floating_modifier $mod normal
    bindsym $mod+Left focus left ; $mod+Right focus right ; $mod+Up focus up ; $mod+Down focus down
    bindsym $mod+Shift+Left move left ; $mod+Shift+Right move right ; $mod+Shift+Up move up ; $mod+Shift+Down move down
    bindsym $mod+Control+Left resize shrink width 20px ; $mod+Control+Right resize grow width 20px ; $mod+Control+Up resize grow height 20px ; $mod+Control+Down resize shrink height 20px
    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+6 workspace number 6
    bindsym $mod+7 workspace number 7
    bindsym $mod+8 workspace number 8
    bindsym $mod+9 workspace number 9
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5
    bindsym $mod+Shift+6 move container to workspace number 6
    bindsym $mod+Shift+7 move container to workspace number 7
    bindsym $mod+Shift+8 move container to workspace number 8
    bindsym $mod+Shift+9 move container to workspace number 9
    input type:keyboard {
        xkb_layout us
        xkb_options korean:ralt_hangul,korean:rctrl_hanja
    }
    for_window [app_id="flameshot"] floating enable
    exec kime
    include /etc/sway/config.d/*
  '';
in
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export ELECTRON_OZONE_PLATFORM_HINT=wayland
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM=wayland
      export QT_QPA_PLATFORMTHEME=gtk3
      export XDG_SESSION_TYPE=wayland
      export XCURSOR_THEME=Bibata-Modern-Ice
      export XCURSOR_SIZE=24
      export XCURSOR_PATH="/run/current-system/sw/share/icons:~/.local/share/icons:~/.icons:/usr/share/icons"
    '';
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/sway/config - - - - ${swayConfig}"
  ];
}

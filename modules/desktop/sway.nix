_: {
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

  environment.etc."sway/config".source = ../../files/sway/config;

  # noctalia writes a default ~/.config/sway/config whenever the file is missing,
  # which would shadow /etc/sway/config. Keep the path a symlink so noctalia skips it.
  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/sway/config - - - - /etc/sway/config"
  ];
}

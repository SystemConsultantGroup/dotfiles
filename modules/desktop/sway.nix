{ pkgs, ... }:
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export NIXOS_OZONE_WL=1
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM=wayland
      export QT_QPA_PLATFORMTHEME=gtk3
      export XDG_SESSION_TYPE=wayland
      export XCURSOR_THEME=Bibata-Modern-Ice
      export XCURSOR_SIZE=24
      export XCURSOR_PATH="/run/current-system/sw/share/icons:~/.local/share/icons:~/.icons:/usr/share/icons"
    '';
  };

  environment.etc = {
    "sway/config".source = ../../files/sway/config;
    "sway/choose-highest-mode".source = ../../files/sway/choose-highest-mode;
    "sway/reload-noctalia-colors" = {
      source = ../../files/sway/reload-noctalia-colors;
      mode = "0755";
    };
  };

  systemd.user = {
    tmpfiles.rules = [
      "L+ %h/.config/sway/config - - - - /etc/sway/config"
    ];

    # Noctalia generates ~/.config/sway/noctalia after sway has started (and
    # rewrites it on wallpaper/theme changes) but sway never re-reads it on
    # its own, so watch the file and reload. KillMode=process lets the
    # revived choose-highest-mode daemon survive this oneshot.
    paths."sway-noctalia-colors" = {
      wantedBy = [ "sway-session.target" ];
      pathConfig.PathChanged = "%h/.config/sway/noctalia";
    };

    services."sway-noctalia-colors" = {
      path = [
        pkgs.coreutils
        pkgs.jq
        pkgs.procps
        pkgs.sway
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        KillMode = "process";
        ExecStart = "/etc/sway/reload-noctalia-colors";
      };
    };
  };
}

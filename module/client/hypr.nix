{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.pavucontrol
    pkgs.bibata-cursors
    pkgs.brightnessctl
  ];
  environment.variables.HYPRLAND_CONFIG = "/home/aperso/dotfiles/config/hypr/hyprland.conf";
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = ''
      ${pkgs.tuigreet}/bin/tuigreet --cmd 'uwsm start -e -D Hyprland hyprland-uwsm.desktop'
    '';
  };
  home-manager.users.aperso = {
    home.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
      GDK_SCALE = "1";
      GDK_DPI_SCALE = "1.5";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      QT_SCALE_FACTOR = "1.5";
    };
    gtk = {
      enable = true;
      cursorTheme = {
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
        size = 24;
      };
    };
    qt = {
      enable = true;
      platformTheme.name = "gtk";
    };
    programs.alacritty = {
      enable = true;
      settings = {
        window.padding = {
          x = 8;
          y = 10;
        };
      };
    };
    programs.rofi = {
      enable = true;
      plugins = [ pkgs.rofi-calc ];
    };
    services.flameshot = {
      enable = true;
      settings = {
        General = {
          disabledGrimWarning = true;
          useGrimAdapter = true;
        };
      };
    };
  };
}

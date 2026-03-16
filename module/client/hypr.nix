{
  pkgs,
  self,
  ...
}:
{
  environment.systemPackages = with pkgs; [ pavucontrol bibata-cursors brightnessctl ];
  environment.variables.HYPRLAND_CONFIG = "/home/aperso/dotfiles/config/hypr/hyprland.conf";
  programs.hyprland.enable = true;
  home-manager.users.aperso = {
    home.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
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
      plugins = with pkgs; [ rofi-calc ];
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

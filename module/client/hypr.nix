{
  pkgs,
  ...
}:
{
  environment.variables.HYPRLAND_CONFIG = "/home/aperso/dotfiles/config/hypr/hyprland.conf";
  programs.hyprland.enable = true;
  home-manager.users.aperso = {
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

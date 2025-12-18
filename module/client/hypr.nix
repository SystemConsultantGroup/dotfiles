{
  pkgs,
  ...
}:
{
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    rofi
  ];

  environment.variables.HYPRLAND_CONFIG = "/home/aperso/dotfiles/config/hypr/hyprland.conf";
}

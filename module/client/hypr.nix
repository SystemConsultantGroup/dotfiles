{
  pkgs,
  ...
}:
{
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    glib
    alacritty
    anyrun
  ];

  environment.variables.HYPRLAND_CONFIG = "/home/aperso/dotfiles/config/hypr/hyprland.conf";
}

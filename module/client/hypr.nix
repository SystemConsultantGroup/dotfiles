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
}

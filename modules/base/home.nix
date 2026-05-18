{
  config,
  pkgs,
  self,
  inputs,
  username,
  userFullName,
  ...
}:
let
  homeDir = config.users.users.${username}.home;
  flakeDir = "${self}";
in
{
  # System-level user definition
  users.users.${username} = {
    isNormalUser = true;
    description = userFullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
    ];
  };

  # Environment variables referencing user paths
  environment.variables = {
    NH_OS_FLAKE = "/home/scg/dotfiles";
    HYPRLAND_CONFIG = "${flakeDir}/dynamic/hypr/hyprland.conf";
  };
}

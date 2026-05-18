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
  dotfiles = "${self}";
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
    NH_OS_FLAKE = dotfiles;
    HYPRLAND_CONFIG = "${dotfiles}/dynamic/hypr/hyprland.conf";
  };
}

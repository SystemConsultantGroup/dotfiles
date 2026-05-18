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

  # Age identity (for any future age-managed secrets)
  age.identityPaths = [ "${homeDir}/.config/age/keys.txt" ];

  # Environment variables referencing user paths
  environment.variables = {
    NH_OS_FLAKE = flakeDir;
    HYPRLAND_CONFIG = "${flakeDir}/dynamic/hypr/hyprland.conf";
  };
}

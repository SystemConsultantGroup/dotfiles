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

  # Age identity and secrets
  age.identityPaths = [ "${homeDir}/.config/age/keys.txt" ];
  age.secrets.openrouter = {
    file = ../../secrets/openrouter.age;
    path = "${homeDir}/.config/openrouter/api-key";
    owner = username;
  };

  # Environment variables referencing user paths
  environment.variables = {
    NH_OS_FLAKE = flakeDir;
    HYPRLAND_CONFIG = "${flakeDir}/dynamic/hypr/hyprland.conf";
  };
}

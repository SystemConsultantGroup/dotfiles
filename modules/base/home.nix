{
  config,
  lib,
  username,
  userFullName,
  ...
}:
let
  homeDir = config.users.users.${username}.home;
  # Use home directory path instead of store path for runtime access
  dotfiles = "${homeDir}/dotfiles";
  stylixColors = config.lib.stylix.colors or null;
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
      "video"
      "render"
    ];
  };

  # Environment variables referencing user paths
  environment.variables = {
    NH_OS_FLAKE = dotfiles;
    HYPRLAND_CONFIG = "${dotfiles}/dynamic/hypr/hyprland.lua";
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    HYPRLAND_ACTIVE_BORDER = lib.mkIf (
      stylixColors != null
    ) "rgb(${stylixColors.base0E})";
    HYPRLAND_INACTIVE_BORDER = lib.mkIf (
      stylixColors != null
    ) "rgb(${stylixColors.base03})";
  };
}

{
  config,
  username,
  userFullName,
  ...
}:
let
  homeDir = config.users.users.${username}.home;
  # Use home directory path instead of store path for runtime access
  dotfiles = "${homeDir}/dotfiles";
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
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
  };
}

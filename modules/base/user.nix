{
  username,
  userFullName,
  ...
}:
{
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

  environment.variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
}

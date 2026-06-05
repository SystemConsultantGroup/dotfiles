{ lib, username, ... }:
{
  home-manager.users.${username}.qt = {
    enable = true;
    platformTheme.name = lib.mkForce "gtk";
  };
}

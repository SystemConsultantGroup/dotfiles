{ username, ... }:
{
  home-manager.users.${username}.services.flameshot.enable = true;
}

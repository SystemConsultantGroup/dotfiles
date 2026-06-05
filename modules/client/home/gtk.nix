{ username, ... }:
{
  home-manager.users.${username}.gtk.enable = true;
}

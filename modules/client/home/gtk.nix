{ pkgs, username, ... }:
{
  home-manager.users.${username}.gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
}

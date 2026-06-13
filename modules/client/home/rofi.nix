{ pkgs, username, ... }:
{
  home-manager.users.${username}.programs.rofi = {
    enable = true;
    plugins = [ pkgs.rofi-calc ];
  };
}

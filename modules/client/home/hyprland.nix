{ config, username, ... }:
{
  home-manager.users.${username}.home.sessionVariables = {
    HYPRLAND_CONFIG = "${config.users.users.${username}.home}/dotfiles/dynamic/hypr/hyprland.lua";
  };
}

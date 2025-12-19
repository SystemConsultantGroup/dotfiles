{ config, pkgs, ... }:

{
  home.username = "aperso";
  home.homeDirectory = "/home/aperso";

  # Packages you want to manage with Home Manager
  home.packages = with pkgs; [
    flameshot
  ];

  # Home Manager version
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}

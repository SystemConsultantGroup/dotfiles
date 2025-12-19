{ pkgs, ... }:

{
  imports = [
    ./font.nix
    ./hypr.nix
  ];

  services.xserver.xkb.layout = "us";

  i18n.inputMethod = {
    enable = true;
    type = "kime";
    kime.iconColor = "White";
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vesktop
    firefox
    zed-editor
    nixd
    nil
  ];

  # Add Home Manager module
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.aperso = import ./home.nix;
}

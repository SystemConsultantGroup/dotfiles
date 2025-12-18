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
    discord
    firefox
    zed-editor
    nixd
    nil
  ];
}

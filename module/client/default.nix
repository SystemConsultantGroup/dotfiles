{ pkgs, ... }:
let
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
    sha256 = "03cjglf896q8cwx3x4j0q08yf9di0xzd0f52qz4v3gd6lva7zgzy";
  };
in
{
  imports = [
    ./font.nix
    ./hypr.nix
    (import "${home-manager}/nixos")
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

  home-manager.users.aperso.home.stateVersion = "25.11";
}

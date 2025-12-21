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

  services.gnome.gnome-keyring.enable = true;

  services.xserver.xkb.layout = "us";

  i18n.inputMethod = {
    enable = true;
    type = "kime";
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vesktop
    firefox
    zed-editor
    vscode-fhs
    nixd
    nil
  ];

  # Enable PipeWire audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Enable audio control media keys
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp";

  home-manager.users.aperso.home.stateVersion = "25.11";
}

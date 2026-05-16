{
  pkgs,
  self,
  kime,
  ...
}:
{
  imports = [
    ./font.nix
    ./hypr.nix
  ];
  nixpkgs.overlays = [
    (final: prev: {
      kime = prev.callPackage ./pkgs/kime.nix { kime-src = kime; };
    })
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
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp";
  home-manager.users.aperso = {
    home.file.".bashrc".source = "${self}/config/bash/.bashrc";
    home.stateVersion = "25.11";
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "apersomany";
          email = "aperso@aperso.dev";
        };
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.base;
in
{
  imports = [ ./user.nix ];

  options.dotfiles.base = {
    podman.enable = lib.mkEnableOption "Podman container engine";
    nixld.enable = lib.mkEnableOption "nix-ld for running foreign binaries";
  };

  config = lib.mkMerge [
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          auto-optimise-store = true;
        };
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };

      nixpkgs.config.allowUnfree = true;
      security.sudo.wheelNeedsPassword = false;
      i18n.defaultLocale = "en_US.UTF-8";

      networking = {
        nameservers = [
          "1.1.1.1"
          "8.8.8.8"
          "1.0.0.1"
          "8.8.4.4"
        ];
        networkmanager.enable = lib.mkDefault true;
        nftables.enable = true;
        firewall.enable = false;
      };

      environment.systemPackages = [
        pkgs.bat
        pkgs.bun
        pkgs.fd
        pkgs.fzf
        pkgs.git
        pkgs.gh
        pkgs.devenv
        pkgs.jq
        pkgs.mtr
        pkgs.nh
        pkgs.nodejs
        pkgs.opencode
        pkgs.ripgrep
        pkgs.unzip
        pkgs.uv
        pkgs.yazi
        pkgs.zip
      ];
    }
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    })
    (lib.mkIf cfg.nixld.enable {
      programs.nix-ld = {
        enable = true;
        libraries = [
          pkgs.zlib
          pkgs.stdenv.cc.cc
        ];
      };
    })
  ];
}

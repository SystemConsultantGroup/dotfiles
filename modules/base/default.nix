{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotfiles.base;
in
{
  imports = [
    ./user.nix
    inputs.home-manager.nixosModules.home-manager
    ./home
  ];

  options.dotfiles.base.podman.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable Podman container engine";
  };

  config = lib.mkMerge [
    {
      home-manager.backupFileExtension = "backup";

      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          auto-optimise-store = true;
          trusted-users = [
            "root"
            "@wheel"
          ];
          allow-unfree = true;
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

      programs.nix-ld = {
        enable = true;
        libraries = [
          pkgs.zlib
          pkgs.stdenv.cc.cc
        ];
      };

      environment.systemPackages = [
        pkgs.alacritty.terminfo
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
  ];
}

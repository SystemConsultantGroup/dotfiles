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
    ./home
    inputs.home-manager.nixosModules.home-manager
  ];

  options.dotfiles.base = {
    podman.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Podman container engine";
    };
    openssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the OpenSSH server daemon";
    };
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
        };
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };

      security.sudo.wheelNeedsPassword = false;

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

      nixpkgs.config.allowUnfree = true;

      programs.nix-ld = {
        enable = true;
        libraries = [
          pkgs.stdenv.cc.cc
          pkgs.zlib
        ];
      };

      environment.systemPackages = [
        pkgs.alacritty.terminfo
      ];
    }
    (lib.mkIf cfg.openssh.enable {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = true;
          KbdInteractiveAuthentication = true;
        };
      };
    })
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
    })
  ];
}

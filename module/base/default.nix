{ pkgs, ... }:
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

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  networking = {
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "1.0.0.1"
      "8.8.4.4"
    ];
    networkmanager.enable = true;
    nftables.enable = true;
    firewall.enable = false;
  };

  users.users.aperso = {
    isNormalUser = true;
    description = "Donghyun Shin";
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
    ];
  };

  environment.systemPackages = [
    pkgs.zip
    pkgs.unzip
    pkgs.git
    pkgs.gh
    pkgs.nh
    pkgs.opencode
    pkgs.yazi
  ];

  environment.variables.NH_OS_FLAKE = "/home/aperso/dotfiles";
}

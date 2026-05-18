{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.agenix.nixosModules.default
    ./home.nix
  ];

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
    networkmanager.enable = lib.mkDefault true;
    nftables.enable = true;
    firewall.enable = false;
  };

  environment.systemPackages = [
    pkgs.zip
    pkgs.unzip
    pkgs.git
    pkgs.gh
    pkgs.devenv
    pkgs.nh
    pkgs.opencode
    pkgs.yazi
  ];

}

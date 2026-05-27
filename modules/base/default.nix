{
  pkgs,
  lib,
  ...
}:
{
  imports = [
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

  security.sudo.wheelNeedsPassword = false;

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
    pkgs.yazi
    pkgs.zip
  ];

}

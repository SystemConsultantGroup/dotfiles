{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" "1.0.0.1" "8.8.4.4" ];
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  users.users.aperso = {
    isNormalUser = true;
    description = "Donghyun Shin";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  environment.systemPackages = with pkgs; [
    zip
    unzip
    git
    gh
    nh
    opencode
  ];

  environment.variables.NH_OS_FLAKE = "/home/aperso/dotfiles";
}

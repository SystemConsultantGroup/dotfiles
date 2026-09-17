{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/base.nix
    ./modules/networking.nix
    ./modules/routing.nix
    ./modules/firewall.nix
    ./modules/nftables.nix
    ./modules/storage.nix
    ./modules/services.nix
    ./modules/pi.nix
  ];

  networking.hostName = "router";
  time.timeZone = "Asia/Seoul";

  boot = {
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  system.stateVersion = "25.11";
}

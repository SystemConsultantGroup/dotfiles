{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./storage.nix
    ../../modules/base
    ../../modules/router
    ../../modules/server
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

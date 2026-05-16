{ pkgs, ... }:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    ../../module/base
    ../../module/client
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

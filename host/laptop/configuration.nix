{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../module/base
    ../../module/client
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "laptop";
  
  hardware.sensor.iio.enable = true;

  services.asusd = {
    enable = true;
    enableUserService = true;
  };

  time.timeZone = "Asia/Seoul";

  system.stateVersion = "25.11";
}

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../module/base
    ../../module/server
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "scg-server";
  networking.interfaces.enp5s0.ipv4.addresses = [{
    address = "115.145.150.218";
    prefixLength = 24;
  }];
  networking.defaultGateway = "115.145.150.1";

  time.timeZone = "Asia/Seoul";

  system.stateVersion = "25.05";
}

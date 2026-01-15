{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../module/base
    ../../module/client
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "scg-client";
  networking.interfaces.eno1.ipv4.addresses = [{
    address = "115.145.150.190";
    prefixLength = 24;
  }];
  networking.defaultGateway = "115.145.150.1";

  time.timeZone = "Asia/Seoul";

  system.stateVersion = "25.05";
}

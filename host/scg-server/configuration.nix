{ config, pkgs, ... }:

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

  environment.systemPackages = with pkgs; [
    cloudflared
  ];

  users.users.cloudflare = {
    isSystemUser = true;
    group = "cloudflare";
  };

  users.groups.cloudflare = {};

  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "cloudflare";
      Group = "cloudflare";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token eyJhIjoiYTNlMWE3ZDlmMjI0ZTQyYmQ0MWIzMDM5ZDZiMDg2YjkiLCJ0IjoiNDIyNzNiYzEtODdiMi00MzUxLWExYTQtNGM1OWEwMWY0MGJlIiwicyI6Ik56TXhOVE13TkdRdE5qa3daUzAwTmpZd0xUZzBaRGt0TkRneE1XUTVPRFJrWm1ZMyJ9";
    };
  };

  system.stateVersion = "25.05";
}

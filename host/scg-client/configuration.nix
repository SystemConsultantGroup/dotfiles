{ config, pkgs, ... }:

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

  sops.defaultSopsFile = ../../secret/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets."cloudflare_tunnel/scg_client" = {
     owner = "cloudflare";
  };

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
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.cloudflared}/bin/cloudflared tunnel run --token $(cat ${config.sops.secrets."cloudflare_tunnel/scg_client".path})'";
    };
  };

  system.stateVersion = "25.05";
}

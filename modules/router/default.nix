{ pkgs, ... }:
let
  wanAddresses = [
    "115.145.150.182"
    "115.145.150.193"
    "115.145.150.204"
    "115.145.150.203"
    "115.145.150.202"
    "115.145.150.201"
    "115.145.150.200"
    "115.145.150.199"
    "115.145.150.198"
    "115.145.150.197"
    "115.145.150.196"
    "115.145.150.195"
    "115.145.150.194"
  ];
in
{
  imports = [
    ./firewall.nix
    ./lease-sweep.nix
    ./nftables.nix
    ./routing.nix
  ];

  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    nftables.enable = true;
    firewall.enable = false;
  };

  services.cloudflare-warp.enable = true;

  systemd.services.ethtool-enp0s25 = {
    description = "Disable TSO on enp0s25";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.ethtool}/bin/ethtool -K enp0s25 tso off
    '';
  };

  router = {
    enable = true;
    interfaces = {
      enp0s25 = {
        ipv4.addresses = map (address: {
          inherit address;
          prefixLength = 24;
        }) wanAddresses;
        ipv4.routes = [
          {
            extraArgs = [
              "default"
              "via"
              "115.145.150.1"
            ];
          }
        ];
      };
      enp5s0.ipv4 = {
        addresses = [
          {
            address = "10.0.0.1";
            prefixLength = 8;
            dns = [
              "1.1.1.1"
              "1.0.0.1"
              "8.8.8.8"
              "8.8.4.4"
            ];
            gateways = [ "10.0.0.1" ];
            keaSettings.option-data = [
              {
                name = "domain-name-servers";
                code = 6;
                csv-format = true;
                space = "dhcp4";
                data = "1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4";
              }
              {
                name = "routers";
                code = 3;
                csv-format = true;
                space = "dhcp4";
                data = "10.0.0.1";
              }
            ];
          }
        ];
        kea.enable = true;
      };
    };
  };
}

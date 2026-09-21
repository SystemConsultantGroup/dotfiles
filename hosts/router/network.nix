{
  lib,
  pkgs,
  ...
}:
let
  wan = {
    interface = "enp0s25";
    addresses = [
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
    prefixLength = 24;
    gateway = "115.145.150.1";
  };

  japaneseEgress = {
    interface = "proton-jp";
    meshInstance = "scg-skku-router-jp";
    hostInterface = "meshjp-host";
    peerInterface = "meshjp-peer";
    routeTable = "200";
  };

  lan = {
    interface = "enp5s0";
    address = "10.0.0.1";
    prefixLength = 16;
    cidr = "10.0.0.0/16";
    netmask = "255.255.0.0";
    domain = "home.arpa";
    dhcpPool = {
      start = "10.0.0.17";
      end = "10.0.255.239";
    };
  };
in
{
  dotfiles.router = {
    inherit lan wan;
    cloudflare = {
      inherit japaneseEgress;
      mesh.instance = "scg-skku-router";
      officeDetection = {
        address = "10.255.0.1";
        cidr = "10.255.0.1/32";
        port = 10443;
      };
    };
  };

  networking.wireguard.interfaces.${japaneseEgress.interface} = {
    ips = [ "10.2.0.2/32" ];
    privateKeyFile = "/var/lib/secrets/wg-JP-FREE-33.key";
    socketNamespace = "mesh-${japaneseEgress.meshInstance}";
    interfaceNamespace = "mesh-${japaneseEgress.meshInstance}";
    table = japaneseEgress.routeTable;
    metric = 100;
    peers = [
      {
        name = "jp-free-33";
        publicKey = "qhEO97nKps2D1JsZjw3AiSuVJVbrBROV3Gpvong0hgI=";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "149.88.103.161:51820";
        persistentKeepalive = 25;
      }
    ];
  };

  systemd.services."wireguard-${japaneseEgress.interface}" = {
    after = [ "netns-mesh-${japaneseEgress.meshInstance}.service" ];
    requires = [ "netns-mesh-${japaneseEgress.meshInstance}.service" ];
    partOf = [ "netns-mesh-${japaneseEgress.meshInstance}.service" ];
  };

  systemd.services."ethtool-${wan.interface}" = {
    description = "Disable TSO on ${wan.interface}";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe pkgs.ethtool} -K ${lib.escapeShellArg wan.interface} tso off
    '';
  };

  router.interfaces = {
    ${wan.interface} = {
      ipv4.addresses = map (address: {
        inherit address;
        inherit (wan) prefixLength;
      }) wan.addresses;
      ipv4.routes = [
        {
          extraArgs = [
            "default"
            "via"
            wan.gateway
          ];
        }
      ];
    };
    ${lan.interface}.ipv4.addresses = [
      { inherit (lan) address prefixLength; }
    ];
  };
}

{
  lib,
  pkgs,
  ...
}:
let
  site = builtins.fromTOML (builtins.readFile ./site.toml);
  inherit (site) lan wan;

  japaneseEgress = {
    interface = "proton-jp";
    meshInstance = "scg-skku-router-jp";
    hostInterface = "meshjp-host";
    peerInterface = "meshjp-peer";
    routeTable = "200";
  };

in
{
  dotfiles.router = {
    inherit lan wan;
    cloudflare = {
      inherit japaneseEgress;
      inherit (site.cloudflare) mesh officeDetection;
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

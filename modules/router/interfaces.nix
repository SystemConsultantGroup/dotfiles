{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) lan wan;
in
{
  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    nftables.enable = true;
    firewall.enable = false;
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

  router = {
    enable = true;
    interfaces = {
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
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  site = builtins.fromTOML (builtins.readFile ./site.toml);
in
{
  dotfiles.router = {
    inherit (site)
      lan
      wan
      warp
      officeDetection
      be
      ;

    upstreams = {
      skku = {
        label = "SKKU";
        interface = site.wan.interface;
        gateway = site.wan.gateway;
        table = 200;
        id = 1;
      };
      warp-jp = {
        label = "WARP Japan";
        interface = config.dotfiles.router.warp.warp-jp.link;
        gateway = config.dotfiles.router.warp.warp-jp.gateway;
        table = 201;
        id = 2;
      };
    };

    ingresses = {
      office = {
        label = "Office Internet exit";
        interface = site.lan.interface;
        network = site.lan.cidr;
        kind = "office";
        defaultUpstream = site.routingDefaults.office;
        returnId = 1;
        returnTable = 210;
      };
      mesh = {
        label = "Base Internet exit";
        interface = config.dotfiles.router.warp.mesh.link;
        gateway = config.dotfiles.router.warp.mesh.gateway;
        network = config.dotfiles.router.meshCidr;
        kind = "mesh";
        defaultUpstream = site.routingDefaults.mesh;
        returnId = 2;
        returnTable = 211;
      };
      mesh-yt = {
        label = "mesh-yt Internet exit";
        interface = config.dotfiles.router.warp.mesh-yt.link;
        gateway = config.dotfiles.router.warp.mesh-yt.gateway;
        network = config.dotfiles.router.meshCidr;
        kind = "mesh";
        defaultUpstream = site.routingDefaults.mesh-yt;
        returnId = 3;
        returnTable = 212;
      };
    };
  };

  systemd.services."ethtool-${site.wan.interface}" = {
    description = "Disable TSO on ${site.wan.interface}";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe pkgs.ethtool} -K ${lib.escapeShellArg site.wan.interface} tso off
    '';
  };
}

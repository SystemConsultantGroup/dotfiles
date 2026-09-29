{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) meshCidr warp;
  ip = lib.getExe' pkgs.iproute2 "ip";

  # Policy-routing table for Mesh clients that exit in Japan.
  japanTable = "201";

  waywarpState = index: "/var/lib/waywarp/${toString index}";

  mkInstance = _: instance: {
    inherit (instance) index;
    access.bridge = { };
    inherit (instance) location via environmentFile;
  };

  # Extra unit settings layered on the upstream Waywarp units.
  mkUnit =
    name: instance: routes:
    lib.nameValuePair "waywarp-${name}" {
      unitConfig = {
        # Imported Mesh registrations must exist before the first start;
        # otherwise Waywarp would enroll an unrelated consumer device.
        ConditionPathExists =
          lib.optional instance.imported "${waywarpState instance.index}/registration/reg.json"
          ++ lib.optional (instance.environmentFile != null) instance.environmentFile;
      };
      # Routes through the bridge vanish with its link, so add them each time
      # the instance reports ready.
      serviceConfig.ExecStartPost = [
        (pkgs.writeShellScript "waywarp-${name}-routes" (
          lib.concatMapStrings (route: ''
            ${ip} -4 route replace ${route} via ${instance.gateway} dev ${instance.link} onlink
          '') routes
        ))
      ];
    };
in
{
  services.waywarp.instances = lib.mapAttrs mkInstance warp;

  systemd.services =
    lib.listToAttrs [
      # Mesh clients and the office LAN reach each other through the main table.
      (mkUnit "mesh" warp.mesh [ meshCidr ])
      # Replies from warp-jp return to the Japanese Mesh node.
      (mkUnit "mesh-jp" warp.mesh-jp [ "${meshCidr} table ${japanTable}" ])
      (mkUnit "warp-jp" warp.warp-jp [ "default table ${japanTable}" ])
    ]
    // {
      router-policy-routing = {
        description = "Policy routing for Japanese Mesh egress";
        wantedBy = [ "multi-user.target" ];
        before = [
          "waywarp-mesh-jp.service"
          "waywarp-warp-jp.service"
        ];
        requiredBy = [
          "waywarp-mesh-jp.service"
          "waywarp-warp-jp.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        # Traffic entering from either Japanese link uses only the Japanese
        # table. The blackhole keeps it off the WAN while warp-jp is down.
        script = ''
          ${ip} -4 route replace blackhole default table ${japanTable} metric 4096
          for link in ${warp.mesh-jp.link} ${warp.warp-jp.link}; do
            while ${ip} -4 rule del iif "$link" lookup ${japanTable} 2>/dev/null; do :; done
            ${ip} -4 rule add pref 1000 iif "$link" lookup ${japanTable}
          done
        '';
        preStop = ''
          for link in ${warp.mesh-jp.link} ${warp.warp-jp.link}; do
            while ${ip} -4 rule del iif "$link" lookup ${japanTable} 2>/dev/null; do :; done
          done
          ${ip} -4 route flush table ${japanTable} 2>/dev/null || true
        '';
      };
    };
}

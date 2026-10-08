{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) meshCidr warp;
  ip = lib.getExe' pkgs.iproute2 "ip";

  # Cloudflare's reserved IPv6 device range is not account-configurable.
  meshCidr6 = "2606:4700:cf1:1000::/64";

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
    name: instance: routes4: routes6:
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
          ''
            set -eu
          ''
          + lib.concatMapStrings (route: ''
            ${ip} -4 route replace ${route} via ${instance.gateway} dev ${instance.link} onlink
          '') routes4
          + lib.concatMapStrings (route: ''
            ${ip} -6 route replace ${route} via ${instance.gateway6} dev ${instance.link} onlink
          '') routes6
        ))
      ];
    };
in
{
  services.waywarp.instances = lib.mapAttrs mkInstance warp;

  systemd.services =
    lib.listToAttrs [
      # The main table also returns router-generated ICMP errors to Mesh clients.
      (mkUnit "mesh" warp.mesh [ meshCidr ] [ meshCidr6 ])
      # Replies from warp-jp return to the Japanese Mesh node in both families.
      (mkUnit "mesh-jp" warp.mesh-jp
        [ "${meshCidr} table ${japanTable}" ]
        [
          "${meshCidr6} table ${japanTable}"
        ]
      )
      (mkUnit "warp-jp" warp.warp-jp [ "default table ${japanTable}" ] [ "default table ${japanTable}" ])
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
          for family in -4 -6; do
            ${ip} "$family" route replace blackhole default table ${japanTable} metric 4096
            for link in ${warp.mesh-jp.link} ${warp.warp-jp.link}; do
              while ${ip} "$family" rule del iif "$link" lookup ${japanTable} 2>/dev/null; do :; done
              ${ip} "$family" rule add pref 1000 iif "$link" lookup ${japanTable}
            done
          done
        '';
        preStop = ''
          for family in -4 -6; do
            for link in ${warp.mesh-jp.link} ${warp.warp-jp.link}; do
              while ${ip} "$family" rule del iif "$link" lookup ${japanTable} 2>/dev/null; do :; done
            done
            ${ip} "$family" route flush table ${japanTable} 2>/dev/null || true
          done
        '';
      };
    };
}

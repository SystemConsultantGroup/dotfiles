{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router)
    meshCidr
    warp
    upstreams
    ingresses
    ;
  ip = lib.getExe' pkgs.iproute2 "ip";
  waywarpState = index: "/var/lib/waywarp/${toString index}";

  mkInstance = _: instance: {
    inherit (instance)
      index
      location
      via
      environmentFile
      ;
    access.bridge = { };
  };

  mkUnit =
    name: instance:
    let
      routes =
        lib.optional (name == "mesh") meshCidr
        ++ map (upstream: "default table ${toString upstream.table}") (
          lib.filter (upstream: upstream.interface == instance.link) (lib.attrValues upstreams)
        )
        ++ map (ingress: "${ingress.network} table ${toString ingress.returnTable}") (
          lib.filter (ingress: ingress.interface == instance.link) (lib.attrValues ingresses)
        );
    in
    lib.nameValuePair "waywarp-${name}" {
      unitConfig.ConditionPathExists =
        lib.optional instance.imported "${waywarpState instance.index}/registration/reg.json"
        ++ lib.optional (instance.environmentFile != null) instance.environmentFile;
      after = [ "router-policy-routing.service" ];
      requires = [ "router-policy-routing.service" ];
      serviceConfig.ExecStartPost = [
        (pkgs.writeShellScript "waywarp-${name}-routes" (
          ''
            set -eu
          ''
          + lib.concatMapStrings (route: ''
            ${ip} -4 route replace ${route} via ${instance.gateway} dev ${instance.link} onlink
          '') routes
          + lib.optionalString (name == "mesh") ''
            # Control-plane return path for router-generated IPv6 errors only.
            # There is no IPv6 Internet default or downstream forwarding.
            ${ip} -6 route replace 2606:4700:cf1:1000::/64 via ${instance.gateway6} dev ${instance.link} onlink
          ''
        ))
      ];
    };
in
{
  assertions = [
    {
      assertion =
        builtins.length (lib.attrValues warp)
        == builtins.length (lib.unique (map (instance: instance.index) (lib.attrValues warp)));
      message = "Waywarp instances must use unique bridge indices";
    }
  ];
  services.waywarp.instances = lib.mapAttrs mkInstance warp;
  systemd.services = lib.mapAttrs' mkUnit warp;
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) upstreams ingresses warp;
  ip = lib.getExe' pkgs.iproute2 "ip";
  tables =
    map (upstream: upstream.table) (lib.attrValues upstreams)
    ++ map (ingress: ingress.returnTable) (lib.attrValues ingresses);
  mkRule = mask: mark: table: priority: ''
    while ${ip} -4 rule del pref ${toString priority} fwmark ${toString mark}/${mask} lookup ${toString table} 2>/dev/null; do :; done
    ${ip} -4 rule add pref ${toString priority} fwmark ${toString mark}/${mask} lookup ${toString table}
  '';
in
{
  assertions = [
    {
      assertion =
        builtins.length tables == builtins.length (lib.unique tables)
        && lib.all (
          table:
          !(lib.elem table [
            253
            254
            255
          ])
        ) tables;
      message = "Router upstream and return tables must be unique and must not use built-in routing tables";
    }
    {
      assertion = lib.all (ingress: builtins.hasAttr ingress.defaultUpstream upstreams) (
        lib.attrValues ingresses
      );
      message = "Every router ingress must reference an existing default upstream";
    }
    {
      assertion =
        builtins.length (lib.attrValues upstreams)
        == builtins.length (lib.unique (map (upstream: upstream.id) (lib.attrValues upstreams)))
        &&
          builtins.length (lib.attrValues ingresses)
          == builtins.length (lib.unique (map (ingress: ingress.returnId) (lib.attrValues ingresses)));
      message = "Router upstream IDs and ingress return IDs must each be unique";
    }
  ];

  systemd.services.router-policy-routing = {
    description = "Fail-closed IPv4 exit and return routing tables";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    before = map (name: "waywarp-${name}.service") (lib.attrNames warp);
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      ${lib.concatMapStrings (table: ''
        ${ip} -4 route replace blackhole default table ${toString table} metric 4096
      '') tables}
      ${lib.concatMapStrings (upstream: mkRule "0x00ff0000" (upstream.id * 65536) upstream.table 900) (
        lib.attrValues upstreams
      )}
      ${lib.concatMapStrings (
        ingress: mkRule "0xff000000" (ingress.returnId * 16777216) ingress.returnTable 910
      ) (lib.attrValues ingresses)}

      # Remove the previous ingress-pinned Japan policy only after the marked
      # tables exist. IPv6 is no longer a downstream forwarding service.
      for link in ${warp.mesh-yt.link} ${warp.warp-jp.link}; do
        while ${ip} -4 rule del pref 1000 iif "$link" lookup 201 2>/dev/null; do :; done
        while ${ip} -6 rule del pref 1000 iif "$link" lookup 201 2>/dev/null; do :; done
      done
      ${ip} -6 route flush table 201 2>/dev/null || true
    '';
    # Do not tear down rules or blackholes on a service restart: connections
    # retain their routing labels, and losing a lookup must never leak to the main table.
  };
}

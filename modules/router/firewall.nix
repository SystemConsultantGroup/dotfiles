{ config, lib, ... }:
let
  inherit (config.dotfiles.router)
    lan
    warp
    officeDetection
    ingresses
    upstreams
    meshCidr
    ;
  meshLinks = map (ingress: ingress.interface) (
    lib.filter (ingress: ingress.kind == "mesh") (lib.attrValues ingresses)
  );
  meshSet = lib.concatMapStringsSep ", " (link: ''"${link}"'') meshLinks;
  restrictedSet = lib.concatMapStringsSep ", " (instance: ''"${instance.link}"'') (
    lib.filter (instance: instance.link != warp.mesh.link) (lib.attrValues warp)
  );
in
{
  # Nix owns the fixed safety envelope. The be owns only inet router_be, whose
  # connection labels restore packet marks; Waywarp owns its namespace tables.
  networking.nftables.tables.filter = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority filter; policy accept;

        ip daddr ${officeDetection.address} tcp dport ${toString officeDetection.port} iifname "${lan.interface}" accept
        ip daddr ${officeDetection.address} tcp dport ${toString officeDetection.port} drop

        ${lib.concatMapStrings (ingress: ''
          ip daddr ${lan.address} tcp dport { 53, 443 } iifname "${ingress.interface}" ip saddr ${ingress.network} accept
          ip daddr ${lan.address} udp dport 53 iifname "${ingress.interface}" ip saddr ${ingress.network} accept
        '') (lib.attrValues ingresses)}
        ip daddr ${lan.address} tcp dport 443 drop

        # Preserve IPv6 bridge neighbor discovery for Waywarp internals, then
        # drop other unsolicited traffic on the selective/exit links.
        iifname { ${restrictedSet} } ip6 hoplimit 255 icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert } accept
        iifname { ${restrictedSet} } ct state != { established, related } drop
      }

      chain ingress_source {
        # A Mesh link can also be an Internet exit. Its tracked replies have
        # public source addresses, unlike new connections from Mesh clients.
        ct direction reply ct state { established, related } return
        ${lib.concatMapStrings (ingress: ''
          iifname "${ingress.interface}" ip saddr != ${ingress.network} drop
        '') (lib.attrValues ingresses)}
      }

      chain selected_exit {
        ${lib.concatMapStrings (upstream: ''
          meta mark & 0x00ff0000 == ${toString (upstream.id * 65536)} oifname "${upstream.interface}" return
        '') (lib.attrValues upstreams)}
        # This check precedes established/related acceptance: a lost policy
        # lookup must not let an existing WARP connection leak onto the WAN.
        drop
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        meta nfproto ipv6 reject with icmpv6 type admin-prohibited
        jump ingress_source
        # During first activation the controller may not have installed its
        # classifier yet. Even old established Internet flows must fail closed
        # until their packet has a selected exit; internal traffic is exempt.
        ${lib.concatMapStrings (ingress: ''
          ct direction original iifname "${ingress.interface}" ip daddr != { ${lan.cidr}, ${meshCidr}, ${officeDetection.cidr} } meta mark & 0x00ff0000 == 0 drop
        '') (lib.attrValues ingresses)}
        meta mark & 0x00ff0000 == 0x00ff0000 drop
        ct direction original meta mark & 0x00ff0000 != 0 jump selected_exit
        ct state vmap { established : accept, related : accept, invalid : drop }

        # Internal destinations bypass the chosen Internet exit.
        iifname "${lan.interface}" oifname { ${meshSet} } accept
        iifname { ${meshSet} } oifname "${lan.interface}" accept

        ${lib.concatMapStrings (
          ingress:
          lib.concatMapStrings (upstream: ''
            iifname "${ingress.interface}" meta mark & 0x00ff0000 == ${toString (upstream.id * 65536)} oifname "${upstream.interface}" accept
          '') (lib.attrValues upstreams)
        ) (lib.attrValues ingresses)}
      }
    '';
  };
}

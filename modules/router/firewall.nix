{ config, ... }:
let
  inherit (config.dotfiles.router)
    lan
    wan
    warp
    officeDetection
    ;
in
{
  # Each table is replaced atomically on reload. Tables owned by other
  # programs, such as Waywarp's, are left untouched.
  networking.nftables.tables.filter = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority filter; policy accept;

        ip daddr ${officeDetection.address} tcp dport ${toString officeDetection.port} iifname "${lan.interface}" accept
        ip daddr ${officeDetection.address} tcp dport ${toString officeDetection.port} drop

        # IPv6 next hops need link-local neighbor discovery even though the
        # Japanese links carry no application traffic for the router itself.
        iifname { "${warp.mesh-jp.link}", "${warp.warp-jp.link}" } ip6 hoplimit 255 icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert } accept
        iifname { "${warp.mesh-jp.link}", "${warp.warp-jp.link}" } ct state != { established, related } drop
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        ct state vmap { established : accept, related : accept, invalid : drop }

        # Preserve IPv4-only forwarding outside the Japanese path.
        meta nfproto ipv4 iifname "${lan.interface}" oifname "${wan.interface}" accept

        # The office LAN and Mesh clients form one network, and Mesh clients may
        # use the WAN.
        meta nfproto ipv4 iifname "${lan.interface}" oifname "${warp.mesh.link}" accept
        meta nfproto ipv4 iifname "${warp.mesh.link}" oifname { "${lan.interface}", "${wan.interface}" } accept

        # Japanese Mesh clients exit only through warp-jp, in either IP family.
        iifname "${warp.mesh-jp.link}" oifname "${warp.warp-jp.link}" accept
      }
    '';
  };
}

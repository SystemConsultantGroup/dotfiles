{ config, notnft, ... }:
let
  inherit (config.dotfiles.router) lan wan;
  inherit (config.dotfiles.router.cloudflare) officeDetection;
  inherit (config.dotfiles.router.cloudflare.mesh) hostInterface;
in
{
  dotfiles.nftables.filterTable =
    with notnft.dsl;
    with payload;
    add table.ip {
      input =
        add chain
          {
            type = f: f.filter;
            hook = f: f.input;
            prio = f: f.filter;
            policy = f: f.accept;
          }
          [
            (is.eq ip.daddr (cidr officeDetection.cidr))
            (is.eq ip.protocol (f: f.tcp))
            (is.eq th.dport officeDetection.port)
            (is.eq meta.iifname lan.interface)
            accept
          ]
          [
            (is.eq ip.daddr (cidr officeDetection.cidr))
            (is.eq ip.protocol (f: f.tcp))
            (is.eq th.dport officeDetection.port)
            drop
          ];

      forward =
        add chain
          {
            type = f: f.filter;
            hook = f: f.forward;
            prio = f: f.filter;
            policy = f: f.drop;
          }
          [
            (vmap ct.state {
              established = accept;
              related = accept;
            })
          ]
          [
            (is.eq meta.iifname lan.interface)
            (is.eq meta.oifname wan.interface)
            accept
          ]
          [
            (is.eq meta.iifname hostInterface)
            (is.eq meta.oifname wan.interface)
            accept
          ]
          [
            (is.eq meta.iifname hostInterface)
            (is.eq meta.oifname lan.interface)
            accept
          ];
    };
}

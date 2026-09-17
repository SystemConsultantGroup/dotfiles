{ notnft, ... }:
let
  addressing = import ./addressing.nix;
  inherit (addressing) officeDetection officeLan;
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
            (is.eq meta.iifname officeLan.interface)
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
            (is.eq meta.iifname "enp5s0")
            (is.eq meta.oifname "enp0s25")
            accept
          ]
          [
            (is.eq meta.iifname "mesh0-host")
            (is.eq meta.oifname "enp0s25")
            accept
          ]
          [
            (is.eq meta.iifname "mesh0-host")
            (is.eq meta.oifname "enp5s0")
            accept
          ];
    };
}

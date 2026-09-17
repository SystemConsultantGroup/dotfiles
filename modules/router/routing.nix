{
  lib,
  notnft,
  ...
}:
let
  wanAddresses = [
    "115.145.150.182"
    "115.145.150.193"
    "115.145.150.204"
    "115.145.150.203"
    "115.145.150.202"
    "115.145.150.201"
    "115.145.150.200"
    "115.145.150.199"
    "115.145.150.198"
    "115.145.150.197"
    "115.145.150.196"
    "115.145.150.195"
    "115.145.150.194"
  ];
in
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  dotfiles.nftables.natTable =
    with notnft.dsl;
    with payload;
    add table.ip {
      postrouting =
        add chain
          {
            type = f: f.nat;
            hook = f: f.postrouting;
            prio = f: f.srcnat;
            policy = f: f.accept;
          }
          [
            (is.eq meta.oifname "enp0s25")
            (snat {
              addr.map = {
                key = jhash ip.saddr (builtins.length wanAddresses);
                data = set (
                  lib.imap0 (i: address: [
                    i
                    address
                  ]) wanAddresses
                );
              };
            })
          ];
      prerouting = add chain {
        type = f: f.nat;
        hook = f: f.prerouting;
        prio = f: f.dstnat;
        policy = f: f.accept;
      };
    };
}

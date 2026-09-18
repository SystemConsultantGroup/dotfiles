{
  config,
  lib,
  notnft,
  ...
}:
let
  inherit (config.dotfiles.router) lan wan;
  inherit (config.dotfiles.router.cloudflare.mesh) clientCidr hostInterface;
  wanAddresses = map (
    address: address.address
  ) config.router.interfaces.${wan.interface}.ipv4.addresses;
in
{
  options.dotfiles.nftables = {
    natTable = lib.mkOption {
      type = lib.types.raw;
      description = "Generated nftables NAT table";
    };
    filterTable = lib.mkOption {
      type = lib.types.raw;
      description = "Generated nftables filter table";
    };
  };

  config = {
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
              (is.eq meta.oifname wan.interface)
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
            ]
            [
              (is.eq meta.iifname hostInterface)
              (is.eq meta.oifname lan.interface)
              (is.eq ip.saddr (cidr clientCidr))
              (snat { addr = lan.address; })
            ];
      };

    router.networkNamespaces.default.nftables.jsonRules =
      with notnft.dsl;
      ruleset {
        nat = config.dotfiles.nftables.natTable;
        filter = config.dotfiles.nftables.filterTable;
      };
  };
}

{
  config,
  lib,
  notnft,
  ...
}:
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

  config.router.networkNamespaces.default.nftables.jsonRules =
    with notnft.dsl;
    ruleset {
      nat = config.dotfiles.nftables.natTable;
      filter = config.dotfiles.nftables.filterTable;
    };
}

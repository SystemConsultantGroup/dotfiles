{
  imports = [
    ./options.nix
    ./interfaces.nix
    ./dhcp-dns.nix
    ./firewall.nix
    ./forwarding.nix
    ./nftables.nix
    ./cloudflare
  ];
}

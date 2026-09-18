{
  imports = [
    ./options.nix
    ./dhcp-dns.nix
    ./firewall.nix
    ./forwarding.nix
    ./nftables.nix
    ./cloudflare
  ];

  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    nftables.enable = true;
    firewall.enable = false;
  };

  router.enable = true;
}

{
  imports = [
    ./options.nix
    ./dhcp-dns.nix
    ./firewall.nix
    ./mesh-portal.nix
    ./nftables.nix
    ./cloudflare
  ];

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = false;
  };

  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    nftables.enable = true;
    firewall.enable = false;
  };

  router.enable = true;
}

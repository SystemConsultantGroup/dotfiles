{ pkgs, ... }:
{
  imports = [
    ./options.nix
    ./interfaces.nix
    ./firewall.nix
    ./nat.nix
    ./warp.nix
    ./dhcp-dns.nix
    ./office-detection.nix
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

  # Previously provided by nixos-router.
  environment.systemPackages = [
    pkgs.conntrack-tools
    pkgs.dig.dnsutils
    pkgs.ethtool
    pkgs.tcpdump
  ];
  services.irqbalance.enable = true;
}

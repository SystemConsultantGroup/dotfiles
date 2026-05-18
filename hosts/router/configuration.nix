{ notnft, lib, ... }:

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
  wanPrefixLength = 24;
  wanGateway = "115.145.150.1";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/server
    ../../modules/client
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.hostName = "router";
  networking.networkmanager.enable = false;

  time.timeZone = "Asia/Seoul";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.printing.enable = true;

  router.enable = true;

  router.interfaces.enp0s25 = {
    ipv4.addresses = map (address: { inherit address; prefixLength = wanPrefixLength; }) wanAddresses;
    ipv4.routes = [
      { extraArgs = [ "default" "via" wanGateway ]; }
    ];
  };

  router.interfaces.enp5s0 = {
    ipv4.addresses = [{
      address = "10.0.0.1";
      prefixLength = 8;
      dns = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4" ];
      gateways = [ "10.0.0.1" ];
    }];
    ipv4.kea.enable = true;
  };

  router.networkNamespaces.default.nftables.jsonRules =
    with notnft.dsl; with payload; ruleset {
      nat = add table.ip {
        postrouting = add chain { type = f: f.nat; hook = f: f.postrouting; prio = f: f.srcnat; policy = f: f.accept; }
          [(is.eq meta.oifname "enp0s25") (snat {
            addr = {
              map = {
                key = jhash ip.saddr (builtins.length wanAddresses);
                data = set (lib.imap0 (i: addr: [ i addr ]) wanAddresses);
              };
            };
          })];
        prerouting = add chain { type = f: f.nat; hook = f: f.prerouting; prio = f: f.dstnat; policy = f: f.accept; };
      };
      filter = add table.ip {
        forward = add chain { type = f: f.filter; hook = f: f.forward; prio = f: f.filter; policy = f: f.drop; }
          [(vmap ct.state { established = accept; related = accept; })]
          [(is.eq meta.iifname "enp5s0") (is.eq meta.oifname "enp0s25") accept]
          [(is.eq meta.iifname "enp0s25") (is.eq meta.oifname "enp5s0") (vmap ct.state { established = accept; related = accept; })];
      };
    };

  system.stateVersion = "25.11";
}

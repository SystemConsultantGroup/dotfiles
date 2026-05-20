{
  config,
  pkgs,
  notnft,
  lib,
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

  boot.kernelPackages = pkgs.linuxPackages_latest;
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

  # NVIDIA GTX 970 (Maxwell) — 580 is the last legacy branch supporting this GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  systemd.services.ethtool-enp0s25 = {
    description = "Disable TSO on enp0s25";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    script = ''
      ${pkgs.ethtool}/bin/ethtool -K enp0s25 tso off
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # ARP cache warming: fping sweep of all DHCP-leased IPs every second.
  # Resolves a client logic bug where ARP entries go stale after router reboot.
  systemd.services.fping-lease-sweep = {
    description = "fping sweep of DHCP leased IPs to warm ARP cache";
    after = [ "kea-dhcp4-server-enp5s0.service" ];
    requires = [ "kea-dhcp4-server-enp5s0.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fping-lease-sweep" ''
        leasefile="/var/lib/private/kea/dhcp4-enp5s0.leases"
        if [ -s "$leasefile" ]; then
          ${pkgs.gawk}/bin/awk -F, '!/^#/ && NF > 1 {print $1}' "$leasefile" \
            | ${pkgs.findutils}/bin/xargs -r \
                ${pkgs.fping}/bin/fping -c 1 -t 500 -q 2>/dev/null || true
        fi
      '';
      AmbientCapabilities = [ "CAP_NET_RAW" ];
      StartLimitIntervalSec = 0;
    };
  };

  systemd.timers.fping-lease-sweep = {
    description = "Run fping sweep of DHCP leased IPs every 1s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnUnitActiveSec = "1s";
      AccuracySec = "500ms";
    };
  };

  router.enable = true;

  router.interfaces.enp0s25 = {
    ipv4.addresses = map (address: {
      inherit address;
      prefixLength = wanPrefixLength;
    }) wanAddresses;
    ipv4.routes = [
      {
        extraArgs = [
          "default"
          "via"
          wanGateway
        ];
      }
    ];
  };

  router.interfaces.enp5s0 = {
    ipv4.addresses = [
      {
        address = "10.0.0.1";
        prefixLength = 8;
        dns = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
        gateways = [ "10.0.0.1" ];
      }
    ];
    ipv4.kea.enable = true;
  };

  router.networkNamespaces.default.nftables.jsonRules =
    with notnft.dsl;
    with payload;
    ruleset {
      nat = add table.ip {
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
                addr = {
                  map = {
                    key = jhash ip.saddr (builtins.length wanAddresses);
                    data = set (
                      lib.imap0 (i: addr: [
                        i
                        addr
                      ]) wanAddresses
                    );
                  };
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
      filter = add table.ip {
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
            [ (is.eq meta.iifname "enp5s0") (is.eq meta.oifname "enp0s25") accept ]
            [
              (is.eq meta.iifname "enp0s25")
              (is.eq meta.oifname "enp5s0")
              (vmap ct.state {
                established = accept;
                related = accept;
              })
            ];
      };
    };

  system.stateVersion = "25.11";
}

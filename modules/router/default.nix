{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.router;
  fe = pkgs.callPackage ./fe { };
  be = cfg.be.package;
  state = "/var/lib/router-be";
  socket = "/run/router-be/controller.sock";
  cert = "/var/lib/acme/${cfg.be.hostname}";
  settings = pkgs.writeText "router-be.json" (
    builtins.toJSON {
      inherit (cfg.be) hostname;
      address = cfg.lan.address;
      domain = cfg.lan.domain;
      state_dir = state;
      inherit socket;
      lease_file = "/var/lib/dnsmasq/dnsmasq.leases";
      ip = lib.getExe' pkgs.iproute2 "ip";
      nft = lib.getExe pkgs.nftables;
      reserved_names = [
        "localhost"
        "router"
        "gateway"
        "dns"
        "wpad"
        "isatap"
      ];
      internal_networks = [
        cfg.lan.cidr
        cfg.meshCidr
        cfg.officeDetection.cidr
      ];
      inherit (cfg) ingresses upstreams;
    }
  );
  hardening = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    UMask = "0077";
    Restart = "on-failure";
    RestartSec = 3;
  };
  # PID 1 reads the existing private source before service sandboxing. Only
  # protected, non-persistent credential memory is made available to each unit.
  cloudflareCredential = {
    LoadCredential = [ "cloudflare-env:${cfg.be.environmentFile}" ];
    LimitCORE = 0;
    # A comment-only, non-secret fallback keeps local policy available if the
    # source is missing. Unit-file syntax does not accept an empty value.
    SetCredential = [ "cloudflare-env:#unavailable" ];
  };
  loadCloudflare = ''
    set +x
    set -euo pipefail
    if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/cloudflare-env" ]; then
      set -a
      if ! . "$CREDENTIALS_DIRECTORY/cloudflare-env" >/dev/null 2>&1; then
        echo "Unable to load Cloudflare credential source" >&2
        exit 1
      fi
      set +x
      set +a
    fi
    export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
  '';
  withCloudflare = pkgs.writeShellScript "router-cloudflare-env" (
    loadCloudflare
    + ''
      exec "$@"
    ''
  );
  # lego uses a provider-specific variable; its alias exists only in memory.
  acmeLego = pkgs.writeShellScriptBin "lego" (
    loadCloudflare
    + ''
      export CLOUDFLARE_DNS_API_TOKEN="''${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
      exec ${lib.getExe pkgs.lego} "$@"
    ''
  );
in
{
  imports = [
    ./options.nix
    ./interfaces.nix
    ./firewall.nix
    ./nat.nix
    ./routing.nix
    ./warp.nix
    ./dhcp-dns.nix
    ./office-detection.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    # IPv6 link-local operation remains available to Waywarp internally, but
    # downstream IPv6 is not a supported forwarding service.
    "net.ipv6.conf.all.forwarding" = false;
    "net.ipv6.conf.default.forwarding" = false;
    # Mesh replies may legitimately use a different interface from the main
    # table's preferred route. Use loose reverse-path validation.
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
  };

  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    nftables = {
      enable = true;
      flushRuleset = false;
    };
    firewall.enable = false;
  };

  users.groups = {
    router-be = { };
    router-tls = { };
  };
  users.users = {
    router-be = {
      isSystemUser = true;
      group = "router-be";
      extraGroups = [ "router-tls" ];
    };
    router-controller = {
      isSystemUser = true;
      group = "router-be";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${state} 0755 router-controller router-be -"
    "d ${state}/dns 0755 router-controller router-be -"
    "f ${state}/dns/hosts 0644 router-controller router-be -"
    "d ${state}/leases 0755 root root -"
  ];

  security.acme = {
    acceptTerms = true;
    certs.${cfg.be.hostname} = {
      dnsProvider = "cloudflare";
      # Local DNS serves this hostname privately; propagation checks must use
      # the public DNS view rather than its locally authoritative subtree.
      dnsResolver = "1.1.1.1:53";
      group = "router-tls";
      # Start the HTTPS service after the first real issuance as well as
      # restarting it on renewal. Never serve the preliminary self-signed cert.
      postRun = "${lib.getExe' pkgs.systemd "systemctl"} --no-block restart router-be.service";
    };
  };

  systemd.services = {
    "acme-order-renew-${cfg.be.hostname}" = {
      path = lib.mkBefore [ acmeLego ];
      unitConfig.ConditionPathExists = cfg.be.environmentFile;
      serviceConfig = cloudflareCredential;
    };
    router-be-controller = {
      description = "Router be device-policy reconciler";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "router-policy-routing.service"
        "systemd-tmpfiles-setup.service"
      ];
      requires = [ "router-policy-routing.service" ];
      serviceConfig =
        hardening
        // cloudflareCredential
        // {
          User = "router-controller";
          Group = "router-be";
          ExecStart = "${withCloudflare} ${lib.getExe be} controller --config ${settings}";
          StateDirectory = "router-be";
          StateDirectoryMode = "0755";
          RuntimeDirectory = "router-be";
          RuntimeDirectoryMode = "0750";
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
        };
    };
    router-be = {
      description = "Router be HTTPS API and fe assets";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "router-be-controller.service"
        "acme-${cfg.be.hostname}.service"
      ];
      # Keep HTTPS available across controller restarts; each API request
      # reconnects to the socket and reports a temporary 503 while it is down.
      wants = [
        "router-be-controller.service"
        "acme-${cfg.be.hostname}.service"
      ];
      unitConfig.ConditionPathExists = [
        "${cert}/acme-success"
        "${cert}/fullchain.pem"
        "${cert}/key.pem"
      ];
      serviceConfig = hardening // {
        User = "router-be";
        Group = "router-be";
        ExecStart = "${lib.getExe be} web --config ${settings} --assets ${fe} --cert ${cert}/fullchain.pem --key ${cert}/key.pem";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
        ];
        IPAddressDeny = "any";
        IPAddressAllow = lib.unique (map (ingress: ingress.network) (lib.attrValues cfg.ingresses));
      };
    };
  };

  # Previously provided by nixos-router.
  environment.systemPackages = [
    pkgs.conntrack-tools
    pkgs.bind.dnsutils
    pkgs.ethtool
    pkgs.tcpdump
  ];
  services.irqbalance.enable = true;
}

{ lib, pkgs, ... }:
let
  instance = "scg-skku-router";
  namespace = "mesh-${instance}";
  hostInterface = "mesh0-host";
  meshInterface = "mesh0-peer";
  serviceName = "mesh-${instance}";
  stateDirectory = "mesh-${instance}";
  statePath = "/var/lib/${stateDirectory}";
  runtimeDirectory = "mesh-${instance}";
  tokenPath = "/var/lib/secrets/mesh-${instance}.token";
  warpPackage = pkgs.cloudflare-warp.override { headless = true; };
  capabilities = [
    "CAP_NET_ADMIN"
    "CAP_NET_BIND_SERVICE"
    "CAP_NET_RAW"
    "CAP_SYS_PTRACE"
  ];
in
{
  environment.systemPackages = [ warpPackage ];

  systemd.tmpfiles.rules = [
    "d ${statePath} 0700 root root -"
    "f ${statePath}/resolv.conf 0644 root root - nameserver\\x201.1.1.1\\nnameserver\\x201.0.0.1\\n"
  ];

  router = {
    networkNamespaces.${namespace} = {
      extraStartCommands = "ip link set lo up";
      sysctl."net.ipv4.ip_forward" = true;
      nftables.textRules = ''
        table inet mesh_filter {
          chain forward {
            type filter hook forward priority filter; policy drop;

            ct state { established, related } accept
            oifname "${meshInterface}" ip daddr 10.0.0.0/8 accept
          }
        }
      '';
    };

    veths.${hostInterface}.peerName = meshInterface;

    interfaces = {
      ${hostInterface}.ipv4 = {
        addresses = [
          {
            address = "172.31.255.1";
            prefixLength = 30;
          }
        ];
        routes = [
          {
            extraArgs = [
              "100.96.0.0/12"
              "via"
              "172.31.255.2"
            ];
          }
        ];
      };

      ${meshInterface} = {
        networkNamespace = namespace;
        dependentServices = [
          serviceName
          "${serviceName}-enroll"
        ];
        ipv4 = {
          addresses = [
            {
              address = "172.31.255.2";
              prefixLength = 30;
            }
          ];
          routes = [
            {
              extraArgs = [
                "default"
                "via"
                "172.31.255.1"
              ];
            }
            {
              extraArgs = [
                "10.0.0.0/8"
                "via"
                "172.31.255.1"
              ];
            }
          ];
        };
      };
    };
  };

  systemd.services = {
    # Keep namespace-owned setup units in the same restart transaction as the
    # namespace. This preserves the veth across declarative namespace updates.
    "setup-netns-for-mesh0\\x2dpeer" = {
      after = [ "netns-${namespace}.service" ];
      requires = [ "netns-${namespace}.service" ];
      partOf = [ "netns-${namespace}.service" ];
    };
    "network-addresses-mesh0\\x2dpeer".partOf = [ "netns-${namespace}.service" ];
    "sysctl-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];
    "nftables-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];

    ${serviceName} = {
      description = "Cloudflare Mesh node scg-skku/router";
      wantedBy = [ "multi-user.target" ];
      partOf = [ "netns-${namespace}.service" ];
      after = [
        "network-addresses-mesh0\\x2dhost.service"
        "network-addresses-mesh0\\x2dpeer.service"
        "nftables-netns-${namespace}.service"
        "sysctl-netns-${namespace}.service"
      ];
      requires = [
        "network-addresses-mesh0\\x2dhost.service"
        "network-addresses-mesh0\\x2dpeer.service"
        "nftables-netns-${namespace}.service"
        "sysctl-netns-${namespace}.service"
      ];
      path = [ pkgs.lsof ];
      environment.RUST_BACKTRACE = "full";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${warpPackage}/bin/warp-svc";
        Restart = "always";
        RestartSec = 5;

        User = "root";
        Group = "root";
        WorkingDirectory = statePath;
        StateDirectory = stateDirectory;
        StateDirectoryMode = "0700";
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = "0750";
        RuntimeDirectoryPreserve = "yes";
        LogsDirectory = stateDirectory;

        BindPaths = [ "${statePath}/resolv.conf:/etc/resolv.conf" ];
        BindReadOnlyPaths = [ "${lib.getExe pkgs.nftables}:/usr/sbin/nft" ];
        ReadWritePaths = [ statePath ];

        AmbientCapabilities = capabilities;
        CapabilityBoundingSet = capabilities;
        DevicePolicy = "closed";
        DeviceAllow = [ "/dev/net/tun rw" ];
        NoNewPrivileges = true;

        PrivatePIDs = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        LockPersonality = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };

    "${serviceName}-enroll" = {
      description = "Enroll and connect Cloudflare Mesh node scg-skku/router";
      wantedBy = [ "multi-user.target" ];
      partOf = [ "netns-${namespace}.service" ];
      after = [ "${serviceName}.service" ];
      requires = [ "${serviceName}.service" ];
      path = [ warpPackage ];
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = "mesh-token:${tokenPath}";
        StateDirectory = stateDirectory;
        StateDirectoryMode = "0700";
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = "0750";
        RuntimeDirectoryPreserve = "yes";
      };
      script = ''
        ready=
        for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
          if warp-cli --accept-tos status >/dev/null 2>&1; then
            ready=1
            break
          fi
          sleep 1
        done

        if [ -z "$ready" ]; then
          echo "warp-svc did not become ready" >&2
          exit 1
        fi

        if [ ! -s "$STATE_DIRECTORY/reg.json" ]; then
          token="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/mesh-token")"
          warp-cli --accept-tos connector new "$token"
          unset token
        fi

        # The synthetic connectivity-check hostname does not resolve reliably
        # inside the isolated network namespace.
        warp-cli --accept-tos debug connectivity-check disable
        warp-cli --accept-tos connect
      '';
    };
  };
}

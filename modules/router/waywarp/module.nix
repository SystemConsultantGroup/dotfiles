{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  settings = config.services.waywarp;
  optionalArgument =
    flag: value:
    lib.optionals (value != null) [
      flag
      (toString value)
    ];
  instanceType = types.submodule {
    options = {
      mode = mkOption {
        type = types.enum [
          "proxy"
          "bridge"
        ];
        description = "How the instance exposes WARP traffic.";
      };
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Label shown by waywarp status.";
      };
      colo = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Required Cloudflare location constraints.";
      };
      via = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Uplinks to try, in order (defaults to direct).";
      };
      interface = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Physical uplink interface.";
      };
      edge = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MASQUE edge IPv4 address.";
      };
      edgePort = mkOption {
        type = types.port;
        default = 443;
        description = "MASQUE edge port.";
      };
      mudfishPort = mkOption {
        type = types.port;
        default = 18081;
        description = "SOCKS5 port of Mudfish nodes.";
      };
      noRebootstrap = mkOption {
        type = types.bool;
        default = false;
        description = "Keep running when the requested location changes.";
      };
      listen = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Proxy listen address (loopback only).";
      };
      subnet4 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Bridge IPv4 /30 subnet.";
      };
      subnet6 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Bridge IPv6 /126 subnet.";
      };
      environmentFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Absolute path to a root-readable systemd EnvironmentFile containing relay credentials. Do not put secrets in the Nix store.";
      };
    };
  };
  arguments =
    index: instance:
    [
      "up"
      index
      "--mode"
      instance.mode
      "--foreground"
    ]
    ++ optionalArgument "--name" instance.name
    ++ optionalArgument "--colo" instance.colo
    ++ lib.concatMap (hop: [
      "--via"
      hop
    ]) instance.via
    ++ optionalArgument "--interface" instance.interface
    ++ optionalArgument "--edge" instance.edge
    ++ lib.optionals (instance.edgePort != 443) [
      "--edge-port"
      (toString instance.edgePort)
    ]
    ++ lib.optionals (instance.mudfishPort != 18081) [
      "--mudfish-port"
      (toString instance.mudfishPort)
    ]
    ++ lib.optional instance.noRebootstrap "--no-rebootstrap"
    ++ optionalArgument "--listen" instance.listen
    ++ optionalArgument "--subnet4" instance.subnet4
    ++ optionalArgument "--subnet6" instance.subnet6;
in
{
  options.services.waywarp = {
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "waywarp.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Waywarp package to run.";
    };
    instances = mkOption {
      type = types.attrsOf instanceType;
      default = { };
      example = {
        "0" = {
          mode = "proxy";
        };
        "2" = {
          mode = "bridge";
          colo = "NRT";
          via = [ "mudfish:city=tokyo" ];
        };
      };
      description = "Root-owned Waywarp instances, keyed by their index (0–255).";
    };
  };

  config = {
    assertions = lib.mapAttrsToList (index: instance: {
      assertion =
        let
          parsed = builtins.tryEval (lib.toInt index);
        in
        builtins.match "(0|[1-9][0-9]*)" index != null
        && parsed.success
        && parsed.value <= 255
        && (instance.mode == "proxy" || instance.listen == null)
        && (instance.mode == "bridge" || (instance.subnet4 == null && instance.subnet6 == null));
      message = "services.waywarp.instances.\"${index}\": index must be 0–255; listen requires proxy mode and subnets require bridge mode.";
    }) settings.instances;

    systemd.services = lib.mapAttrs' (
      index: instance:
      lib.nameValuePair "waywarp-${index}" {
        description = "Waywarp instance ${index}";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${lib.getExe settings.package} ${lib.escapeShellArgs (arguments index instance)}";
          EnvironmentFile = lib.optional (instance.environmentFile != null) instance.environmentFile;
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 30;
        };
      }
    ) settings.instances;
  };
}

{ inputs, ... }:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/desktop
    ../../modules/drivers/arc.nix
    inputs.paseo.nixosModules.default
  ];
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  services.cloudflare-warp.enable = true;

  services.paseo = {
    enable = true;
    # Run as the real user so spawned agents (pi) see ~/.pi, git config, ssh keys.
    # Also switches dataDir to /home/aperso/.paseo (the CLI's default home).
    user = "aperso";
    # relay defaults to the hosted app.paseo.sh endpoint (E2E-encrypted);
    # set relay.enable = false to only accept direct connections
  };

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

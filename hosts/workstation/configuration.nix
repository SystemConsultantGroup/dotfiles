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
    # relay defaults to the hosted app.paseo.sh endpoint (E2E-encrypted);
    # set relay.enable = false to only accept direct connections
  };

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

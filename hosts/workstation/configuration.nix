{ ... }:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/desktop
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

  services = {
    cloudflare-warp.enable = true;

    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };
  };

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

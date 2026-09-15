{ pkgs, ... }:
{
  networking.hostName = "scg-workstation";
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/desktop
    ../../modules/drivers/nvidia.nix
  ];

  # LTS kernel (linuxPackages). nvidia.nix pins stable driver against it.
  boot.kernelPackages = pkgs.linuxPackages;

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

  # Temporary first-boot password for aperso. Change with `passwd` after
  # install, then remove this line and rebuild.
  users.users.aperso.initialPassword = "nixos";

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

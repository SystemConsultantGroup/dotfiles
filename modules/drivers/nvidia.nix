{ config, ... }:
{
  # NVIDIA GB206 (RTX 5060, Blackwell) for scg-workstation.
  # LTS kernel comes from the host config (boot.kernelPackages =
  # pkgs.linuxPackages); here we pin the latest *stable* driver against
  # that kernel. Blackwell requires the open kernel modules.
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
}

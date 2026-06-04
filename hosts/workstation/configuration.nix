{ config, pkgs, ... }:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/client
  ];
  boot = {
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  # NVIDIA GPU — compute-only (display on iGPU).
  # Provides CUDA driver runtime (libcuda.so, nvidia-uvm, etc.)
  # without requiring the full CUDA development toolkit.
  hardware.nvidia = {
    modesetting.enable = false;
    powerManagement.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.cloudflare-warp.enable = true;
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

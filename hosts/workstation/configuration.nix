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
    # nvidia in videoDrivers below makes modules available; CUDA triggers autoload.
    blacklistedKernelModules = [ "nouveau" ];
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  # NVIDIA GeForce RTX 5060 — compute-only (display on iGPU).
  # Provides CUDA driver runtime (libcuda.so, nvidia-uvm, etc.)
  # without requiring the full CUDA development toolkit.
  hardware.nvidia = {
    modesetting.enable = false;
    powerManagement.enable = true;
    open = true; # Blackwell GPU — use open kernel module
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.cloudflare-warp.enable = true;
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}

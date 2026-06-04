{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.nvidia;
in
{
  options.hardware.nvidia = {
    cuda = {
      enable = lib.mkEnableOption "CUDA toolkit and libraries";
    };
  };

  config = {
    hardware = {
      graphics = {
        enable32Bit = true;
      };
      nvidia = {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        powerManagement.enable = false;
      };
    };

    services.xserver.videoDrivers = [ "nvidia" ];

    boot.kernelModules = [
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
    ];

    environment.systemPackages = [
      pkgs.nvidia-vaapi-driver
    ]
    ++ lib.optionals cfg.cuda.enable [
      pkgs.cudaPackages.cuda_nvcc
      pkgs.cudaPackages.cuda_cudart
      pkgs.cudaPackages.libcublas
      pkgs.cudaPackages.libcufft
      pkgs.cudaPackages.libcurand
      pkgs.cudaPackages.libcusolver
      pkgs.cudaPackages.libcusparse
      pkgs.cudaPackages.cuda_cccl
    ];

    environment.sessionVariables = lib.optionalAttrs cfg.cuda.enable {
      CUDA_PATH = "${pkgs.cudaPackages.cuda_nvcc}";
      EXTRA_LDFLAGS = "-L${pkgs.cudaPackages.cuda_cudart}/lib";
      EXTRA_CCFLAGS = "-I${pkgs.cudaPackages.cuda_cudart}/include";
    };
  };
}

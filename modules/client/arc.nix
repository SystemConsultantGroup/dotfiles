{ pkgs, ... }:
{
  boot.kernelParams = [ "i915.enable_guc=3" ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-compute-runtime.drivers
      intel-graphics-compiler
      level-zero
    ];
  };

  programs.nix-ld.libraries = with pkgs; [
    intel-compute-runtime
    intel-compute-runtime.drivers
    intel-graphics-compiler
    level-zero
    ocl-icd
  ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    ocl-icd
    clinfo
  ];
}

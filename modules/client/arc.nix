{ pkgs, ... }:
{
  boot.kernelParams = [ "i915.enable_guc=3" ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
    ];
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      intel-compute-runtime
      intel-ocl
    ];
  };

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}

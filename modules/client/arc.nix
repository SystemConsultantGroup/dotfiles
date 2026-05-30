{ pkgs, ... }:
{
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

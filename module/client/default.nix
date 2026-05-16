{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../user/aperso.nix
    ./font.nix
    ./hypr.nix
  ];
  services.gnome.gnome-keyring.enable = true;
  services.xserver.xkb.layout = "us";
  environment.systemPackages = [
    pkgs.vesktop
    pkgs.firefox
    pkgs.zed-editor
    pkgs.vscode-fhs
    pkgs.nixd
    pkgs.nil
  ];
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp";
}

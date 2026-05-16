{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../user/aperso.nix
    ./font.nix
    ./hypr.nix
  ];
  i18n = {
    defaultLocale = "en_US.UTF-8";
    inputMethod = {
      enable = true;
      type = "kime";
      package = lib.mkForce inputs.kime.packages.${pkgs.system}.default;
    };
  };
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

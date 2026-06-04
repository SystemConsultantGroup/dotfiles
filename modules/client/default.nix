{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix
    ./home.nix
    ./font.nix
    ./hypr.nix
    ../theme
  ];
  hardware.graphics.enable = true;
  i18n = {
    defaultLocale = "en_US.UTF-8";
    inputMethod = {
      enable = true;
      type = "kime";
      package = lib.mkForce inputs.kime.packages.${pkgs.system}.default;
    };
  };
  environment.systemPackages = [
    pkgs.vesktop
    pkgs.firefox
    pkgs.brave
    pkgs.zed-editor
    pkgs.vscode-fhs
    pkgs.nixd
    pkgs.nil
  ];
  services = {
    gnome.gnome-keyring.enable = true;
    xserver.xkb = {
      layout = "us";
      options = "terminate:ctrl_alt_bksp";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}

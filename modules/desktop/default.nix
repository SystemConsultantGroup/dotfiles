{
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
{
  imports = [
    ./alacritty.nix
    ./font.nix
    ./noctalia.nix
    ./sway.nix
  ];

  i18n.inputMethod = {
    enable = true;
    type = "kime";
    package = lib.mkForce inputs.kime.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    gnome.gnome-keyring.enable = true;

    gvfs.enable = true;
  };

  xdg.portal.wlr.enable = true;

  environment.systemPackages = [
    pkgs.alacritty.terminfo
    pkgs.bibata-cursors
    pkgs.brightnessctl
    pkgs.libva-utils
  ];

  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "text/xml" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };

  users.users.${username}.packages = [
    pkgs.alacritty
    pkgs.firefox
    pkgs.zed-editor
    pkgs.vscode-fhs
    pkgs.vesktop
    pkgs.nautilus
    pkgs.pwvucontrol
    pkgs.nixd
    pkgs.nil
    pkgs.flameshot
    inputs.persway.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./home
    ./font.nix
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "kime";
    package = lib.mkForce inputs.kime.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  # GTK_IM_MODULE=kime forces kime's GTK IM module on all GTK apps, but Firefox
  # on Wayland uses its own text-input-v3 via libmozwayland.so (not GTK IM
  # modules). Setting GTK_IM_MODULE globally conflicts with Firefox's native
  # Wayland text-input, breaking Korean input in Firefox.
  # QT_IM_MODULE and XMODIFIERS stay set for Qt / XWayland apps.
  environment.variables.GTK_IM_MODULE = lib.mkForce null;

  environment.systemPackages = [
    pkgs.bibata-cursors
    pkgs.brightnessctl
    pkgs.libva-utils
  ];

  services = {
    xserver.xkb = {
      layout = "us";
      options = "terminate:ctrl_alt_bksp";
    };

    gnome.gnome-keyring.enable = true;

    gvfs.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --cmd 'uwsm start hyprland-uwsm.desktop'";
    };
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # xdg-desktop-portal-hyprland advertises the Screenshot interface in its
  # .portal file but doesn't actually implement it (a known bug). Flameshot
  # 14 (and other modern Wayland screenshot tools) needs the Screenshot
  # portal, so we also install xdg-desktop-portal-wlr and force the portal
  # dispatcher to use it for that specific interface. The hyprland portal
  # still wins for ScreenCast / GlobalShortcuts, which it does implement.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  xdg.portal.config.hyprland."org.freedesktop.impl.portal.Screenshot" = "wlr";
}

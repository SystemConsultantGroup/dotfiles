{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  users.users.aperso = {
    isNormalUser = true;
    description = "Donghyun Shin";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    gh
    nh
    claude-code
  ];

  environment.variables.NH_OS_FLAKE = "/home/aperso/dotfiles";
}

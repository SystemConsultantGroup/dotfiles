{ pkgs, ... }:

{
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
    claude-code
  ];
}

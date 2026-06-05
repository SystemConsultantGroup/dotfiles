{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./git.nix
    ./bash.nix
  ];

  home-manager.users.${username}.home = {
    stateVersion = "25.11";
    sessionVariables.NH_OS_FLAKE = "${config.users.users.${username}.home}/dotfiles";
    packages = [
      pkgs.bat
      pkgs.bun
      pkgs.fd
      pkgs.fzf
      pkgs.gh
      pkgs.devenv
      pkgs.jq
      pkgs.mtr
      pkgs.nodejs
      pkgs.opencode
      pkgs.ripgrep
      pkgs.unzip
      pkgs.uv
      pkgs.nh
      pkgs.yazi
      pkgs.zip
    ];
  };
}

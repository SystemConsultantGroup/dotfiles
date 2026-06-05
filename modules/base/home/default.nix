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

  home-manager.users.${username} = {
    home.sessionVariables.NH_OS_FLAKE = "${config.users.users.${username}.home}/dotfiles";
    home.packages = [
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

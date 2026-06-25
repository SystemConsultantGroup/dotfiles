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
    ./ssh.nix
  ];

  home-manager.users.${username}.home = {
    stateVersion = "25.11";
    sessionVariables.NH_OS_FLAKE = "${config.users.users.${username}.home}/dotfiles";
    activation.linkPiAgent = ''
      AGENT_DIR="$HOME/.pi/agent"
      DOTFILES_DIR="$HOME/dotfiles/dynamic/pi-agent"
      if [ -L "$AGENT_DIR" ]; then
        CURRENT_TARGET=$(readlink "$AGENT_DIR")
        if [ "$CURRENT_TARGET" != "$DOTFILES_DIR" ]; then
          echo "pi-agent symlink points elsewhere ($CURRENT_TARGET), leaving alone"
        fi
      elif [ -d "$AGENT_DIR" ]; then
        if [ -n "$(ls -A "$AGENT_DIR" 2>/dev/null)" ]; then
          echo "Migrating existing ~/.pi/agent/ to dotfiles dynamic/pi-agent/"
          cp -rn "$AGENT_DIR"/. "$DOTFILES_DIR"/
          rm -rf "$AGENT_DIR"
        else
          rmdir "$AGENT_DIR"
        fi
        ln -s "$DOTFILES_DIR" "$AGENT_DIR"
        echo "Symlinked ~/.pi/agent -> dotfiles/dynamic/pi-agent"
      elif [ ! -e "$AGENT_DIR" ]; then
        mkdir -p "$DOTFILES_DIR"
        ln -s "$DOTFILES_DIR" "$AGENT_DIR"
        echo "Symlinked ~/.pi/agent -> dotfiles/dynamic/pi-agent"
      fi
    '';
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
      pkgs.ripgrep
      pkgs.unzip
      pkgs.uv
      pkgs.nh
      pkgs.zip
    ];
  };
}

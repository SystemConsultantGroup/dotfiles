{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./bash.nix
    ./git.nix
    ./ssh.nix
  ];

  home-manager.users.${username}.home = {
    stateVersion = "25.11";
    sessionVariables.NH_OS_FLAKE = "${config.users.users.${username}.home}/dotfiles";
    activation.managePiAgentConfig = ''
      AGENT_DIR="$HOME/.pi/agent"
      SRC_DIR="$HOME/dotfiles/dynamic/pi-agent"
      mkdir -p "$AGENT_DIR"
      for file in settings.json AGENTS.md keybindings.json SYSTEM.md APPEND_SYSTEM.md models.json; do
        TARGET="$AGENT_DIR/$file"
        SOURCE="$SRC_DIR/$file"
        if [ ! -f "$SOURCE" ]; then
          continue
        fi
        if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
          continue
        fi
        rm -f "$TARGET"
        ln -s "$SOURCE" "$TARGET"
      done
    '';
    packages = [
      pkgs.nh
      pkgs.gh
      pkgs.nix-search-cli
      pkgs.zip
      pkgs.unzip
      pkgs.ripgrep
      pkgs.jq
      pkgs.bat
      pkgs.fd
      pkgs.fzf
      pkgs.killall
      pkgs.uv
      pkgs.nodejs
      pkgs.pnpm
      pkgs.devenv
      pkgs.mtr
      pkgs.hping
    ];
  };
}

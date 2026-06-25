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

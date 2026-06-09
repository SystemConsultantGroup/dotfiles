{ username, ... }:
{
  home-manager.users.${username}.programs.ssh = {
    enable = true;
    # Always send xterm-256color as TERM when SSHing.
    # This avoids "missing or unsuitable terminal: alacritty" errors on
    # servers that lack the alacritty terminfo entry.
    matchBlocks = {
      "*".setEnv.TERM = "xterm-256color";
    };
  };
}

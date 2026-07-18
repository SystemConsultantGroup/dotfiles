{ username, ... }:
{
  home-manager.users.${username}.programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";

      # Always send xterm-256color as TERM when SSHing.
      # This avoids "missing or unsuitable terminal: alacritty" errors on
      # servers that lack the alacritty terminfo entry.
      SetEnv.TERM = "xterm-256color";
    };
  };
}

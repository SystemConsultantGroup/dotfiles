{ username, ... }:
{
  fileSystems."/home/${username}/.pi" = {
    overlay = {
      lowerdir = [ "/home/${username}/dotfiles/.pi" ];
      upperdir = "/home/${username}/.local/state/overlays/pi/upper";
      workdir = "/home/${username}/.local/state/overlays/pi/work";
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/${username}/.pi 0755 ${username} users -"
  ];

  programs.bash.interactiveShellInit = ''
    alias pi="pnpx --allow-build=@google/genai --allow-build=protobufjs @earendil-works/pi-coding-agent@latest"
  '';
}

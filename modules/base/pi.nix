{ pkgs, username, ... }:
let
  # Real `pi` binary on the system PATH so non-interactive consumers that
  # don't see bash aliases (e.g. the paseo daemon, which runs as its own
  # system user) can spawn pi. Interactive shells still hit the alias below
  # first; both run the identical pnpx invocation.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.pnpm ];
    text = ''
      exec pnpx --allow-build=@google/genai --allow-build=protobufjs @earendil-works/pi-coding-agent@latest "$@"
    '';
  };
in
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

  environment.systemPackages = [ pi ];

  programs.bash.interactiveShellInit = ''
    alias pi="pnpx --allow-build=@google/genai --allow-build=protobufjs @earendil-works/pi-coding-agent@latest"
  '';
}

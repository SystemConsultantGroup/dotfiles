{ pkgs, username, ... }:
let
  # Real `pi` binary on the system PATH so non-interactive consumers can
  # spawn pi. Fullscreen TUI mode is appended only when the first argument
  # is not a flag, so explicit invocations like --help, -p, or --tui-mode
  # regular keep pi in regular mode.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.pnpm ];
    text = ''
      if [[ $# -eq 0 || $1 != -* ]]; then
        set -- --tui-mode fullscreen "$@"
      fi
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
}

# PLAN: dotfiles rewrite

Transient execution plan. Delete this file after successful execution.

## Goal

Strip the repo to a minimal, single-host NixOS config:

- No upstream/downstream/fork machinery (delete all dev/merge skills, rewrite AGENTS.md)
- No home-manager (everything NixOS-native, one build, one rollback)
- Hyprland → Sway
- Noctalia v4 (`noctalia-shell` 4.7.7, JSON settings) → Noctalia v5 (`pkgs.noctalia`, TOML, GUI overrides in state dir)
- Delete `dynamic/` entirely — zero repo files symlinked for hot-reload
- Drop the laptop host (recoverable from git history / GitHub later)
- Reduce system packages and services to a minimum

## Target structure

```
.
├── AGENTS.md                     rewritten: no fork machinery, simple conventions
├── .pi/
│   ├── agent/
│   │   └── SYSTEM.md             system-wide overlay, symlinked from ~/.pi/agent/SYSTEM.md
│   └── skills/                   only non-fork skills (delete the 6 dev/merge dirs)
├── flake.nix                     inputs: nixpkgs + kime only; mkHost kept; workstation only
├── hosts/
│   └── workstation/
│       ├── configuration.nix
│       └── hardware-configuration.nix    (copied as-is)
├── files/
│   └── wallpapers/               moved from dynamic/wallpapers
└── modules/
    ├── base/                     nix/gc/sudo/net/users + bash/git/ssh/direnv + user packages
    ├── desktop/                  sway, noctalia v5, greetd, portals, fonts, kime, pipewire, GUI apps
    └── drivers/
        ├── arc.nix               ACTIVE on workstation (main monitor is on Arc)
        └── radeon.nix            module only, not imported (future / AMD side)
```

## Delegation model (main agent orchestrates, does not do the work)

Builtin agents available: `researcher` (web), `scout` (local recon), `planner`, `worker` (implementation), `reviewer`, `oracle`/`advisor`, `context-builder`, `delegate`. Main agent reads the `pi-subagents` skill and routes work; children must not spawn their own subagents (except assigned fanout children).

Per change (each module, config file, or research question):

1. Research fanout (fresh context, distinct angles): `researcher` → web evidence (official docs first: docs.noctalia.dev/v5, sway man, search.nixos.org); `scout` → system-side (options in the actual pinned nixpkgs rev via store grep / `nix eval`, live system state: `lspci`, `/sys/class/backlight/`, `man sway`, current `~/.config`).
2. Plan (only for large changes): `planner` turns the research into an implementation brief (files, options, validation, risks).
3. Implement: ONE `worker` (sole writer for the repo) receives the research/plan brief, writes the module/config, runs its own focused validation.
4. Review: fresh-context `reviewer` fanout, read-only, distinct angles (correctness against nixpkgs options, wayland/sway correctness, simplicity). Reviewers do not edit; they return evidence-backed findings with file/line refs.
5. Parent: synthesize accepted fixes (apply via a fix `worker` if non-trivial), run the mechanical gates (`statix check . && deadnix . && nix fmt`, `nh os build .`), commit, push.

The parent stays the final decision-maker: it approves scope, accepts/rejects review findings, and runs the build gates. It does not write module code or reason through config details itself.

Phase mapping: Phase 2 research = the queued items below via researcher/scout fanout; module writes = worker; pre-commit validation = reviewer fanout + parent gates.

## Research discipline (every change)

Before writing any module or config, verify it on both sides:

1. System-side: confirm the option/package exists in the ACTUAL nixpkgs being used. The pinned rev is in `flake.lock`; grep the store source (`nix flake archive github:nixos/nixpkgs/<rev>` → `/nix/store/...-source/nixos/modules/...`) or `nix eval github:nixos/nixpkgs/<rev>#<attr>`. Also inspect the live system (`ls /sys/class/backlight/`, `lspci`, `man sway`, current `~/.config` state) rather than assuming.
2. Web-side: prefer official docs over blogs — docs.noctalia.dev/v5, sway(1) man page / sway wiki, search.nixos.org options, the tool's own GitHub. Never oneshot URLs: search first, then fetch. The local Hyprland wiki skill does NOT apply — we are on Sway now.
3. Record the finding (what was verified + where) in the commit message or a short note so the verification is auditable.

Specific research items queued before Phase 2 writes:

- `programs.noctalia` options in the UPDATED nixpkgs rev (does it gain `settings`/`configFile`? confirm `systemd.target` default and sway's `graphical-session.target` startup; battery needs upower)
- Noctalia v5 IPC command names for sway keybinds (`noctalia msg ...`) from docs.noctalia.dev/v5/ipc — verify each keybind command before committing
- `programs.sway` options: extraConfig, extraSessionCommands, wrapperFeatures.gtk, extraPackages
- sway keybind/input syntax (man sway / sway wiki) — including the `korean:ralt_hangul,korean:rctrl_hanja` xkb options under sway
- kime under sway (text-input-v3 support, known issues)
- Intel Arc on the current kernel: xe vs i915 driver, whether any extra kernel modules/firmware are needed, backlight device name for brightnessctl
- xdg-desktop-portal-wlr wiring for sway (portal config + Screenshot interface)
- greetd → `sway` session command form
- confirm updated nixpkgs still lacks `programs.alacritty` (decision is package-only anyway, but verify)

## Facts to remember

- Delegation: the main agent does NOT implement — research goes to `researcher`/`scout`, implementation to a single `worker`, review to fresh-context `reviewer`s. The parent only orchestrates, gates, and commits (see Delegation model).

- `~/.pi/agent/{AGENTS.md, settings.json}` are symlinks into `dynamic/pi-agent/` — realize before wiping.
- `~/.config/noctalia/{settings.json, user-templates.toml}` are symlinks into `dynamic/noctalia/` (v4 artifacts) — delete.
- Pending uncommitted changes exist: `dynamic/pi-agent/{AGENTS.md,settings.json}`, `modules/base/home/bash.nix`, untracked `.vscode/`. Preserve via snapshot commit + backup.
- Pinned nixpkgs (rev 47f3deb4) LACKS `pkgs.noctalia` (v5) and NixOS `programs.alacritty`. `nix flake update nixpkgs` is a hard prerequisite.
- Workstation is AMD CPU (`kvm-amd`) + Intel Arc GPU on the main monitor. Current `videoDrivers = ["amdgpu"]` is wrong/stale; `intel-media-driver` in client module is the Arc VA-API driver — move it into drivers/arc.nix.
- Noctalia v5 config model: `~/.config/noctalia/*.toml` = declarative base (GUI never writes here), `~/.local/state/noctalia/settings.toml` = GUI overrides (untracked state, safe to delete to reset). `noctalia config validate` shows merged result.
- Noctalia v5 IPC is `noctalia msg ...` (not v4's `noctalia-shell ipc call ...`). Verify exact commands on docs.noctalia.dev/v5/ipc when porting keybinds.
- Sway starts `graphical-session.target`, so the noctalia systemd service default target works. Fallback if it doesn't autostart: `exec noctalia --daemon` in sway config.
- Keep `.git` during the wipe (full history + rollback). Backup to /tmp anyway.

## Locked decisions

- Keep `.git`; wipe only tracked files. `.direnv/`, `.pi/npm/`, `.pi/git/`, `.vscode/` (untracked/ignored) survive untouched.
- Noctalia base config: `pkgs.writeText` config.toml + one `systemd.tmpfiles` `L+` symlink into `~/.config/noctalia/`. GUI overrides live in state dir (untracked).
- Alacritty: package only, no config file (current config was 3 lines of padding; Noctalia builtin alacritty template colors it).
- kime: unchanged (`i18n.inputMethod`, package from `inputs.kime`). Korean xkb options move into sway input config: `korean:ralt_hangul,korean:rctrl_hanja`.
- pipewire: drop `jack.enable`. No podman, no openssh server.
- Wallpapers: `files/wallpapers/` (assets, not a mechanism). Noctalia base config points wallpaper dir at `~/dotfiles/files/wallpapers`.
- pi config: `~/.pi/agent/{AGENTS.md, settings.json}` become real untracked files (stop versioning settings.json). `.pi/agent/SYSTEM.md` is the one tracked, symlinked system-wide overlay, seeded from current SYSTEM_ENV content (current `dynamic/pi-agent/AGENTS.md`).
- cloudflare-warp stays on workstation (it's why `firewall.enable = false`).
- Keep `mkHost` in flake.nix so the laptop host is trivial to re-add from git history.

## Phase 0 — Preserve

```bash
cd ~/dotfiles
git add -A
git commit -m "chore: snapshot pre-rewrite state (PLAN.md, pending edits)"
cp -a ~/dotfiles /tmp/dotfiles-rewrite-backup-$(date +%Y%m%d-%H%M%S)
```

## Phase 1 — Realize runtime symlinks (before their targets are wiped)

```bash
# pi agent: turn repo symlinks into real files (untracked personal state)
rm ~/.pi/agent/AGENTS.md ~/.pi/agent/settings.json
cp dynamic/pi-agent/AGENTS.md ~/.pi/agent/AGENTS.md
cp dynamic/pi-agent/settings.json ~/.pi/agent/settings.json

# v4 noctalia artifacts — delete symlinks (v5 uses config.toml + state dir)
rm ~/.config/noctalia/settings.json ~/.config/noctalia/user-templates.toml
```

## Phase 2 — Wipe + scaffold

Research first: complete the queued items above (system-side greps against the nixpkgs rev that results from the `nix flake update` step below; web-side docs for noctalia IPC and sway syntax). Do not write a module until its options are verified to exist.

```bash
# delete the 6 fork skills
rm -rf .pi/skills/{dev-upstream,dev-downstream,merge-into-upstream,merge-into-downstream,merge-from-upstream,merge-from-downstream}

# wipe tracked tree (keeps .git, .direnv, .pi/npm, .pi/git, .vscode)
git ls-files | xargs rm
git add -A

# move wallpapers before wiping dynamic/
mkdir -p files/wallpapers
mv dynamic/wallpapers/* files/wallpapers/
```

Create the new files:

- `flake.nix` — inputs nixpkgs (nixos-unstable) + kime; `mkHost` with specialArgs (username, userFullName, gitUserName, gitUserEmail); `nixosConfigurations.workstation`; formatter (treefmt/nixfmt/stylua); devShell (statix, deadnix). No home-manager.
- `AGENTS.md` — rewritten: no fork detection/skills/merge rules. Keep: no `with pkgs;`, `statix check . && deadnix . && nix fmt` before commits, branch `master`, conventional commits, package placement convention, "don't discard unrecognized changes", validation table (Nix files → `nh os build .`; sway config → `sway --validate -c <config>`). ADD a delegation mandate: the main agent does not implement — it orchestrates (`researcher`/`scout` for research, one `worker` for implementation, fresh-context `reviewer`s for review) and only runs gates + commits itself.
- `.pi/agent/SYSTEM.md` — seed from current SYSTEM_ENV content (`dynamic/pi-agent/AGENTS.md`), then `ln -sfn ~/dotfiles/.pi/agent/SYSTEM.md ~/.pi/agent/SYSTEM.md`.
- `hosts/workstation/hardware-configuration.nix` — copy existing as-is.
- `hosts/workstation/configuration.nix` — hostName, systemd-boot + memtest86, timeZone Asia/Seoul, stateVersion 25.11, cloudflare-warp, imports: hardware-configuration, ../../modules/base, ../../modules/desktop, ../../modules/drivers/arc.
- `modules/base/`:
  - nix settings (experimental-features flakes/nix-command, auto-optimise-store, trusted-users root+@wheel, gc weekly `--delete-older-than 7d`)
  - `security.sudo.wheelNeedsPassword = false`
  - networking: nameservers (1.1.1.1/8.8.8.8/1.0.0.1/8.8.4.4), networkmanager, nftables, `firewall.enable = false` (warp)
  - `nixpkgs.config.allowUnfree = true`, nix-ld with stdenv.cc.cc + zlib
  - users: `users.users.aperso` (isNormalUser, extraGroups networkmanager wheel kvm video render), `environment.variables.SSL_CERT_FILE`
  - `programs.bash` interactiveShellInit (PS1, `$HOME/.local/bin` PATH, aliases pi/oc/claude, gh token export, devenv hook), `programs.git` (name/email + gh credential helper), `programs.ssh` (client extraConfig from old ssh.nix), `programs.direnv` + nix-direnv
  - `users.users.aperso.packages`: nh, gh, nix-search-cli, zip, unzip, ripgrep, jq, bat, fd, fzf, killall, uv, nodejs, pnpm, devenv. Drop mtr/hping.
  - `environment.sessionVariables.NH_OS_FLAKE = "/home/aperso/dotfiles"`
  - `systemd.tmpfiles.rules` — one `L+` for noctalia config.toml (see desktop)
- `modules/desktop/`:
  - `programs.sway`: enable, `wrapperFeatures.gtk = true`, extraSessionCommands (MOZ_ENABLE_WAYLAND, QT_QPA_PLATFORM=wayland, QT_QPA_PLATFORMTHEME=gtk3, XCURSOR_THEME=Bibata-Modern-Ice, XCURSOR_SIZE=24), extraConfig: keybinds ported from `dynamic/hypr/hyprland.lua` (super+enter alacritty, super+d or super+r noctalia launcher via `noctalia msg ...`, super+q close, alt+enter fullscreen, super+shift+s flameshot gui -s -c, XF86MonBrightness brightnessctl 5%, super+arrows focus/move/resize, workspaces 1-9, drag/resize mouse), input xkb `korean:ralt_hangul,korean:rctrl_hanja`
  - `programs.noctalia`: enable, `systemd.enable = true`, `recommendedServices.enable = true`; base config.toml via `pkgs.writeText` (theme dark, wallpaper directory `~/dotfiles/files/wallpapers`, `[theme.templates] builtin_ids = ["sway","alacritty","gtk3","gtk4","qt"]`), tmpfiles `L+ ~/.config/noctalia/config.toml` → store path
  - greetd: useTextGreeter, `tuigreet --cmd 'sway'`
  - `xdg.portal.extraPortals = [ xdg-desktop-portal-wlr ]`, config sway Screenshot → wlr
  - fonts: freesentation (existing derivation moves to modules/desktop/pkgs/ or inline), inter, cascadia-code, nerd-fonts.caskaydia-cove, fontconfig KO config, `programs.dconf` profile
  - `i18n.inputMethod` kime (package from `inputs.kime`), `services.xserver.xkb` layout us + `terminate:ctrl_alt_bksp`
  - services: pipewire (no jack), gnome-keyring, gvfs, upower
  - `environment.systemPackages`: alacritty.terminfo, bibata-cursors, brightnessctl, libva-utils
  - `xdg.mime.defaultApplications` → firefox
  - GUI apps in `users.users.aperso.packages`: alacritty, firefox, zed-editor, vesktop, nautilus, pwvucontrol, nixd, nil, flameshot
- `modules/drivers/arc.nix` — `hardware.graphics.enable = true`, `extraPackages = [ intel-media-driver ]`
- `modules/drivers/radeon.nix` — `hardware.graphics.enable = true`, `services.xserver.videoDrivers = [ "amdgpu" ]` (module only, for future)

Then validate:

```bash
nix flake update nixpkgs        # pulls in pkgs.noctalia + newer sway bits
# re-verify queued research items against the NEW rev (options may have changed)
statix check . && deadnix .
nix fmt
nh os build .                   # build BEFORE switching
# sanity-check the generated artifacts on the build host (system-side verification)
git add -A
git commit -m "refactor: rewrite repo — single host, sway + noctalia v5, no home-manager"
```

## Phase 3 — Switch + cleanup (live machine)

```bash
nh os switch .                  # greetd now launches sway; current Hyprland session survives until logout

# post-switch cleanup
find ~/.config -xtype l         # review dangling HM symlinks, delete the ones HM created
rm -rf ~/.config/hypr           # v4 Hyprland leftovers (generated noctalia-colors.lua etc.)
nix-collect-garbage -d          # later, after a successful sway boot
```

First sway login verification (system-side checks on the live session):

- `noctalia config validate` passes
- bar/launcher/notifications render (noctalia autostarted via systemd; fallback `exec noctalia --daemon`)
- Korean input works (kime + xkb options)
- launcher, screenshot (flameshot), brightness, volume (pwvucontrol), workspace keybinds all fire
- battery widget present (upower)

Then delete this file and commit.

## Rollback

- Working tree: `git checkout master -- .` (old tree is one commit back) or restore `/tmp/dotfiles-rewrite-backup-*`
- Live system: `nh os rollback` (previous generation still has Hyprland + home-manager)

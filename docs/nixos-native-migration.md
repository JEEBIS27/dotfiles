# NixOS native migration

## Implemented configuration (not yet validated on the destination PC)

- Ghostty is managed by Home Manager with the existing font and shared palette.
- `jeebis-terminal` launches fish or the requested application directly. It does
  not call Hyprland IPC, Rio or TUIOS. Its Ghostty executable is a Nix dependency.
- Super+Enter opens Ghostty with an independent `tmux new-session`;
  Super+Alt+Enter opens plain Ghostty. Shift adds placement directly below the
  initially focused tiled window. Running processes are not restored after reboot.
- `jeebis-agents` directly launches Herdr App, outside Ghostty and tmux.
  The GUI app and herdr-core are separate fixed-version binary Nix packages.
- Theme rendering now produces `ghostty.conf`; reload only signals Ghostty
  processes owned by the current user that already installed a reload handler.
- NixOS owns the Fcitx daemon and MejiroIME server; Home Manager seeds a writable
  Fcitx profile and installs the candidate UI metadata.
- MejiroIME source and its Zenzai model URL/hash are pinned.
  Herdr App 0.1.13 and core 0.1.18 use fixed official release URLs and SHA-256 hashes.
  Their own tested package/toolchain pins are explicit exceptions to shared pkgs.
- Home Manager integrated with NixOS uses the system package set.

## Default NixOS profile

`nixosModules.personal` now imports `nixosModules.niri`: `just switch` on an
existing integrated NixOS installation selects Niri and MejiroIME without editing
`/etc/nixos/flake.nix`. Hyprland/UWSM are disabled and SDDM uses Weston. Host
boot, disks, users, stateVersion and graphics drivers remain host-owned.

The Niri profile launches plain Ghostty directly through an absolute Nix store
path (`Super+Alt+Enter`). `Super+Enter` uses Ghostty with tmux. No Omarchy cwd
helper, gtk-launch, Rio or TUIOS participates in these terminal shortcuts.
Legacy runtime/aliases, TUIOS hooks and Rio configuration are not deployed by
this profile. Lua sources remain in the repository for the Omarchy profile.

MejiroIME is the only declared Japanese engine. Its upstream NixOS module
owns the server and adds the Fcitx addon; no local checkout is needed. The
published source is pinned at `88d832c4a84ab7233ee865585a31877b2f6adce1`.
Git access to the MejiroIME repository is required on the target PC; credentials
are local and are never placed in the flake URL or repository. Anonymous archive
access returned 404 here, so the source uses the Git transport.
Uncommitted development changes are not included. Update this input after
publishing the desired MejiroIME revision. The neural worker starts on CPU;
Vulkan may be selected explicitly after real GPU validation. The model is
Zenz v3.1 small Q5_K_M with a pinned revision and SHA-256.

MejiroIME's candidate UI patch targets Fcitx 5.1.23. The daemon, classic UI,
addon and build dependencies therefore use the existing `nixpkgs-apps` pin as
one explicit compatibility group. The base NixOS Fcitx 5.1.19 has a different
`InputWindow::paint` signature and cannot accept that patch. `neuralPkgs` is
passed explicitly as well, avoiding upstream's impure platform autodetection.

Do not use `desktop-vm` as a real machine configuration: its root is tmpfs.
Do not change boot/disk/hardware configuration to the VM example.

## Acceptance and remaining implementation

No builds, automated tests, activation, compositor reload or reboot were run
for this migration, as validation is being performed on the destination PC.
Lock generation only records dependencies and does not prove package builds.

1. Check plain Ghostty/fish, direct Yazi/Helix launches, palette changes and images.
2. Validate the migrated application map and normal/below-split launch behavior
   on Niri. Shift resizes, Ctrl swaps/reorders, and Ctrl+Shift moves windows.
   Add per-host display/touch declarations; the Hyprland-only automatic rotation
   service is disabled in Niri. See `niri-keybindings.md` for mappings and limits.
3. Check Niri login, Tide IPC, portals/screen sharing, image/video/GIF wallpaper,
   static lock wallpaper, actual locking/authentication, suspend and SDDM.
4. On Niri, check MejiroIME in Ghostty, browser, GTK and Qt: live/neural
   conversion, Mejiro input, candidate placement, focus, reconversion, logout and
   suspend. Existing regular Fcitx profiles are preserved; select MejiroIME there
   if the profile predates this migration. New profiles contain keyboard-jp and
   MejiroIME only. No other Japanese engine is installed by this profile.
5. Herdr App palette and pinned Codex launch settings are implemented. Validate
   agent status, window-close/reopen session persistence, and native Codex resume. Migrate TUIOS-owned Codex hooks before
   removing TUIOS. The Niri Agent shortcut and the generated Hyprland Codex app shortcut
   now launch Herdr App. The old TUIOS helper sources remain for recovery.
6. Move actual host configurations into the repository while keeping their
   hardware declarations separate. Replace `/etc/nixos` generated-wrapper lock
   updates with a single authoritative repository lock and explicit host routing.
7. Legacy TUIOS, Rio and Omarchy sources remain in the repository for the
   Omarchy profile, but are not deployed by Niri. Audit pre-existing mutable Codex
   hooks before agent acceptance: disabling the old activation hook does not
   remove hook entries previously written into local Codex state. App package-set
   exceptions and remaining editor checkout links can be simplified separately.
8. Verify a second PC with separate hardware/display declarations.

Private credentials, chat history, learned dictionaries, cloud contents and
running-session state are not repository configuration.

## Herdr App packaging

`packages/herdr-app.nix` repackages the official Linux GUI binary with
`autoPatchelfHook`, explicit Wayland/X11/Vulkan/font libraries and a wrapper that
finds the pinned core. `packages/herdr-core.nix` installs the official static musl
binary and its `hc` alias. No upstream installation script is executed.

The icon is installed in the standard icon directory rather than beside the
executable. In pinned App 0.1.13, that disables its app self-updater's install-root
detection (`src/update.rs::find_root`). The core detects package-manager ownership
from its Nix-store path. Recheck these behaviors whenever versions change.
Existing local `settings.json` may explicitly select a different core; no private
settings are overwritten by this module.

Official metadata:
- https://releases.herdr.dev/app/latest.json
- https://releases.herdr.dev/core/latest.json

The x86_64 downloads matched the published hashes and their ELF dependencies were
inspected. No Nix builds, executable launches, GUI/Wayland/IME tests or activation
were performed. ARM64 hashes are recorded from official metadata; that platform
has not been inspected or tested here. NixOS needs working Vulkan drivers from
the destination machine's graphics configuration.

## ChatGPT desktop application

The official Linux desktop app is packaged from Debian release
`26.1103.32239`, using the versioned official pool URL and the SHA-256 published
in OpenAI's package index. The downloaded amd64 package matched that hash.
`dpkg-deb` only extracts its contents: no apt/pacman setup or maintainer scripts
are executed. `autoPatchelfHook` and explicit dependencies supply the Nix runtime.
The PC package set permits only the named unfree applications ChatGPT, Slack,
Spotify and Obsidian required by the declared application map.

The package is currently x86_64-only. Account login, chat history and private
app data remain local. NixOS is not an officially supported Linux distribution.
The app follows upstream's default XWayland behavior; native Wayland can be
requested explicitly with `chatgpt --ozone-platform=wayland` after fully quitting.
No sandbox-disabling flags are added.

Niri binds Super+Alt+C to `chatgpt`. Its new-window/focus behavior is controlled
by the app, not by Hyprland IPC. The former fresh-window shortcut is preserved
for the Hyprland recovery profile through its existing helper. The Niri path
contains no promise that launching an already-running app creates another window.
The `codex:` callback scheme is registered without changing HTTP/HTTPS defaults.

Reference: https://learn.chatgpt.com/docs/linux/linux-app
Package metadata: https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages

Only archive metadata, hashes and ELF dependencies were inspected. No Nix build,
login, GUI startup, IME, callback or bundled Codex sandbox behavior was tested.

## Stage 1–2 implementation status

PC output/input/static rotation settings are now separate from the common Niri
layout. A per-PC module example and hardware/validation boundaries are documented
in `machine-profiles.md`. Real target output names and GPU configuration still
need confirmation; no real-machine profile was invented.

Herdr palette generation, owned preference reconciliation, explicit core path,
and pinned Codex `--no-daemon` launch were implemented. Existing settings/program
entries are preserved and locally backed up. Source syntax, narrowed Nix settings
and assertions, isolated JSON reconciliation, and all three Herdr palettes passed.
No system derivation build or desktop activation has been completed.

The target user will run the stage 3 commands, one step at a time. Before any
switch, identify the target GPU and current configuration, transfer reviewed
changes, and build the intended host profile. Stop at the first failure. No
commit, push or merge is implied by the source work.

## Applying this migration

Apply only after the migration commit has been published to the selected branch.
From a TTY in an existing integrated installation:

```bash
cd ~/dotfiles
git pull --ff-only
just switch
```

A successful switch installs the next session; it does not replace the running
Hyprland process with Niri. Log out and select **Niri** in SDDM, or reboot after
success. Then check `Super+Alt+Enter` (plain Ghostty), `Super+Enter` (tmux) and
`Super+F` (Tide launcher), in that order. If switch fails, stop and capture the
first actual error. Do not continue with graphical acceptance checks.

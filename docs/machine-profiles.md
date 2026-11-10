# PC-specific configuration

`modules/machine.nix` owns Home Manager options under `jeebis.machine`.
`files/niri/config.kdl` contains only the common desktop layout and keybindings.
No output name, resolution or GPU is inferred from the machine doing the build.

Keep one Home Manager module per real PC in `hosts/machines/`, using
`example.nix` as a schema example. The example is not imported automatically.
Add that PC's module to its `home-manager.users.jeebis.imports` in the NixOS
composition. This remains separate from the common personal/Niri modules.

```nix
{ ... }: {
  jeebis.machine = {
    outputs."REAL-OUTPUT-NAME" = {
      mode = "1920x1080@60";
      scale = 1.25;
      position = { x = 0; y = 0; };
      transform = "normal";
    };
    keyboard = { layout = "jp"; model = "jp106"; };
    touchpad = { tap = true; naturalScroll = true; };
    touchOutput = "REAL-OUTPUT-NAME";
  };
}
```

Use only actual output names reported by the target session (`niri msg outputs`),
not the placeholder above. Leaving `outputs = { };` lets Niri choose its defaults.
`transform` is static display rotation, not automatic sensor-based rotation.
Niri automatic rotation is not implemented in this migration and the old
Hyprland rotation daemon remains disabled for Niri.

NixOS-only GPU, firmware, boot and disk settings stay in that PC's existing
`configuration.nix` / `hardware-configuration.nix`. Do not copy the build host's
hardware profile or the tmpfs VM example to a real machine. The Niri SDDM greeter
uses Weston; it does not run the old Hyprland rotation helper.

`nixos/machine.nix` separately declares opt-in recovery-greeter rotation settings
under NixOS `jeebis.machine.greeterRotation`. The old embedded ELAN device IDs
were removed. Automatic recovery-greeter rotation defaults off, with an empty
touch-device list until a real machine supplies it.

## Validation boundary

The common/default configuration and Herdr activation script were evaluated with
the Niri VM module composition: no NixOS assertion failures. Source syntax and
isolated Herdr preference-merge/backup behavior were checked. Herdr palette JSON
was generated for Kanagawa, Tokyo Night and Catppuccin in temporary directories.

A full-system derivation evaluation was intentionally interrupted because it
expanded into fetching all existing Helix grammars. No package build, system
switch, GUI launch, authentication, suspend or real hardware validation was run.
The execution host is Omarchy; the target NixOS PC is checked by its user.

## Herdr ownership

`configureHerdr` reconciles only these public preferences: pinned core path,
shared theme name, terminal font and font size, and the Codex command
(`codex --no-daemon`, supported by the pinned Codex revision). Other settings and
program entries are retained. Original mutable settings/programs get one local
`.before-home-manager` backup. Invalid JSON or user-owned symlinks stop the update.

Theme changes atomically write `themes/jeebis.json` inside Herdr's own watched
configuration directory. The default `main` layout inherits the selected theme;
a custom layout with explicit theme/font values takes precedence by upstream
design. Existing layouts, mods, credentials, agent hooks, histories and sessions
are not replaced.

Herdr-core keeps live terminals when the app window closes. After a reboot or
core crash, upstream restores shells/layouts rather than running programs.
Native Codex history can be resumed with Codex's resume command. Automatic chat
resume and removal of legacy TUIOS hooks are not claimed by this configuration.
Verify actual agent status and window-close/reopen behavior on the target PC.

Upstream schema references (pinned App 0.1.13 source):
- https://github.com/herdrdev/herdr-app/blob/adf94cb2c9b6f1cadbb31c51f84114b1aa332f0a/src/settings.rs
- https://github.com/herdrdev/herdr-app/blob/adf94cb2c9b6f1cadbb31c51f84114b1aa332f0a/defaults/AGENTS.md

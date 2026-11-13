# Tide Island

Home Manager installs the Quickshell edition of [Tide Island](https://github.com/enhaoswen/Tide-island), pinned to 1.0.49 with a source checksum. The upstream installer is not run. Qt/C++ backends, Quickshell and runtime tools are declared in `packages/tide-island.nix`.

The OpenGL successor is under development and is not used here. The Quickshell edition is no longer actively maintained upstream.

## Lifecycle

- `tide-island.service`: island, launcher, notifications, clipboard and session lock.
- `jeebis-wallpaper.service`: mpvpaper for still images, GIF and video.
- `jeebis-idle.service`: swayidle, 600-second idle lock and before-sleep lock.
- `jeebis-display-rotation.service`: independent personal display rotation.

UWSM starts the graphical session services. Do not add another `exec-once` launcher. `jeebis-desktop shell restart` restarts Tide. Log out and back in after migrating; do not keep the previous shell running alongside Tide.

## Managed settings

`modules/desktop.nix` declares `tide-island/userconfig.json`, keybindings and services. Home Manager seeds this JSON only when missing, as a writable local file. GUI changes persist across activations. Upgrading removes the former managed link and seeds writable defaults. Changes to the Nix defaults do not overwrite an existing local configuration. Credentials, clipboard history, calendar notes and caches remain local.

| Shortcut | Action |
|---|---|
| Super+F | Application launcher |
| Super+Shift+Esc | Settings |
| Super+Esc | Power menu |
| Super+N | Toggle island |
| Super+Shift+B | Show island |
| Super+Shift+N | Hide island |

## Theme and wallpaper

Use [the theme tool](theme-tooling.md) for fixed palette + home wallpaper + lock wallpaper presets. Tide's color tokens read the generated `jeebis-theme/current/tide-colors.json`; the lock screen reads the generated static lock wallpaper. The small source adapter is `packages/desktop/tide-integration.py`. Theme changes do not restart the shell or its password conversation.

The wallpaper picker invokes `jeebis-desktop wallpaper set`; mpvpaper owns rendering independently of the shell. Video/GIF home wallpaper requires a static `lockWallpaper` in the preset. The picker changes the home wallpaper only; choosing a theme preset restores that preset's pair.

## Previous shell

The customized former shell is archived in [JEEBIS27/jeebis-shell](https://github.com/JEEBIS27/jeebis-shell). Home Manager does not package or synchronize it. Compatibility command adapters and Hyprland defaults retained in this repository are separate from the removed Quickshell shell; they do not require an installed Omarchy OS on NixOS.

This migration has not been built or tested on the destination PC. Login, PAM unlock, clipboard, notifications, theme changes, video playback and suspend require destination testing.

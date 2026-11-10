# Niri keybindings and application launches

## Source of truth

`files/desktop/applications.nix` defines application keys, executable argument
arrays and window app IDs. `modules/niri.nix` generates the matching normal and
below-split bindings and a JSON catalog with Nix-store executable paths. The
Hyprland recovery profile still keeps its original Lua definitions separately.

All 20 application entries from the prior Lua map are represented. Agent work
opens Herdr App. YouTube uses a Helium app window instead of a private Chrome
extension desktop ID. Web URLs and flags are separate argv entries. Slack,
Spotify, Obsidian, Nautilus, LocalSend, Zathura and btop are declared packages.

| Shortcut | Action |
| --- | --- |
| Super+Alt+Return / Space | Plain Ghostty / Helium |
| Super+Alt+A / B / C / D / E | btop / Slides / ChatGPT / Herdr App / Sheets |
| Super+Alt+F / G / I / M / N / O | Files / GitHub / Slack / Spotify / Helix / Obsidian |
| Super+Alt+Q / R / U / W / X / Y / Z | Calendar / Teams / YouTube / Docs / LocalSend / Yazi / Zathura |
| Add Shift to an app shortcut | Open a new window directly below the initially focused tiled window |
| Super+Return / Super+Shift+Return | Ghostty + independent tmux session, right / below |
| Super+Alt+Return / Super+Alt+Shift+Return | Plain Ghostty, right / below |
| Super+HJKL or arrows | Focus left/down/up/right |
| Add Shift | Resize by 50 logical pixels |
| Add Ctrl | Swap left/right; reorder up/down |
| Add Ctrl+Shift | Move column left/right; window up/down |
| Super+W / Super+Shift+W | Close window / snapshot and close workspace windows |
| Super+T / Super+Shift+T | Focus floating/tiling layer / toggle window floating |
| Super+Shift+F / Super+Ctrl+F | Maximize/restore / fullscreen |
| Super+Tab / Super+Shift+Tab / Super+Ctrl+Tab | Next / previous / formerly focused workspace |
| Super+PageUp/PageDown or Super+wheel | Previous/next workspace |
| Super+Shift+PageUp/PageDown | Previous/next monitor |
| Super+Ctrl+PageUp/PageDown | Move window to previous/next workspace |
| Super+1..0 / Super+Shift+1..0 | Select / move window to named workspace 1..10 |
| Super+F / Super+Shift+Escape | Tide launcher / settings |
| Super+N / Super+Shift+B / Super+Shift+N | Toggle / show / hide Tide Island |
| Super+Alt+T | Cycle shared theme |
| Super+Alt+Shift+K | Niri hotkey overlay |
| Super+R | Cycle preset column widths |
| Super+V / Super+Shift+V | Consume or expel a window left/right |
| Super+Ctrl+T or Super+Alt+Shift+J | Toggle tabbed column display |
| Super+Shift+S or Print | Screenshot |
| Super+Escape | Tide session lock |

## Window selection and split placement

`packages/desktop/niri-actions.py` uses Niri's JSON socket API, reviewed against
pinned Niri 26.04. Shift launches capture the original workspace and focused
window ID, then wait up to 15 seconds for a newly created matching window.
Existing windows are never selected as a fallback, including singleton apps
that only activate an already-open window.

When the new window occupies a single column immediately to the original
column's right, it is consumed into that column. Niri appends consumed tiles at
the bottom, so the helper then reorders the new tile immediately after the
original one. This also handles a column already containing several windows,
rather than treating "below" as simply "at the bottom of the column".
If a window rule already put the new tile in the original column, only the
vertical ordering is adjusted. It does not change the column width.

Niri 26.04 has no ID argument for vertical reorder operations. The helper
focuses the verified new tile, then checks the active window, workspace and
launch generation before each step. A newer launch, workspace change or focus
change cancels the remaining work. Actual input and IPC cannot be made atomic;
focus changes during a step still need real-session verification.

Floating windows and unexpected multi-window/column layouts are left alone with
a notification. Without an initially focused window, the app opens normally.
Apps that do not create another window cannot produce a new split; their
existing windows are not moved to simulate one.

## Terminal sessions

Super+Return starts Ghostty with `tmux new-session`; Shift additionally places
that new Ghostty window directly below the original tiled window. Each launch
creates its own tmux session, so separate terminal windows do not mirror one
shared tmux session. Detached sessions can be selected with `tmux ls` and
`tmux attach -t <session>`; no automatic existing-session selection is performed.

Super+Alt+Return starts plain Ghostty/fish; Shift requests the same below-split
placement without tmux. These are Niri window splits, not tmux pane splits.
Working-directory inheritance is best effort from the focused client PID; it
cannot guarantee a shell's current cwd. tmux persistence is process lifetime
persistence, not restoration of running processes after a reboot.

## Differences and validation boundary

Niri has a scrolling layout. Dwindle preselection, Hyprland special workspaces,
the exchange-direction submap, and the old floating-group algorithms are not
translated to arbitrary lookalikes. Vertical reorder and move share the Niri
operation; horizontal swap and column move remain distinct. Split placement
requires actual layout testing. No Hyprland IPC, Omarchy
launcher, TUIOS, or gtk-launch is used by the generated Niri application map.

Per-host outputs/touch mappings and replacement automatic rotation remain
separate work. Tide's old fixed-bar/fixed-notch distinction is represented only
by show/hide/toggle; the Niri layout switch toggles tabbed columns, not Dwindle.

Only source/syntax and diff checks are performed here; no Nix build, Niri session
activation, hotkey, app-window, fullscreen, or session-lock test has been run.
In particular simultaneous launches of the same application, Chromium app IDs,
new vs reused ChatGPT/Herdr windows, and focus transitions require real-session
verification before treating these as accepted behavior.

References:
- https://niri-wm.github.io/niri/IPC.html
- https://github.com/niri-wm/niri/blob/v26.04/niri-ipc/src/lib.rs
- https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html

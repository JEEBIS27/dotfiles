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
| Add Shift | Resize by 10 percentage points; horizontal resizing compensates the adjacent column |
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
| Super+Alt+Shift+K | Search keybindings by typing (Fuzzel) |
| Super+R | Cycle preset column widths |
| Super+V / Super+Shift+V | Consume or expel a window left/right |
| Super+Ctrl+T or Super+Alt+Shift+J | Toggle tabbed column display |
| Super+Shift+S or Print | Screenshot |
| Super+Escape | Tide session lock |
| Super+Ctrl+Escape | Tide power menu (shutdown/reboot/suspend/logout) |

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


## Paired resizing and width history

Horizontal resizing uses 10 percentage point steps and compensates the current
partner so the pair fills 100%. Each normal paired column is limited to 10–90%;
maximizing temporarily uses 100%. A sole column stays full-width. Vertical
resizing uses 10 percentage points without changing the neighboring column.
Floating windows resize independently. Percentage calculations assume the current
4px gaps and no left/right exclusive panels or horizontal struts.

On focus movement between adjacent columns, the more recently changed width is
preserved and the other column fills the remaining space. Manual and automatic
changes have equal priority. Never-resized columns have no timestamp. One paired
operation gives its actually changed columns the same timestamp; ties preserve
the previously focused column. No-op changes do not refresh timestamps. History
is shared by the keyboard helper and watcher, scoped to the compositor session.

Examples (`*` is focused, `| ... |` is the visible pair):

```text
|50 / 50*| 50   -> resize middle to 40 -> |60 / 40*| 50
|60 / 40*| 50   -> focus right         -> 60 |40 / 60*|
60 |40 / 60*|  -> resize right to 70  -> 60 |30 / 70*|
60 |30 / 70*|  -> focus middle, left  -> |70* / 30| 70
```

`Super+Shift+F` saves the current partner and width before switching to 100%.
Shrinking again restores that partner and frames the pair without changing focus,
including when the focused column is in the middle or at the right edge. This
avoids the blank right-hand half left by the upstream view anchoring behavior.
The packaged Niri patch lets `CenterWindow` on an adjacent inactive window frame
its pair with the focused column; upstream treats that request as a no-op.

The auto-width service compensates an externally resized column after its width
stays unchanged for 300 ms. This is a debounce, not a button-release notification:
a pause during a drag can trigger it. Mouse resizing keeps the chosen width rather
than snapping to 10% steps. The service waits for actual client geometry commits
before framing a newly resized pair. Application minimum sizes can prevent an
exact 100% pair.

Regression checks: `python3 scripts/check-niri-resize.py`. The isolated-compositor
integration check uses `scripts/fixtures/niri-layout-client.c` and validates the
real widths, focused window, and screenshot color spans.



## Searchable keybindings

Super+Alt+Shift+K opens Fuzzel with the active managed Niri bindings. Type a key,
action, or application name to narrow the list (Japanese descriptions and English
keywords are both included). Escape closes it; selecting a row only closes the
reference list and never executes the action. The list reads the current generated
config, including application and workspace bindings, rather than a separate static
shortcut list. Niri's stock overlay is not searchable.

Super+Ctrl+Escape opens Tide's power menu. Super+Escape continues to lock the session.

# TUIOS settings and actions

The patched nixpkgs TUIOS 0.10.1 client shows a gear in the three leftmost
cells of row one. It overlays the existing row; it does not change the pane's
rows, scrollback, or stored text. With a visible dock it sits at the dock's
left edge (top or bottom). Click it, use arrows/j/k and Enter, or click a row.
Escape closes the menu. It captures only its own mouse press and release.

The Display page lists individual controls: border style, pane separators,
shared borders, titles, window buttons, scrollbar, dock, sidebar, motion and
unfocused dimming. Dimming accepts 0–90%; Left/Right move by 1%, and Enter
opens direct numeric input. Changes apply live and are saved.

Defaults hide decoration, sidebar and dock, disable motion and use 0% dimming.
Theme colors remain independent. No Minimal preset or diagnostics entry is
added. The launcher clears an inherited NO_COLOR so a GUI terminal can
negotiate colors normally.

The upstream geometry still matters: shared borders remove each tiled pane's
own title/control frame. To show titles or buttons, disable shared borders and
choose a visible border style as well as enabling that individual control.
Separators have their own switch and can be hidden without resizing panes.

The other menu groups contain session creation/switch/rename/detach/end;
pane splits/focus/swap/zoom/equalize/rotate/close/workspace move; workspace
creation/switch/rename/close; BSP, master-stack and scrolling layouts;
copy/search/scrollback; Yazi, scratch, Codex, palette, sidebar, Inbox and
notification focus. Closing panes/workspaces and ending sessions ask for
confirmation; detaching retains processes. Deleting saved snapshots is not
offered: no equivalent capability has been implemented.

Each actionable row resolves its hint from the live keybinding registry,
preferably a global binding, otherwise a complete leader chord. A binding that
only works in window mode says so. An unbound action has no hint.

## Configuration ownership

Home Manager manages `~/.config/tuios/defaults.toml` and a small `config.toml`
entrypoint. The entrypoint includes the defaults, then `local.toml`.
Home Manager creates `local.toml` only if absent and never overwrites it.
TUIOS's own layered-config writer redirects changes from read-only Nix files
to that writable include. Local choices override future defaults.

“Edit configuration” opens `local.toml` in `$VISUAL`, `$EDITOR`, or `nvim`, in
that order, in a new pane. Editor arguments separated by spaces are accepted;
shell expressions in editor variables are not evaluated. The binding is
`Alt+E`, then `Alt+,`. Codex also has `Alt+E`, then `Alt+C`.
Use “Reload configuration” after manual edits. Restarting the client retains
saved settings. An existing client must detach and reconnect to load a newly
installed client binary; active panes need not be terminated.

The extension is a source patch at `packages/tuios/settings-gear.patch` applied
to the locked nixpkgs package. No extra flake input or Go dependency is added.
When upgrading TUIOS, rebuild the patch and rerun the native UI check.

## Verification

```sh
python scripts/check-terminal.py --tuios /path/to/patched/tuios
python -m venv /tmp/tuios-menu-tests
/tmp/tuios-menu-tests/bin/pip install pyte
/tmp/tuios-menu-tests/bin/python scripts/check-tuios-gear.py \
  --tuios /path/to/patched/tuios --artifacts /tmp/tuios-menu-results
```

The menu check uses a private daemon and XDG tree, real PTY mouse/key input,
and writes screen snapshots plus raw ANSI output. It checks overlay visibility,
menu navigation, numeric editing and 1% steps, a writable local override while
defaults stay unchanged, a single gear after enabling the bar, actual shortcut
hints, scrolling layout selection, an actual pane split, close confirmation,
and opening the correct file in an editor.

On the desktop, also confirm the gear does not reserve a line, clicking beside
it still reaches the application, scrolling and resizing remain normal, the
bar receives the gear when enabled, session end asks before killing processes,
and settings survive detach/reconnect. Japanese IME, Yazi image transport and
colors inside applications remain separate runtime checks; these are not
proven by this menu check.

Rollback: activate the previously recorded Home Manager generation and restore
its recorded configuration links as described in `terminal-migration.md`.
Do not delete local.toml; it contains the user's choices. Git history retains
the original package configuration and the native patch can be reverted.

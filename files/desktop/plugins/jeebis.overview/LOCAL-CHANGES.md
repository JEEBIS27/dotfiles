# Local adaptation

Upstream: https://github.com/AyushKr2003/omarchy-overview
Commit: b130ce11d1742663da2d01f554656eba8624a1bf

Packaged as `jeebis.overview`. The unsupported `menu` kind without a menu entry
point was removed to pass the installed Omarchy manifest validator. The plugin
remains an overlay. Default layout is the workspace grid and search is disabled.
No Hyprland keybindings are changed; the bar opens it through shell IPC.

Compatibility: older Commons.Style versions without reduceMotion/duration use
normal animation durations and do not enable reduced motion.

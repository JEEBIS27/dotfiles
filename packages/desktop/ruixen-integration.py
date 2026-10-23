"""Connect Ruixen's presentation to the shared desktop backend at build time."""
from pathlib import Path
import re
import sys
import os

root = Path(sys.argv[1])
commands = {
    'omarchy-theme-bg-switcher': 'jeebis-ruixen-wallpaper-pick',
    'omarchy-theme-bg-set': 'jeebis-ruixen-wallpaper-set',
    'omarchy-theme-switcher': 'jeebis-ruixen-theme-pick',
    'omarchy-theme-set': 'jeebis-ruixen-theme-set',
    'omarchy-theme-list': 'jeebis-ruixen-theme-list',
}
for path in root.rglob('*'):
    if not path.is_file() or path.suffix not in ('.qml', '.js', '.sh', '.py'):
        continue
    text = path.read_text()
    if path.suffix == ".qml":
        config_import = os.path.relpath(root / "plugins/ShellConfig.js", path.parent)
        text = re.sub(r'import "[^"\n]*ShellConfig\.js" as ShellConfig',
                      lambda _: f'import "{config_import}" as ShellConfig', text)
        settings_import = os.path.relpath(root / "plugins/ruixen.launcher/extensions/settings", path.parent)
        text = re.sub(r'import "[^"\n]*ruixen\.launcher/extensions/settings" as Settings',
                      lambda _: f'import "{settings_import}" as Settings', text)
    for old, new in commands.items():
        text = re.sub(re.escape(old) + r'(?![\w-])', new, text)
    text = text.replace('omarchy restart shell', 'jeebis-desktop shell restart')
    # Include the shared preset wallpapers alongside user-supplied media.
    if path.name == 'list-wallpapers.sh':
        needle = 'find -L "$HOME/.local/state/omarchy/current/theme/backgrounds"'
        text = text.replace(needle, 'find -L "${XDG_DATA_HOME:-$HOME/.local/share}/jeebis-desktop/backgrounds" "$HOME/.local/state/omarchy/current/theme/backgrounds"')
    if path.name == 'list-themes.sh':
        text = '#!/usr/bin/env bash\nexec jeebis-desktop theme catalog\n'
    path.write_text(text)

# Use the same shell radius for real windows, after Ruixen's local look-and-feel.
config = (root / "plugins/ShellConfig.js").read_text()
radius = int(re.search(r"var radius = (\d+);", config).group(1))
(root / "hyprland/jeebis-curvature.lua").write_text(
    "-- Generated from jeebis-shell/ShellConfig.js.\n"
    f"hl.config({{ decoration = {{ rounding = {radius} }} }})\n")

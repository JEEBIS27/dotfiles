"""Connect Ruixen's presentation to the shared desktop backend at build time."""
from pathlib import Path
import re
import math
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
        motion_import = os.path.relpath(root / "plugins/motion", path.parent)
        text = re.sub(r'import "[^"\n]*motion" as Motion',
                      lambda _: f'import "{motion_import}" as Motion', text)
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

# One source of truth for shell and compositor easing. Hyprland accepts cubic
# Beziers: smooth approximates the cosine; OutBack is exactly cubic in time.
preset_match = re.search(r'var hyprlandAnimationPreset\s*=\s*"([^"\n]*)";', config)
preset = preset_match.group(1) if preset_match else "InOutSine"
if preset not in ("Linear", "InOutSine", "OutBack"):
    preset = "InOutSine"
strength_match = re.search(r"var animationOvershoot\s*=\s*([+-]?[\d.]+);", config)
strength = float(strength_match.group(1)) if strength_match else 1.70158
strength = max(0, min(3, strength))
speed_match = re.search(r"var animationSpeed\s*=\s*([^;]+);", config)
try:
    speed = float(speed_match.group(1)) if speed_match else 1
except ValueError:
    speed = 1
speed = max(0.1, min(10, speed)) if math.isfinite(speed) and speed > 0 else 1
float_delay_match = re.search(r"var floatOverlapDelayMs\s*=\s*(\d+);", config)
float_delay = min(60000, int(float_delay_match.group(1))) if float_delay_match else 1000
float_threshold_match = re.search(r"var floatOverlapThresholdPercent\s*=\s*([\d.]+);", config)
float_threshold = float(float_threshold_match.group(1)) if float_threshold_match else 95
float_threshold = max(1, min(100, float_threshold)) if math.isfinite(float_threshold) else 95
curve = {"Linear": "jeebisLinear", "InOutSine": "jeebisSmooth", "OutBack": "jeebisOvershoot"}[preset]
bounded = "jeebisLinear" if preset == "Linear" else "jeebisSmooth"
(root / "hyprland/jeebis-motion.lua").write_text(
    "-- Generated from ShellConfig.js; edit hyprlandAnimationPreset / animationOvershoot there.\n"
    'hl.curve("jeebisLinear", { type = "bezier", points = { {0, 0}, {1, 1} } })\n'
    '-- Cosine S-curve approximation, zero endpoint slopes.\n'
    'hl.curve("jeebisSmooth", { type = "bezier", points = { {0.3642, 0}, {0.6358, 1} } })\n'
    f'hl.curve("jeebisOvershoot", {{ type = "bezier", points = {{ {{0.3333333333333333, {(strength + 3) / 3:.15g}}}, {{0.6666666666666667, 1}} }} }})\n'
    f'return {{ curve = "{curve}", bounded = "{bounded}", preset = "{preset}", speed = {speed:.15g}, floatOverlapDelayMs = {float_delay}, floatOverlapThresholdPercent = {float_threshold:.15g} }}\n')

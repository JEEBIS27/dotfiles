#!/usr/bin/env bash
# Install the managed greeter on an existing Arch/Omarchy host; never restart SDDM.
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Run with pkexec or sudo, passing the built theme and rotation package." >&2; exit 1; fi
theme=${1:?Astronaut package required}
rotation=${2:?Rotation package required}
[[ $theme == /nix/store/* && -f $theme/share/sddm/themes/sddm-astronaut-theme/Main.qml ]]
[[ $rotation == /nix/store/* && -x $rotation/bin/jeebis-display-rotation ]]
backup=$(mktemp -d /var/lib/jeebis-login-backup.XXXXXXXX)
cp -a /etc/sddm.conf "$backup/" 2>/dev/null || true
cp -a /etc/sddm.conf.d "$backup/" 2>/dev/null || true
if [[ ! -d /usr/lib/qt6/qml/QtQuick/VirtualKeyboard ]]; then
  pacman -S --needed --noconfirm qt6-virtualkeyboard
fi
install -d /etc/jeebis-desktop /etc/sddm.conf.d /nix/var/nix/gcroots/jeebis-login
ln -sfn "$theme" /nix/var/nix/gcroots/jeebis-login/theme
ln -sfn "$rotation" /nix/var/nix/gcroots/jeebis-login/rotation
cat > /etc/jeebis-desktop/greeter.lua <<EOF
-- Managed by scripts/install-astronaut-login.sh.
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true }, animations = { enabled = false } })
hl.on("hyprland.start", function() hl.exec_cmd("$rotation/bin/jeebis-display-rotation greeter") end)
EOF
# Main sddm.conf has precedence over conf.d. Preserve every unrelated setting,
# including existing autologin, and override only the managed theme/compositor.
python3 - "$theme" <<'PYTHON'
import configparser,sys
from pathlib import Path
p=Path('/etc/sddm.conf')
c=configparser.ConfigParser(interpolation=None);c.optionxform=str
if p.exists():c.read(p)
for group in ('Theme','General','Wayland'):
 if not c.has_section(group):c.add_section(group)
c['Theme']['Current']='sddm-astronaut-theme'
c['Theme']['ThemeDir']=sys.argv[1]+'/share/sddm/themes'
c['General']['DisplayServer']='wayland'
c['Wayland']['CompositorCommand']='start-hyprland -- --config /etc/jeebis-desktop/greeter.lua'
with p.open('w') as f:c.write(f)
PYTHON
chmod 644 /etc/sddm.conf /etc/jeebis-desktop/greeter.lua
printf 'Installed. SDDM was not restarted. Backup: %s\n' "$backup"

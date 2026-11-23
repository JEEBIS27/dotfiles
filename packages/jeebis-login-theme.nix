{
  pkgs,
  palette ? "catppuccin",
}:
let
  # Use the same display components as the desktop lock.
  lockComponents = ../vendor/jeebis-tide-shell/qml/lockscreen;
in
pkgs.runCommand "jeebis-login-theme" { } ''
    theme="$out/share/sddm/themes/jeebis-login-theme"
    mkdir -p "$theme/TideLock"
    for component in LockScreenView LockCard LockGlyph LockAction LockLayoutHandle; do
      cp "${lockComponents}/$component.qml" "$theme/TideLock/"
    done
    cp ${../files/desktop/login/Main.qml} "$theme/Main.qml"
    cp ${../vendor/jeebis-tide-shell/LICENSE} "$theme/LICENSE"
    cat > "$theme/metadata.desktop" <<'META'
  [SddmGreeterTheme]
  Name=Jeebis Tide Login
  Description=Tide Island lock-screen visuals with SDDM authentication
  Type=sddm-theme
  Version=1.0
  MainScript=Main.qml
  ConfigFile=theme.conf
  Theme-Id=jeebis-login-theme
  Theme-API=2.0
  QtVersion=6
  META
    ${pkgs.python3}/bin/python3 - "$theme/Palette.js" ${../files/desktop/themes}/${palette}.toml <<'PYTHON'
  import json, sys, tomllib
  from pathlib import Path
  c = tomllib.loads(Path(sys.argv[2]).read_text())
  tokens = dict(panel=c['background'], module=c['lighter_background'],
      accent=c['accent'], textPrimary=c['foreground'], textSecondary=c['muted'],
      textMuted=c['muted'], error=c['red'], buttonFill=c['foreground'],
      buttonFillHover=c['bright_foreground'], buttonFillPressed=c['light_foreground'],
      surfaceBorder='#26ffffff', radiusPanel=28)
  Path(sys.argv[1]).write_text('.pragma library\nvar tokens = ' + json.dumps(tokens) + ';\n')
  PYTHON
    touch "$theme/theme.conf"
''

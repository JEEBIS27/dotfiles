{ pkgs }:
pkgs.runCommand "jeebis-desktop-runtime-4.0.4" { nativeBuildInputs = [ pkgs.bash pkgs.python3 ]; } ''
  mkdir -p "$out"
  cp -R ${../../vendor/desktop-runtime}/. "$out/"
  chmod -R u+w "$out"
  cp ${./native-menu.json} "$out/default/omarchy/omarchy-menu.jsonc"
  # Namespace compatibility stays private to this runtime, never a system Omarchy install.
  find "$out" -type f \( -name '*.qml' -o -name '*.js' -o -name '*.lua' -o -name '*.sh' \) -print0 | while IFS= read -r -d $'\0' file; do
    substituteInPlace "$file" \
      --replace-quiet '/usr/share/omarchy' "$out" \
      --replace-quiet '/.config/omarchy' '/.config/jeebis-desktop' \
      --replace-quiet '/.local/state/omarchy' '/.local/state/jeebis-desktop' \
      --replace-quiet '/omarchy"' '/jeebis-desktop"' \
      --replace-quiet '"/omarchy/' '"/jeebis-desktop/' \
      --replace-quiet '/usr/bin/python3' '${pkgs.python3}/bin/python3' \
      --replace-quiet 'omarchy.current.theme' 'jeebis-desktop.current.theme'
    # Rename only the singleton, not properties such as statusColor.r.
    sed -i -E 's/\<Color\./DesktopColor./g' "$file"
  done
  substituteInPlace "$out/shell/Commons/qmldir" --replace-fail 'singleton Color ' 'singleton DesktopColor '
  cat > "$out/default/hypr/autostart.lua" <<'LUA'
  -- UWSM and Home Manager own service startup on NixOS.
LUA
  # Native hardware/service state belongs to NixOS, not distro provisioning.
  cat > "$out/default/hypr/envs.lua" <<LUA
  hl.env("OMARCHY_PATH", "$out")
  hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
  hl.env("XDG_SESSION_TYPE", "wayland")
  hl.env("QT_QPA_PLATFORM", "wayland;xcb")
  hl.env("MOZ_ENABLE_WAYLAND", "1")
  hl.env("XCURSOR_SIZE", "24")
  -- These shared defaults are independent of the distribution.
  hl.config({
    xwayland = { force_zero_scaling = true },
    ecosystem = { no_update_news = true },
  })
LUA
  chmod +x "$out/bin/"*
  find "$out" -type f -name '*.sh' -exec chmod +x {} +
  patchShebangs "$out"
  for file in "$out/bin/"*; do
    substituteInPlace "$file" \
      --replace-quiet '/omarchy/' '/jeebis-desktop/' \
      --replace-quiet '/.local/state/omarchy' '/.local/state/jeebis-desktop' \
      --replace-quiet '/omarchy"' '/jeebis-desktop"'
  done
''

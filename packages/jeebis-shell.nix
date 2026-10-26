{ pkgs, native ? false }:
let
  source = ../vendor/jeebis-shell;
in pkgs.runCommand "jeebis-shell" { nativeBuildInputs = [ pkgs.bash pkgs.python3 ]; } ''
  mkdir -p "$out/plugins" "$out/hyprland"
  cp -R ${source}/ruixen.* ${source}/bars/v2/ruixen.bar ${source}/bars/widgets/ruixen.* "$out/plugins/"
  cp -R ${source}/hyprland/. "$out/hyprland/"
  cp ${source}/LICENSE "$out/LICENSE"
  cp ${source}/ShellConfig.js "$out/plugins/ShellConfig.js"
  chmod -R u+w "$out"
  # Reproduce upstream's shared-file injection without running its installer.
  for target in wallpapers wallpaper-shuffle; do
    cp ${source}/ruixen.wallpaper/WallpaperRotationState.qml "$out/plugins/ruixen.launcher/extensions/$target/"
  done
  cp ${source}/ruixen.wallpaper/wallpaper-effects.py "$out/plugins/ruixen.launcher/extensions/wallpapers/"
  cp ${source}/ruixen.wallpaper/WallpaperRotationState.qml ${source}/ruixen.wallpaper/wallpaper-effects.py "$out/plugins/ruixen.notch/"
  chmod -R u+w "$out"
  ${pkgs.python3}/bin/python3 ${./desktop/ruixen-integration.py} "$out"
  find "$out" -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) -print0 | while IFS= read -r -d $'\0' file; do
    substituteInPlace "$file" \
      --replace-quiet '/.local/share/ruixen-shell' '/.local/share/jeebis-shell' \
      --replace-quiet '*/ruixen-shell/*' '*/jeebis-shell/*' \
      --replace-quiet '/usr/bin/python3' '${pkgs.python3}/bin/python3'
    ${pkgs.lib.optionalString native "substituteInPlace \"$file\" --replace-quiet '/.config/omarchy' '/.config/jeebis-desktop' --replace-quiet '/.local/state/omarchy' '/.local/state/jeebis-desktop'"}
    ${pkgs.lib.optionalString native "sed -i -E 's/\\<Color\\./DesktopColor./g' \"$file\""}
  done
  find "$out" -type f -name '*.sh' -exec chmod +x {} +
  patchShebangs "$out"
''

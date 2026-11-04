{ pkgs }:
pkgs.runCommand "jeebis-display-rotation" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p "$out/bin" "$out/lib"
  cp ${../vendor/jeebis-shell/bars/widgets/ruixen.notch/JeebisDisplayRotation.py} "$out/lib/rotation.py"
  cp ${./desktop/rotation-watch.py} "$out/lib/watch.py"
  makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/jeebis-display-rotation" \
    --add-flags "$out/lib/watch.py $out/lib/rotation.py" \
    --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.hyprland pkgs.coreutils pkgs.bash ]}
''

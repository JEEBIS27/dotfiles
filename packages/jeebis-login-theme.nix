{ pkgs }:
let
  astronaut = pkgs.sddm-astronaut.override { embeddedTheme = "astronaut"; };
in pkgs.runCommand "jeebis-login-theme" { } ''
  theme="$out/share/sddm/themes/jeebis-login-theme"
  mkdir -p "$theme"
  cp -R ${astronaut}/share/sddm/themes/sddm-astronaut-theme/. "$theme/"
  chmod -R u+w "$theme"
  cp ${../files/desktop/login/Main.qml} "$theme/Main.qml"
  # Preserve upstream LICENSE and credits alongside the customized view.
  sed -i 's/^Name=.*/Name=Jeebis Login/; s/^Theme-Id=.*/Theme-Id=jeebis-login-theme/' "$theme/metadata.desktop"
''

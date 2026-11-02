{ pkgs }:
let
  pname = "helium";
  version = "0.20.3.1";
  src = pkgs.fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-H69Thkj+FKHqkuMlyxI4rojEeGZsteY9DSrxcP5MoDc=";
  };
  contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in pkgs.appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/helium.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Helium
Exec=$out/bin/helium %U
Icon=helium
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=helium
EOF
    if [ -d ${contents}/usr/share/icons ]; then
      cp -r --no-preserve=mode ${contents}/usr/share/icons "$out/share/"
    fi
    if [ -f ${contents}/helium.png ] && [ ! -e "$out/share/icons/hicolor/256x256/apps/helium.png" ]; then
      mkdir -p "$out/share/icons/hicolor/256x256/apps"
      cp ${contents}/helium.png "$out/share/icons/hicolor/256x256/apps/helium.png"
    fi
  '';
  meta = {
    description = "Helium browser, pinned official Linux AppImage";
    homepage = "https://helium.computer";
    license = pkgs.lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "helium";
  };
}

{ pkgs }:
let
  quickshell = import ./quickshell.nix { inherit pkgs; };
  deps = with pkgs; [ bash coreutils procps systemd dbus xdg-utils gtk3 brightnessctl
    wireplumber pulseaudio networkmanager bluez power-profiles-daemon upower
    python3 grim slurp ffmpeg curl findutils gnugrep gnused gawk file util-linux
    cliphist wl-clipboard hyprland hyprsunset cava imagemagick jq ];
in pkgs.stdenv.mkDerivation rec {
  pname = "tide-island";
  version = "1.0.49";
  src = pkgs.fetchurl {
    url = "https://github.com/enhaoswen/Tide-island/releases/download/${version}/tide-island-source.tar.xz";
    sha256 = "d6a9828834b52248db1f820bbfa3d8960563c1d166c7381946c366038e77d24f";
  };
  nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config pkgs.qt6.wrapQtAppsHook pkgs.makeWrapper pkgs.python3 ];
  buildInputs = with pkgs; [ systemd qt6.qtbase qt6.qtdeclarative qt6.qtwebsockets
    qt6.qtwayland qt6.qt5compat qt6.qtconnectivity qt6.qtsvg qt6.qtmultimedia ];
  cmakeFlags = [ "-DTIDE_ISLAND_WITH_NIRI=OFF" ];
  # No upstream installer, writes to /usr, or bundled test targets.
  postPatch = ''
    rm -rf tests Tide-island-app/tests
    ${pkgs.python3}/bin/python3 ${./desktop/tide-integration.py} .
  '';
  doCheck = false;
  dontWrapQtApps = true;
  postInstall = ''
    rm -f "$out/bin/tide-island" "$out/lib/systemd/user/tide-island.service"
    makeQtWrapper ${quickshell}/bin/quickshell "$out/bin/tide-island" \
      --add-flags "-p $out/share/tide-island" \
      --prefix QML_IMPORT_PATH : "$out/lib/qt6/qml" \
      --prefix PATH : ${pkgs.lib.makeBinPath deps} \
      --set QUICKSHELL_LYRICS_BACKEND "$out/share/tide-island/bin/lyricsmpris"
    wrapQtApp "$out/bin/tide-island-config-app" --prefix PATH : ${pkgs.lib.makeBinPath deps}
  '';
  meta = { description = "Tide Island Quickshell desktop shell"; homepage = "https://github.com/enhaoswen/Tide-island";
    license = pkgs.lib.licenses.gpl3Only; platforms = pkgs.lib.platforms.linux; mainProgram = "tide-island"; };
}

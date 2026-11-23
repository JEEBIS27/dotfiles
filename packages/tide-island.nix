{
  pkgs,
  withNiri ? false,
}:
let
  directionBindings = import ./direction-bindings.nix { inherit (pkgs) lib; };
  shellSource = ../vendor/jeebis-tide-shell;
  directionFiles = [
    "qml/controlcenter/ControlCenterLayer.qml"
    "qml/island/HorizontalSelection.js"
  ];
  renderedDirections = pkgs.lib.concatMapStringsSep "\n" (
    file:
    let
      rendered = pkgs.writeText (builtins.baseNameOf file) (
        directionBindings.render (builtins.readFile (shellSource + "/${file}"))
      );
    in
    ''cp "${rendered}" "${file}"''
  ) directionFiles;
  quickshell = import ./quickshell.nix { inherit pkgs; };
  wifi = import ./tide-wifi.nix { inherit pkgs; };
  deps =
    with pkgs;
    [
      bash
      coreutils
      procps
      systemd
      dbus
      xdg-utils
      gtk3
      brightnessctl
      wireplumber
      pulseaudio
      networkmanager
      bluez
      power-profiles-daemon
      upower
      glib
      mako
      python3
      grim
      slurp
      ffmpeg
      curl
      findutils
      gnugrep
      gnused
      gawk
      file
      util-linux
      cliphist
      wl-clipboard
      cava
      imagemagick
      jq
      wifi
    ]
    ++ pkgs.lib.optionals withNiri [ (import ./niri.nix { inherit pkgs; }) pkgs.gammastep ]
    ++ pkgs.lib.optionals (!withNiri) [
      pkgs.hyprland
      pkgs.hyprsunset
    ];
in
pkgs.stdenv.mkDerivation rec {
  pname = "tide-island";
  version = "1.0.49";
  src = shellSource;
  nativeBuildInputs = [
    pkgs.qt6.qtshadertools
    pkgs.cmake
    pkgs.pkg-config
    pkgs.qt6.wrapQtAppsHook
    pkgs.makeWrapper
    pkgs.python3
  ];
  buildInputs = with pkgs; [
    systemd
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebsockets
    qt6.qtwayland
    qt6.qt5compat
    qt6.qtconnectivity
    qt6.qtsvg
    qt6.qtmultimedia
  ];
  cmakeFlags = [ "-DTIDE_ISLAND_WITH_NIRI=${if withNiri then "ON" else "OFF"}" ];
  postPatch = renderedDirections;
  doCheck = false;
  dontWrapQtApps = true;
  postInstall = ''
    echo 1 > "$out/share/tide-island/network-auth-version"
    echo 1 > "$out/share/tide-island/activity-version"
    install -Dm644 ${./desktop/tide-origin.py} "$out/lib/tide-activity/tide_origin.py"
    install -Dm644 ${./desktop/tide-activity.py} "$out/lib/tide-activity/main.py"
    makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/tide-activity" \
      --add-flags "$out/lib/tide-activity/main.py" --prefix PATH : ${pkgs.lib.makeBinPath deps}
    rm -f "$out/bin/tide-island" "$out/lib/systemd/user/tide-island.service"
    makeQtWrapper ${quickshell}/bin/quickshell "$out/bin/tide-island" \
      --add-flags "-p $out/share/tide-island" \
      --prefix QML_IMPORT_PATH : "$out/lib/qt6/qml" \
      --prefix PATH : ${pkgs.lib.makeBinPath deps} \
      --prefix PATH : "$out/bin" \
      --set QUICKSHELL_LYRICS_BACKEND "$out/share/tide-island/bin/lyricsmpris"
    wrapQtApp "$out/bin/tide-island-config-app" --prefix PATH : ${pkgs.lib.makeBinPath deps}
  '';
  meta = {
    description = "Jeebis desktop shell, based on Tide Island";
    homepage = "https://github.com/enhaoswen/Tide-island";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = pkgs.lib.platforms.linux;
    mainProgram = "tide-island";
  };
}

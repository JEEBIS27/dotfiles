{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
in pkgs.stdenvNoCC.mkDerivation {
  pname = "jeebis-tide-wifi";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
  buildInputs = [ pkgs.gtk3 pkgs.libnma pkgs.networkmanager ];
  passthru.tests.authentication = pkgs.runCommand "tide-wifi-authentication-tests" {
    nativeBuildInputs = [
      (pkgs.python3.withPackages (p: [ p.pygobject3 p.dbus-python p.python-dbusmock ]))
      pkgs.gobject-introspection pkgs.xvfb-run pkgs.dbus
    ];
    buildInputs = [ pkgs.gtk3 pkgs.libnma pkgs.networkmanager ];
    TIDE_WIFI_SOURCE = ./desktop/tide-wifi.py;
    NO_AT_BRIDGE = "1";
  } ''
    xvfb-run -a python3 ${../scripts/check-tide-wifi.py}
    touch $out
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp ${./desktop/tide-wifi.py} $out/bin/jeebis-tide-wifi
    sed -i '1i#!${python}/bin/python3' $out/bin/jeebis-tide-wifi
    chmod +x $out/bin/jeebis-tide-wifi
    runHook postInstall
  '';
}

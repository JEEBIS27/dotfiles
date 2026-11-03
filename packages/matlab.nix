{ pkgs }:

# MATLAB itself and its license remain outside the Nix store.
pkgs.buildFHSEnv {
  name = "matlab-nix";
  targetPkgs = p: with p; [
    bash coreutils cacert glibcLocales zlib stdenv.cc.cc.lib
    alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat
    fontconfig freetype gdk-pixbuf glib gtk3 nspr nss pam pango
    libdrm libgbm libglvnd libselinux libsndfile libuuid
    libxcrypt libxcrypt-legacy libxkbcommon ncurses
    xkeyboard_config udev procps unzip
    libice libsm libx11 libxcb
    libxcomposite libxcursor libxdamage libxext
    libxfixes libxft libxi libxinerama
    libxrandr libxrender libxt libxtst
    libxxf86vm
  ];
  runScript = pkgs.writeShellScript "matlab-launch" ''
    export QT_QPA_PLATFORM=xcb
    unset QT_PLUGIN_PATH QML2_IMPORT_PATH
    if [ "$#" -gt 0 ]; then
      exec "$@"
    fi
    shopt -s nullglob
    installations=("$HOME"/MATLAB/R*/bin/matlab)
    if [ "''${#installations[@]}" -eq 0 ]; then
      echo 'Install MATLAB first: matlab-nix /path/to/installer/install' >&2
      exit 1
    fi
    exec "''${installations[-1]}" -desktop
  '';
}

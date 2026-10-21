{ pkgs }:
let
  payload = pkgs.stdenvNoCC.mkDerivation {
    pname = "mozkey-ibg-payload";
    version = "0.10.4";
    src = pkgs.fetchurl {
      url = "https://github.com/kazormia296/mozkey-ibg/releases/download/v0.10.4/mozkey-ibg-v0.10.4-archlinux-x86_64.tar.xz";
      sha256 = "33b8f01927c35f512fd4a8bdca4c23165f6532766f21e0580673dc6679ef958f";
    };
    dontUnpack = true;
    # The release embeds /usr/lib/mozkey-ibg. Only the FHS environment exposes it.
    dontPatchELF = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p "$out"
      tar -xJf "$src" -C "$out" --strip-components=1
      rm "$out/lib/mozkey-ibg/llama-server"
      ln -s ${pkgs.llama-cpp}/bin/llama-server "$out/lib/mozkey-ibg/llama-server"
    '';
    meta = {
      description = "Pinned Mozkey IbG release payload for a private FHS runtime";
      homepage = "https://github.com/kazormia296/mozkey-ibg";
      license = with pkgs.lib.licenses; [ asl20 bsd3 lgpl21Plus mit ];
      platforms = [ "x86_64-linux" ];
    };
  };
  launcher = pkgs.writeShellScript "mozkey-fcitx5-entry" ''
    export FCITX_ADDON_DIRS="/usr/lib/fcitx5"
    export XDG_DATA_DIRS="/usr/share:''${XDG_DATA_DIRS:-}"
    if [[ "''${1:-}" == --check-model ]]; then
      exec ${pkgs.llama-cpp}/bin/llama-cli -m /usr/lib/mozkey-ibg/models/zenz-v3.2-small-Q5_K_M.gguf -ngl 0 -t 2 -c 256 -n 1 -p test --no-warmup --no-display-prompt
    fi
    if [[ "''${1:-}" == --check-runtime ]]; then
      set -e
      ${pkgs.python3}/bin/python3 - <<'PY'
import ctypes
from pathlib import Path
ctypes.CDLL('/usr/lib/fcitx5/fcitx5-mozkey-ibg.so')
for path in ['/usr/lib/mozkey-ibg/mozc_server', '/usr/lib/mozkey-ibg/mozc_tool', '/usr/lib/mozkey-ibg/mozc_zenz_scorer', '/usr/lib/mozkey-ibg/models/zenz-v3.2-small-Q5_K_M.gguf', '/usr/share/fcitx5/inputmethod/mozkey-ibg.conf']:
    assert Path(path).is_file(), path
for path in ['/usr/lib/mozkey-ibg/mozc_server', '/usr/lib/mozkey-ibg/mozc_zenz_scorer', '/usr/lib/mozkey-ibg/models/zenz-v3.2-small-Q5_K_M.gguf']:
    assert not Path(path).is_symlink(), path
print('Mozkey addon loaded; regular private server, scorer and model paths exist.')
PY
      /usr/lib/mozkey-ibg/llama-server --version
      exec ${pkgs.fcitx5}/bin/fcitx5 --version
    fi
    exec ${pkgs.fcitx5}/bin/fcitx5 "$@"
  '';
  fhs = pkgs.buildFHSEnv {
  name = "mozkey-fcitx5";
  targetPkgs = p: [
    payload p.fcitx5 p.fcitx5-gtk p.qt6.qtbase p.qt6.qtwayland
    p.glibc p.stdenv.cc.cc.lib p.llama-cpp p.python3 p.coreutils
    p.xdg-utils p.fontconfig p.dbus
  ];
  # Mozc compares /proc/<server-pid>/exe with its embedded /usr/lib path.
  # buildFHSEnv normally aliases /usr/lib to /usr/lib64; make /usr/lib the
  # canonical directory instead, preserving the upstream server identity check.
  # Server/scorer/model files must also be regular files, not store symlinks.
  extraBuildCommands = ''
    rm "$out/usr/lib"
    mv "$out/usr/lib64" "$out/usr/lib"
    ln -s /usr/lib "$out/usr/lib64"
    chmod -R u+w "$out/usr/lib/mozkey-ibg"
    rm -r "$out/usr/lib/mozkey-ibg"
    cp -rL ${payload}/lib/mozkey-ibg "$out/usr/lib/mozkey-ibg"
  '';
  runScript = launcher;
  passthru = { inherit payload; };
  meta.description = "Mozkey IbG with Fcitx5 in a private /usr-compatible environment";
};
in pkgs.symlinkJoin {
  name = "mozkey-fcitx5-0.10.4";
  paths = [ fhs pkgs.fcitx5-gtk pkgs.qt6Packages.fcitx5-qt ];
  postBuild = ''
    ln -s "$out/bin/mozkey-fcitx5" "$out/bin/fcitx5"
  '';
  passthru = { inherit payload fhs; };
}

{ pkgs }:
let
  libraries = with pkgs; [
    stdenv.cc.cc.lib alsa-lib at-spi2-core cairo cups dbus expat
    gdk-pixbuf glib gtk3 libdrm libglvnd libnotify libusb1 libxkbcommon mesa
    nspr nss openssl pango systemd tpm2-tss vulkan-loader wayland
    libx11 libxcb libxcomposite libxdamage libxext
    libxfixes libxrandr
  ];
  # Separate bundled helpers require both Qt ABIs at runtime. Do not put Qt
  # development outputs in buildInputs: their setup hooks reject mixed majors.
  qtRuntime = map pkgs.lib.getLib [ pkgs.qt5.qtbase pkgs.qt6.qtbase ];
  runtimeLibraries = libraries ++ qtRuntime;
in pkgs.stdenvNoCC.mkDerivation rec {
  pname = "chatgpt";
  version = "26.1103.32239";
  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    sha256 = "18c108808ea2c52fb8dbf92d3362d27741e3382c5891bd4ae903a9b5781364ef";
  };
  nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook makeWrapper wrapGAppsHook3 ];
  buildInputs = libraries;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin" "$out/share"
    cp -a usr/lib/chatgpt "$out/lib/chatgpt"
    # This pinned deb ships its icon in the app resources, not share/icons.
    install -Dm644 usr/lib/chatgpt/resources/icon-chatgpt.png \
      "$out/share/pixmaps/chatgpt.png"
    # These optional HID builds target musl, whereas NixOS uses glibc.
    find "$out/lib/chatgpt/resources" -type d -name '*-linux-x64-musl' -prune -exec rm -rf {} +
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils pkgs.git pkgs.coreutils pkgs.bash ]} \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibraries}
    mkdir -p "$out/share/applications"
    cp usr/share/applications/chatgpt.desktop "$out/share/applications/"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U"
    runHook postInstall
  '';
  preFixup = ''
    ${pkgs.lib.concatMapStringsSep "\n" (qt: ''addAutoPatchelfSearchPath "${qt}/lib"'') qtRuntime}
    addAutoPatchelfSearchPath "$out/lib/chatgpt"
    addAutoPatchelfSearchPath "$out/lib/chatgpt/resources/cua_node/lib/node_modules/@img/sharp-libvips-linux-x64/lib"
  '';
  meta = {
    description = "Official ChatGPT desktop app for Linux";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}

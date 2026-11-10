{ pkgs }:
let
  core = import ./herdr-core.nix { inherit pkgs; };
  assets = {
    x86_64-linux = { target = "linux-x86_64"; hash = "77b0be72a46ca14bb367365a04164641f914b3a69712bac391d39c56a959bef4"; };
    aarch64-linux = { target = "linux-aarch64"; hash = "2e5bb05c47cffbad018ad34217ea4c816476d7eb842692f740798c9020f0281e"; };
  };
  asset = assets.${pkgs.stdenv.hostPlatform.system};
  libraries = with pkgs; [
    stdenv.cc.cc.lib libxkbcommon wayland vulkan-loader fontconfig freetype libglvnd
    libxcb libx11 libxcursor libxi libxrandr
  ];
in pkgs.stdenvNoCC.mkDerivation rec {
  pname = "herdr-app";
  version = "0.1.13";
  src = pkgs.fetchurl {
    url = "https://releases.herdr.dev/app/${version}/herdr-app-${asset.target}.tar.gz";
    sha256 = asset.hash;
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
  buildInputs = libraries;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app "$out/libexec/herdr-app/herdr-app"
    # v0.1.13 identifies a self-updatable release by an SVG beside its binary.
    # Keep the icon in the standard icon directory: Nix owns all upgrades.
    install -Dm644 herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
    install -Dm644 LICENSE "$out/share/licenses/herdr-app/LICENSE"
    install -Dm644 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-app/THIRD-PARTY-NOTICES"
    mkdir -p "$out/bin"
    makeWrapper "$out/libexec/herdr-app/herdr-app" "$out/bin/herdr-app" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ core pkgs.xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath libraries}
    runHook postInstall
  '';
  passthru = { inherit core; };
  meta = {
    description = "Herdr desktop application for terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = pkgs.lib.licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "herdr-app";
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}

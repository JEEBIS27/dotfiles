{ pkgs }:
let
  assets = {
    x86_64-linux = { target = "linux-x86_64"; hash = "5b2f97cb4b2a9d7a6b2cc5942628203ed9fbb7cc0c2b4b09ad8a6f5648e246b7"; };
    aarch64-linux = { target = "linux-aarch64"; hash = "cf33393cf950bb763734dc3e16610ab9daf8492391a4ef0de56026cd7f752853"; };
  };
  asset = assets.${pkgs.stdenv.hostPlatform.system};
in pkgs.stdenvNoCC.mkDerivation rec {
  pname = "herdr-core";
  version = "0.1.18";
  src = pkgs.fetchurl {
    url = "https://releases.herdr.dev/core/${version}/herdr-core-${asset.target}.tar.gz";
    sha256 = asset.hash;
  };
  sourceRoot = ".";
  # Upstream Linux core releases are static musl executables.
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-core "$out/bin/herdr-core"
    ln -s herdr-core "$out/bin/hc"
    install -Dm644 LICENSE "$out/share/licenses/herdr-core/LICENSE"
    install -Dm644 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-core/THIRD-PARTY-NOTICES"
    runHook postInstall
  '';
  meta = {
    description = "Persistent terminal runtime for Herdr App";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = pkgs.lib.licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "herdr-core";
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}

{ pkgs }:
# Retain nixpkgs' runtime integration, but avoid the unreachable Snap API.
# Spotify only retains recent Debian releases: update URL/version/hash together.
(import ./gtk-ime.nix { inherit pkgs; package = pkgs.spotify; }).overrideAttrs (old: {
  version = "1.3.4.258.gc60b10b0946a";
  src = pkgs.fetchurl {
    url = "https://repository.spotify.com/pool/non-free/s/spotify-client/spotify-client_1.3.4.258.gc60b10b0946a_amd64.deb";
    sha256 = "20f327441d11b202c82e65b69ec990ef631eb66605da15f41076c049acb718e4";
  };
  nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.dpkg ];
  unpackPhase = ''
    runHook preUnpack
    mkdir source
    dpkg-deb --extract "$src" source
    cd source
    runHook postUnpack
  '';
})

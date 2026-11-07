# Public upstream source, pinned for reproducible builds.
{ ... }:
(builtins.fetchTree {
  type = "github";
  owner = "JEEBIS27";
  repo = "fish-eza-path-colors";
  rev = "678c8f1e7046cfadb8881b834a002a4ade74e475";
  narHash = "sha256-gvpekmK+32LzJzCCfa8FvNFuEkbM0IWLx1oNOyUc/V4=";
}).outPath

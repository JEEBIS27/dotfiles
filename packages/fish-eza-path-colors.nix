{ pkgs }:
let
  source = import ./fish-eza-path-colors-source.nix { inherit pkgs; };
in import source { inherit pkgs; }

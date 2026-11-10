{ lib, pkgs, appPkgs, mejiroSource, ... }:
let
  # Keep Fcitx linked against system pkgs, and reuse the explicitly platformed
  # neural package pin. Upstream pinned-pkgs.nix imports nixpkgs with {}, which
  # depends on builtins.currentSystem and fails during pure flake evaluation.
  package = pkgs.callPackage (mejiroSource + "/nix/package.nix") {
    neuralPkgs = appPkgs;
  };
  model = pkgs.fetchurl {
    url = "https://huggingface.co/Miwa-Keita/zenz-v3.1-small-gguf/resolve/ddf6e44b2e05ab7ea9a3e31559c5e7948761365c/ggml-model-Q5_K_M.gguf";
    sha256 = "4de930c06bef8c263aa1aa40684af206db4ce1b96375b3b8ed0ea508e0b14f6c";
  };
in {
  services.mejiroime = {
    enable = true;
    inherit package;
    manageFcitx5 = true;
    neural = {
      modelPath = "${model}";
      # Keep neural conversion enabled without requiring working Vulkan.
      workerPackage = lib.mkDefault package.zenzWorker;
      gpu = lib.mkDefault "off";
    };
  };
  i18n.inputMethod.fcitx5.waylandFrontend = true;
  home-manager.users.jeebis.xdg.dataFile."fcitx5/addon/classicui.conf".source =
    "${package}/share/mejiroime/fcitx5/classicui.conf";
}

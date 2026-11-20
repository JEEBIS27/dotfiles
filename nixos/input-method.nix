{
  config,
  lib,
  pkgs,
  appPkgs,
  mejiroSource,
  mejiroEngineSource,
  ...
}:
let
  # Keep the standard Fcitx daemon and MejiroIME addons on the same app pin.
  package = appPkgs.callPackage (mejiroSource + "/nix/package.nix") {
    neuralPkgs = appPkgs;
    engineSource = mejiroEngineSource;
  };
  model = pkgs.fetchurl {
    url = "https://huggingface.co/Miwa-Keita/zenz-v3.1-small-gguf/resolve/ddf6e44b2e05ab7ea9a3e31559c5e7948761365c/ggml-model-Q5_K_M.gguf";
    sha256 = "4de930c06bef8c263aa1aa40684af206db4ce1b96375b3b8ed0ea508e0b14f6c";
  };
in
{
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
  i18n.inputMethod.package = lib.mkForce (
    appPkgs.qt6Packages.fcitx5-with-addons.override {
      addons = config.i18n.inputMethod.fcitx5.addons;
    }
  );
  i18n.inputMethod.fcitx5.waylandFrontend = true;
}

{ config, lib, pkgs, appPkgs, mejiroSource, ... }:
let
  # The upstream candidate renderer targets Fcitx 5.1.23. Keep the daemon,
  # classic UI, addon and neural worker on the same explicit app package pin.
  # Never mix the NixOS base Fcitx 5.1.19 with this patched UI.
  package = appPkgs.callPackage (mejiroSource + "/nix/package.nix") {
    neuralPkgs = appPkgs;
  };
  gtkModule = import (mejiroSource + "/nix/fcitx-gtk-inline-colors.nix") { pkgs = appPkgs; };
  model = pkgs.fetchurl {
    url = "https://huggingface.co/Miwa-Keita/zenz-v3.1-small-gguf/resolve/ddf6e44b2e05ab7ea9a3e31559c5e7948761365c/ggml-model-Q5_K_M.gguf";
    sha256 = "4de930c06bef8c263aa1aa40684af206db4ce1b96375b3b8ed0ea508e0b14f6c";
  };
in {
  # The published MejiroIME pin predates HID access rules. Keep access tied
  # to the active local session; 70 sorts before systemd's seat-late rules.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-mejiroime-hid.rules" ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2784", ATTRS{idProduct}=="0001", TAG+="uaccess"
    '')
  ];
  services.mejiroime = {
    enable = true;
    inherit package;
    manageFcitx5 = true;
    enableGtkInlineColors = true;
    neural = {
      modelPath = "${model}";
      # Keep neural conversion enabled without requiring working Vulkan.
      workerPackage = lib.mkDefault package.zenzWorker;
      gpu = lib.mkDefault "off";
    };
  };
  i18n.inputMethod.package = lib.mkForce (appPkgs.qt6Packages.fcitx5-with-addons.override {
    addons = config.i18n.inputMethod.fcitx5.addons;
    fcitx5-gtk = gtkModule;
  });
  i18n.inputMethod.fcitx5.waylandFrontend = true;
  environment.sessionVariables.GIO_EXTRA_MODULES = "${gtkModule}/lib/gtk-4.0/4.0.0/immodules";
  home-manager.users.jeebis.home.sessionVariables.GIO_EXTRA_MODULES =
    config.environment.sessionVariables.GIO_EXTRA_MODULES;
  home-manager.users.jeebis.xdg.dataFile."fcitx5/addon/classicui.conf".source =
    "${package}/share/mejiroime/fcitx5/classicui.conf";
}

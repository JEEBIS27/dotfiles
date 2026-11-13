# Chromium/Electron apps that support the GTK4 input method backend.
{ pkgs, package, executable ? package.meta.mainProgram }:
package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
  buildInputs = (old.buildInputs or []) ++ [ pkgs.gtk4 ];
  postFixup = (old.postFixup or "") + ''
    # The inner nixpkgs wrapper adds native Wayland IME flags when this is set.
    wrapProgram "$out/bin/${executable}" \
      --unset NIXOS_OZONE_WL \
      --set GTK_IM_MODULE fcitx \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.gtk4 ]} \
      --add-flags "--ozone-platform=wayland --gtk-version=4 ${pkgs.lib.optionalString ((old.pname or "") == "slack") "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"}"
  '';
})

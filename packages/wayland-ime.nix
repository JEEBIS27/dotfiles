# Chromium/Electron apps using the compositor's native Wayland text-input-v3.
{ pkgs, package, executable ? package.meta.mainProgram }:
package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
  postFixup = (old.postFixup or "") + ''
    # Keep the protocol choice deterministic instead of relying on the inner
    # nixpkgs wrapper's NIXOS_OZONE_WL handling.
    wrapProgram "$out/bin/${executable}" \
      --unset NIXOS_OZONE_WL \
      --unset GTK_IM_MODULE \
      --add-flags "--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3 ${pkgs.lib.optionalString ((old.pname or "") == "slack") "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"}"
  '';
})

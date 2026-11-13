{ lib, ... }: {
  # Hardware-specific greeter settings are opt-in. Never guess device IDs.
  options.jeebis.machine.greeterRotation = lib.mkOption {
    type = lib.types.submodule {
      options.automatic = lib.mkOption { type = lib.types.bool; default = false; };
      options.touchDevices = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    };
    default = { };
    description = "Hyprland recovery greeter rotation; not used by the Weston Niri greeter.";
  };
}

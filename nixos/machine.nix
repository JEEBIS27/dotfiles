{ lib, ... }: {
  # Sensor discovery is generic; machine-specific device names remain optional.
  options.jeebis.machine.greeterRotation = lib.mkOption {
    type = lib.types.submodule {
      options.automatic = lib.mkOption { type = lib.types.bool; default = true; };
      options.touchDevices = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    };
    default = { };
    description = "Automatic rotation for the isolated Hyprland SDDM greeter.";
  };
}

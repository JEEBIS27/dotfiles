{ config, lib, ... }:
let
  cfg = config.jeebis.machine;
  inherit (lib) mkOption types optionalString;
  quote = builtins.toJSON;
  outputType = types.submodule {
    options = {
      mode = mkOption { type = types.nullOr types.str; default = null; };
      scale = mkOption { type = types.nullOr (types.addCheck (types.either types.int types.float) (value: value > 0)); default = null; };
      position = mkOption {
        type = types.nullOr (types.submodule {
          options.x = mkOption { type = types.int; };
          options.y = mkOption { type = types.int; };
        });
        default = null;
      };
      transform = mkOption { type = types.enum [ "normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270" ]; default = "normal"; };
    };
  };
  outputs = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: output: ''
    output ${quote name} {
      ${optionalString (output.mode != null) "mode ${quote output.mode}"}
      ${optionalString (output.scale != null) "scale ${toString output.scale}"}
      ${optionalString (output.position != null) "position x=${toString output.position.x} y=${toString output.position.y}"}
      transform ${quote output.transform}
    }
  '') cfg.outputs);
in {
  options.jeebis.machine = {
    outputs = mkOption { type = types.attrsOf outputType; default = { }; description = "This PC's display modes, scaling, placement and static rotation."; };
    keyboard.layout = mkOption { type = types.str; default = "jp"; };
    keyboard.model = mkOption { type = types.str; default = "jp106"; };
    touchpad.tap = mkOption { type = types.bool; default = true; };
    touchpad.naturalScroll = mkOption { type = types.bool; default = true; };
    touchOutput = mkOption { type = types.nullOr types.str; default = null; };
    niriConfiguration = mkOption {
      type = types.lines;
      readOnly = true;
      default = ''
        ${outputs}
        input {
          focus-follows-mouse
          keyboard { xkb { layout ${quote cfg.keyboard.layout}; model ${quote cfg.keyboard.model}; }; }
          mouse { accel-speed -0.2; }
          touchpad {
            ${optionalString cfg.touchpad.tap "tap"}
            ${optionalString cfg.touchpad.naturalScroll "natural-scroll"}
          }
          ${optionalString (cfg.touchOutput != null) "touch { map-to-output ${quote cfg.touchOutput}; }"}
        }
      '';
    };
  };
}

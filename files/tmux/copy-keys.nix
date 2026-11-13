{ lib }:
let
  letters = import ../../packages/key-layout.nix {
    inherit lib;
    inherit (import ../helix/key-layout.nix) directionKeys;
  };
  # Only unmodified command keys are translated; searches and jump targets
  # remain literal, just as in Helix, Yazi and TUIOS's copy mode.
  commands = {
    h = "cursor-left"; j = "cursor-down"; k = "cursor-up"; l = "cursor-right";
    H = "top-line"; J = "scroll-down"; K = "scroll-up"; L = "bottom-line";
    w = "next-word"; b = "previous-word"; e = "next-word-end";
    W = "next-space"; B = "previous-space"; E = "next-space-end";
    o = "other-end"; A = "append-selection-and-cancel";
  };
  actual = key: letters.${key} or key;
in lib.concatStringsSep "\n" (
  map (key: "unbind -T copy-mode-vi ${key}") (builtins.attrNames commands)
  ++ lib.mapAttrsToList (key: command:
    "bind -T copy-mode-vi ${actual key} send-keys -X ${command}") commands
) + ''
  bind -T copy-mode-vi v send-keys -X begin-selection
  bind -T copy-mode-vi V send-keys -X select-line
  bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
''

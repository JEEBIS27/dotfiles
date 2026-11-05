{
  lib,
  settings,
  directionKeys ? "hjkl",
}:
let
  letters = import ../key-layout.nix { inherit lib directionKeys; };
  rename =
    key:
    let
      parts = lib.splitString "-" key;
      name = lib.last parts;
      modifiers = lib.init parts;
      shiftOnly = builtins.all (modifier: modifier == "S") modifiers;
    in
    if shiftOnly && builtins.hasAttr name letters then
      lib.concatStringsSep "-" (modifiers ++ [ letters.${name} ])
    else
      key;
  isMotion = command:
    builtins.isString command && (
      builtins.any (prefix: lib.hasPrefix prefix command)
        [ "move_" "extend_" "goto_" "find_" ":jeebis-word-" ":jeebis-WORD-" ":jeebis-smooth-" ]
      || builtins.elem command [ "search_next" "search_prev" "match_brackets" ]
      || lib.hasPrefix ":jeebis-target " command
    );
  motionGuard = value:
    if isMotion value then [ ":jeebis-before-motion" value ]
    else if builtins.isList value then lib.concatMap (command:
      if isMotion command then [ ":jeebis-before-motion" command ] else [ command ]) value
    else value;
  transform =
    node:
    lib.mapAttrs' (
      key: value:
      lib.nameValuePair (rename key) (if builtins.isAttrs value then transform value else motionGuard value)
    ) node;
in

settings
// {
  keys = lib.mapAttrs (_mode: transform) (settings.keys or { });
}

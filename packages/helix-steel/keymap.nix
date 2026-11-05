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
  transform =
    node:
    lib.mapAttrs' (
      key: value:
      lib.nameValuePair (rename key) (if builtins.isAttrs value then transform value else value)
    ) node;
in

settings
// {
  keys = lib.mapAttrs (_mode: transform) (settings.keys or { });
}

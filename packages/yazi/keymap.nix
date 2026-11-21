{
  lib,
  settings,
  directionKeys ? "hjkl",
  modifiedDirectionKeys ? "hjkl",
}:
let
  letters = import ../key-layout.nix { inherit lib directionKeys; };
  modified = import ../key-layout.nix {
    inherit lib;
    directionKeys = modifiedDirectionKeys;
  };
  rename =
    layer: key:
    if builtins.hasAttr key letters then
      letters.${key}
    else if lib.hasPrefix "<" key && lib.hasSuffix ">" key then
      let
        parts = lib.splitString "-" (lib.removeSuffix ">" (lib.removePrefix "<" key));
        name = lib.last parts;
        layout =
          if builtins.all (x: x == "S") (lib.init parts) then
            letters
          else if
            builtins.elem layer [
              "mgr"
              "cmp"
            ]
          then
            modified
          else
            { };
      in
      if builtins.hasAttr name layout then
        "<${lib.concatStringsSep "-" ((lib.init parts) ++ [ layout.${name} ])}>"
      else
        key
    else
      key;
  countArgs = " --down=${letters.j} --up=${letters.k} --next=${letters.w or "w"} --previous=${letters.e or "e"}";
  run =
    command:
    if builtins.isString command && lib.hasPrefix "plugin unified-motions " command then
      command + countArgs
    else
      command;
  binding =
    layer: b:
    b
    // {
      on = if builtins.isList b.on then map (rename layer) b.on else rename layer b.on;
      run = if builtins.isList b.run then map run b.run else run b.run;
    };
in
lib.mapAttrs (
  layerName: layer:
  lib.mapAttrs (
    name: value:
    if
      builtins.elem name [
        "keymap"
        "prepend_keymap"
        "append_keymap"
      ]
    then
      map (binding layerName) value
    else
      value
  ) layer
) settings

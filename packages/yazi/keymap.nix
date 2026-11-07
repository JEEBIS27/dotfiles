{
  lib,
  settings,
  directionKeys ? "hjkl",
}:
let
  letters = import ../key-layout.nix { inherit lib directionKeys; };
  rename =
    key:
    if builtins.hasAttr key letters then
      letters.${key}
    else if lib.hasPrefix "<" key && lib.hasSuffix ">" key then
      let
        parts = lib.splitString "-" (lib.removeSuffix ">" (lib.removePrefix "<" key));
        name = lib.last parts;
      in
      if builtins.all (x: x == "S") (lib.init parts) && builtins.hasAttr name letters then
        "<${lib.concatStringsSep "-" ((lib.init parts) ++ [ letters.${name} ])}>"
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
    b:
    b
    // {
      on = if builtins.isList b.on then map rename b.on else rename b.on;
      run = if builtins.isList b.run then map run b.run else run b.run;
    };
in
lib.mapAttrs (
  _: layer:
  lib.mapAttrs (
    name: value:
    if
      builtins.elem name [
        "keymap"
        "prepend_keymap"
        "append_keymap"
      ]
    then
      map binding value
    else
      value
  ) layer
) settings

{
  lib,
  settings,
  directionKeys ? "hjkl",
}:
let
  logical = lib.stringToCharacters "hjkl";
  actual = lib.stringToCharacters directionKeys;
  valid = builtins.match "[a-z]{4}" directionKeys != null && builtins.length (lib.unique actual) == 4;
  direct = builtins.listToAttrs (
    lib.imap0 (i: key: {
      name = key;
      value = builtins.elemAt actual i;
    }) logical
  );
  inverse = builtins.listToAttrs (
    lib.imap0 (i: key: {
      name = key;
      value = builtins.elemAt logical i;
    }) actual
  );
  # Complete the partial mapping into a permutation, keeping displaced actions.
  # haoe produces j<->a, k<->o, l<->e. Cyclic layouts also remain bijective.
  displaced = builtins.filter (key: !(builtins.elem key logical)) actual;
  origin =
    key:
    let
      previous = inverse.${key};
    in
    if builtins.hasAttr previous inverse then origin previous else previous;
  lower =
    direct
    // builtins.listToAttrs (
      map (key: {
        name = key;
        value = origin key;
      }) displaced
    );
  letters =
    lower // lib.mapAttrs' (key: value: lib.nameValuePair (lib.toUpper key) (lib.toUpper value)) lower;
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
assert lib.assertMsg valid
  "Helix directionKeys must contain four distinct lowercase ASCII letters (left/down/up/right).";
settings
// {
  keys = lib.mapAttrs (_mode: transform) (settings.keys or { });
}

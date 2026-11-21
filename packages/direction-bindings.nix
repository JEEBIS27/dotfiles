{
  lib,
  layout ? import ../files/helix/key-layout.nix,
}:
let
  mapping = directionKeys: import ./key-layout.nix { inherit lib directionKeys; };
  plain = mapping layout.directionKeys;
  modified = mapping layout.modifiedDirectionKeys;
  # Mark only key tokens. Commands, literal input and unrelated shortcuts stay literal.
  tokens =
    kind: letters:
    lib.mapAttrs' (key: value: lib.nameValuePair "@${kind}:${key}@" value) (
      lib.genAttrs (lib.stringToCharacters "hjkliHJKLI") (key: letters.${key} or key)
    );
  replacements = (tokens "plain" plain) // (tokens "mod" modified);
in
{
  inherit plain modified;
  render = builtins.replaceStrings (builtins.attrNames replacements) (
    builtins.attrValues replacements
  );
}

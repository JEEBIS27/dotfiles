{ lib }:
let
  source = builtins.fromTOML (builtins.readFile ../files/helix/config.toml);
  render =
    settings: directionKeys:
    import ../packages/helix-steel/keymap.nix { inherit lib settings directionKeys; };
  rendered = render source (import ../files/helix/key-layout.nix).directionKeys;
  fixture.editor.cursorline = true;
  fixture.keys.normal = {
    h = "left";
    z = [
      ":echo aejkl"
      "@aejkl"
    ];
    j = "down";
    k = "up";
    l = "right";
    a = "append";
    o = "open";
    e = "end";
    J = "extend-down";
    "S-j" = "shift-down";
    "C-j" = "view-down";
    "C-S-j" = "shift-view-down";
    "A-j" = "alt-down";
    "Meta-j" = "meta-down";
    "C-e" = {
      j = "swap-down";
      "C-j" = "modified-swap-down";
    };
  };
  mapped = (render fixture "haoe").keys.normal;
in
assert
  mapped.a == "down"
  && mapped.j == "append"
  && mapped.o == "up"
  && mapped.k == "open"
  && mapped.e == "right"
  && mapped.l == "end";
assert (render fixture "haoe").editor == fixture.editor;
assert mapped.z == fixture.keys.normal.z;
assert rendered.keys.normal.j == source.keys.normal.a && rendered.keys.normal.k == "open_below";
assert rendered.keys.normal.l == ":jeebis-word-prev";
assert mapped.A == "extend-down" && mapped."S-a" == "shift-down";
assert
  mapped."C-j" == "view-down"
  && mapped."C-S-j" == "shift-view-down"
  && mapped."A-j" == "alt-down"
  && mapped."Meta-j" == "meta-down";
assert mapped."C-e".a == "swap-down" && mapped."C-e"."C-j" == "modified-swap-down";
assert (render fixture "hjkl") == fixture;
assert (render fixture "jklh").keys.normal.j == "left";
assert
  (render fixture "jaoe").keys.normal.a == "down"
  && (render fixture "jaoe").keys.normal.h == "append";
assert rendered.keys.normal.space == "command_mode";
assert
  rendered.keys.normal.a == "move_visual_line_down"
  && rendered.keys.normal.o == "move_visual_line_up"
  && rendered.keys.normal.e == "move_char_right";
assert rendered.keys.normal."C-j" == "jump_view_down";
true

{ lib }:
let
  source = builtins.fromTOML (builtins.readFile ../files/helix/config.toml);
  render =
    settings: directionKeys: modifiedDirectionKeys:
    import ../packages/helix-steel/keymap.nix {
      inherit
        lib
        settings
        directionKeys
        modifiedDirectionKeys
        ;
    };
  layout = import ../files/helix/key-layout.nix;
  rendered = render source layout.directionKeys layout.modifiedDirectionKeys;
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
    i = "insert";
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
  mapped = (render fixture "haoe" "jkil").keys.normal;
in
assert
  mapped.a == "down"
  && mapped.j == "append"
  && mapped.o == "up"
  && mapped.k == "open"
  && mapped.e == "right"
  && mapped.l == "end";
assert (render fixture "haoe" "jkil").editor == fixture.editor;
assert mapped.z == fixture.keys.normal.z;
assert
  rendered.keys.normal.j == source.keys.normal.a && rendered.keys.normal.k == source.keys.normal.o;
assert
  rendered.keys.normal.l == [
    ":jeebis-before-motion"
    ":jeebis-word-prev"
  ];
assert mapped.A == "extend-down" && mapped."S-a" == "shift-down";
assert
  mapped."C-k" == "view-down"
  && mapped."C-S-k" == "shift-view-down"
  && mapped."A-k" == "alt-down"
  && mapped."Meta-k" == "meta-down";
assert mapped."C-e".a == "swap-down" && mapped."C-e"."C-k" == "modified-swap-down";
assert (render fixture "hjkl" "hjkl") == fixture;
assert (render fixture "jklh" "hjkl").keys.normal.j == "left";
assert
  (render fixture "jaoe" "hjkl").keys.normal.a == "down"
  && (render fixture "jaoe" "hjkl").keys.normal.h == "append";
assert rendered.keys.normal.space == "command_mode";
assert rendered.keys.normal."A-i" == "no_op" && !(rendered.keys.normal ? "A-h");
assert
  rendered.keys.normal.a == [
    ":jeebis-before-motion"
    "move_visual_line_down"
  ]
  &&
    rendered.keys.normal.o == [
      ":jeebis-before-motion"
      "move_visual_line_up"
    ]
  &&
    rendered.keys.normal.e == [
      ":jeebis-before-motion"
      "move_char_right"
    ];
assert
  rendered.keys.normal."C-k" == ":jeebis-view-down" && rendered.keys.normal."C-i" == ":jeebis-view-up";
assert (render fixture "jkil" "jkil").keys.normal.h == "insert";
assert (render fixture "jkil" "hjkl").keys.normal.i == "up";
true

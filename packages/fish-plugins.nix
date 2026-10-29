# Latest upstream revisions checked on 2026-10-27; pinned for reproducible builds.
{ pkgs }:
let
  sources = builtins.fromJSON (builtins.readFile ./fish-plugin-sources.json);
  prepare = spec: let
    src = pkgs.fetchFromGitHub { inherit (spec) owner repo rev hash; };
  in {
    inherit (spec) name;
    src = pkgs.runCommand "fish-plugin-${spec.name}" { nativeBuildInputs = [ pkgs.bash ]; } (''
      cp -R ${src} $out
      chmod -R u+w $out
    '' + pkgs.lib.optionalString (spec.name == "forgit") ''
      # Upstream's Fisher layout expects bin under conf.d.
      ln -s ../bin $out/conf.d/bin
    '' + pkgs.lib.optionalString (spec.name == "fzf-help") ''
      echo "source $out/src/fzf-help.fish" > $out/init.fish
    '' + pkgs.lib.optionalString (spec.name == "autopair.fish") ''
      # Keep autopair's quote handling, delegate completion to fifc.
      substituteInPlace $out/functions/_autopair_tab.fish \
        --replace-fail 'commandline --function complete' '_fifc'
    '' + pkgs.lib.optionalString (spec.name == "fish-abbreviation-tips") ''
      # Preserve abbreviation tracking before magic-enter executes the line.
      substituteInPlace $out/functions/__abbr_tips_bind_newline.fish \
        --replace-fail 'commandline -f execute' 'magic-enter'
    '' + ''
      patchShebangs $out
    '');
  };
in map prepare sources

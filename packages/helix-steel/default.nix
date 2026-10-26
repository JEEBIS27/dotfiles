{ pkgs }:
let
  pins = builtins.fromJSON (builtins.readFile ./sources.json);
  sources = builtins.mapAttrs (_: pin: pkgs.fetchFromGitHub pin) pins;
  grammars = pkgs.callPackage (sources.helix + "/grammars.nix") {
    # GCC 16 defaults to C23; this scanner defines its own bsearch and needs
    # the pre-C23 libc declarations. No Helix source modification is needed.
    grammarOverlays = [ (_: previous: {
      perl = previous.perl.overrideAttrs (old: {
        FLAGS = old.FLAGS ++ [ "-std=gnu17" ];
      });
    }) ];
  };
  runtime = pkgs.runCommand "helix-steel-runtime" { } ''
    mkdir -p $out
    cp -r ${sources.helix}/runtime/. $out/
    chmod -R u+w $out
    rm -rf $out/grammars
    ln -s ${grammars} $out/grammars
  '';
  baseEditor = pkgs.rustPlatform.buildRustPackage {
    pname = "helix-steel";
    version = "25.07.1-steel-${builtins.substring 0 8 pins.helix.rev}";
    src = sources.helix;
    cargoLock = { lockFile = sources.helix + "/Cargo.lock"; allowBuiltinFetchGit = true; };
    cargoBuildFlags = [ "--package" "helix-term" ];
    buildFeatures = [ "steel" ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";
    HELIX_NIX_BUILD_REV = pins.helix.rev;
    doCheck = false;
    postInstall = ''
      mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
      cp contrib/Helix.desktop $out/share/applications/
      cp contrib/helix.png $out/share/icons/hicolor/256x256/apps/
    '';
    meta.mainProgram = "hx";
  };
  editor = pkgs.symlinkJoin {
    name = "helix-steel-configured";
    paths = [ baseEditor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hx \
        --set HELIX_RUNTIME ${runtime} \
        --run 'export HELIX_STEEL_CONFIG="''${HELIX_STEEL_CONFIG:-''${XDG_CONFIG_HOME:-$HOME/.config}/helix}"; export STEEL_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/jeebis-helix-steel"; mkdir -p "$STEEL_HOME/cached-modules"; export HELIX_YAZI_EDITOR_PID="$$"; export HELIX_YAZI_FILE="''${XDG_RUNTIME_DIR:-$STEEL_HOME}/helix-yazi-$$"'
    '';
    meta.mainProgram = "hx";
  };
  plugins = pkgs.runCommand "helix-steel-plugins" { } ''
    mkdir -p $out
    cp -r ${sources.flash} $out/flash
    cp -r ${sources.pty} $out/steel-pty
    mkdir $out/recentf
    cp ${sources.recentf}/cogs/recentf.scm $out/recentf/
    cp -r ${sources.microscope} $out/microscope
    cp -r ${sources.matte} $out/matte.hx
    cp -r ${sources.notify} $out/notify
    cp -r ${sources.moka} $out/moka
    cp -r ${sources.glyph} $out/glyph
    mkdir $out/yazi
    cp ${../../files/helix/steel/yazi.scm} $out/yazi/yazi.scm
    chmod -R u+w $out
    substituteInPlace $out/recentf/recentf.scm \
      --replace-fail '(define RECENTF-FILE ".helix/recent-files.txt")' \
        '(define RECENTF-FILE (string-append (env-var "STEEL_HOME") "/recent-files.txt"))' \
      --replace-fail '(unless (path-exists? ".helix")' '(unless (path-exists? (env-var "STEEL_HOME"))' \
      --replace-fail '(create-directory! ".helix")' '(create-directory! (env-var "STEEL_HOME"))'
    cat >> $out/recentf/recentf.scm <<'SCM'
    (provide recentf-start!)
    (define (recentf-start!)
      (unless ENABLED
        (set! ENABLED #t)
        (recentf-snapshot)))
    SCM
  '';
  terminal = pkgs.rustPlatform.buildRustPackage {
    pname = "helix-steel-pty";
    version = "0.1.0-${builtins.substring 0 8 pins.pty.rev}";
    src = sources.pty;
    patches = [ ./pty-steel-version.patch ];
    cargoDeps = (pkgs.rustPlatform.importCargoLock {
      lockFile = ./pty-Cargo.lock;
      allowBuiltinFetchGit = true;
    }).overrideAttrs (old: {
      # This dependency uses include_bytes! across workspace crate boundaries.
      # Preserve the sibling name expected by its source; cargo metadata accepts
      # the alias without changing any crate checksums.
      buildCommand = old.buildCommand + ''
        ln -s termwiz-0.24.0 $out/termwiz
      '';
    });
    postPatch = "cp ${./pty-Cargo.lock} Cargo.lock";
    nativeBuildInputs = with pkgs; [ pkg-config cmake python3 perl ];
    buildInputs = with pkgs; [ openssl fontconfig freetype harfbuzz zlib libxkbcommon ];
    doCheck = false;
  };
in { inherit editor baseEditor terminal plugins sources pins; }

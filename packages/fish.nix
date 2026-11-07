{ pkgs, enablePathStyleProvider ? true }:
let
  pathColorsSource = import ./fish-eza-path-colors-source.nix { inherit pkgs; };
  # Content-address the hook files separately: plugin-only updates reuse fish.
  providerPatch = builtins.path {
    path = "${pathColorsSource}/compat/fish-4.9.3/path-style-provider.patch";
    name = "path-style-provider.patch";
  };
  providerAdapter = builtins.path {
    path = "${pathColorsSource}/compat/fish-4.9.3/path-style-provider.rs";
    name = "path-style-provider.rs";
  };
  fish = if enablePathStyleProvider then pkgs.fish.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ providerPatch ];
    postPatch = (old.postPatch or "") + ''
      cp ${providerAdapter} src/highlight/path_style_provider.rs
    '';
  }) else pkgs.fish;
  launcher = pkgs.writeText "fish-launcher.c" ''
    #include <stdio.h>
    #include <termios.h>
    #include <unistd.h>
    int main(int argc, char **argv) {
      (void)argc;
      struct termios mode;
      if (isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &mode) == 0) {
        mode.c_cc[VINTR] = 23; /* Ctrl-W */
        #ifdef VWERASE
        mode.c_cc[VWERASE] = _POSIX_VDISABLE;
        #endif
        (void)tcsetattr(STDIN_FILENO, TCSANOW, &mode);
      }
      /* Preserve argv[0], including -fish for a login shell. */
      execv("${fish}/bin/fish", argv);
      perror("exec fish");
      return 127;
    }
  '';
in pkgs.symlinkJoin {
  name = "fish-${fish.version}";
  pname = "fish";
  inherit (fish) version meta;
  # Preserve the shell interface required by NixOS users and /etc/shells.
  passthru = { inherit (fish) shellPath; };
  paths = [ fish ];
  postBuild = ''
    rm "$out/bin/fish"
    ${pkgs.stdenv.cc}/bin/cc -std=c99 -O2 -Wall -Wextra -Werror ${launcher} -o "$out/bin/fish"
  '';
}

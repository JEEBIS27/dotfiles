{ pkgs }:
let
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
      execv("${pkgs.fish}/bin/fish", argv);
      perror("exec fish");
      return 127;
    }
  '';
in pkgs.symlinkJoin {
  name = "fish-${pkgs.fish.version}";
  pname = "fish";
  inherit (pkgs.fish) version meta;
  paths = [ pkgs.fish ];
  postBuild = ''
    rm "$out/bin/fish"
    ${pkgs.stdenv.cc}/bin/cc -std=c99 -O2 -Wall -Wextra -Werror ${launcher} -o "$out/bin/fish"
  '';
}

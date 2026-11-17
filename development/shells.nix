{ pkgs }:
let
  common = [
    pkgs.pkg-config
    pkgs.gnumake
    pkgs.gcc
  ];
  python = [
    pkgs.python3
    pkgs.uv
  ];
  node = [ pkgs.nodejs ];
  rust = [
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.clippy
  ];
  go = [ pkgs.go ];
  shell =
    packages:
    pkgs.mkShell {
      packages = common ++ packages;
      UV_PYTHON_DOWNLOADS = "never";
      UV_PYTHON_PREFERENCE = "only-system";
    };
in
{
  default = shell (python ++ node ++ rust ++ go);
  python = shell python;
  node = shell node;
  rust = shell rust;
  go = shell go;
}

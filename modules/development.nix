{ appPkgs, ... }:
{
  # Runtime versions are selected by the committed nixpkgs-apps lock.
  home.packages = with appPkgs; [
    python3
    uv
    nodejs
    rustc
    cargo
    rustfmt
    clippy
    go
    mise
  ];

  # uv manages project dependencies; Nix supplies the interpreter.
  home.sessionVariables = {
    UV_PYTHON_DOWNLOADS = "never";
    UV_PYTHON_PREFERENCE = "only-system";
  };

  programs.direnv = {
    enable = true;
    package = appPkgs.direnv;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv = {
      enable = true;
      package = appPkgs.nix-direnv;
    };
    # Explicit project opt-in keeps mise from overriding Nix environments.
    stdlib = ''
      use_mise() {
        watch_file mise.toml mise.lock .mise.toml
        direnv_load ${appPkgs.mise}/bin/mise exec -- ${appPkgs.direnv}/bin/direnv dump
      }
    '';
  };
}

# MATLAB

Build the pinned Linux environment:

```sh
cd ~/Git/home-manager
nix --extra-experimental-features 'nix-command flakes' build "path:$PWD#matlab-nix" --out-link ~/.local/state/matlab-nix
```

Run the downloaded, extracted official installer inside it:

```sh
~/.local/state/matlab-nix/bin/matlab-nix ~/Downloads/install
```

Sign in with a licensed MathWorks account and select `~/MATLAB/R2026b`
(use the absolute home path in the installer). MATLAB binaries, license data,
and account state stay outside Git and the Nix store.

Home Manager supplies `matlab-nix` in `~/.local/bin`. After installation:

```sh
matlab-nix
```

The application list also includes **MATLAB R2026b**, which launches this
wrapper. Its desktop entry uses the installed MATLAB icon and window class,
so the application island can identify the running window. When upgrading
MATLAB, update the release and window class in `modules/apps.nix`.

With no arguments, the launcher selects the last release alphabetically under
`~/MATLAB/R*/bin/matlab`. To select a release or pass MATLAB options, supply its
executable explicitly:

```sh
matlab-nix ~/MATLAB/R2026b/bin/matlab -batch 'disp(version)'
```

The environment uses Nix libraries and X11/XWayland for the Qt interface.
Building the wrapper does not install MATLAB or activate a license. MATLAB is
not rebuilt by Nix, and using this environment does not make it a MathWorks
validated Linux distribution.

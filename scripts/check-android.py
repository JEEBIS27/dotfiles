#!/usr/bin/env python3
"""Evaluate the actual Nix-on-Droid import graph without building ARM packages."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
expr = r'''
let
  f = builtins.getFlake ("path:" + ROOT);
  d = f.nixOnDroidConfigurations.galaxy-tab-s11;
  h = d.config.home-manager.config;
in {
  system = d.pkgs.stdenv.hostPlatform.system;
  home = h.home.homeDirectory;
  username = h.home.username;
  shell = d.config.user.shell;
  packages = map (p: p.pname or p.name) h.home.packages;
  files = builtins.attrNames h.home.file;
  services = builtins.attrNames h.systemd.user.services;
  desktopOptions = h.jeebis ? desktop;
  themeDirectory = h.jeebis.shell.themeDirectory;
  activation = h.home.activationPackage.drvPath;
  editor = h.home.sessionVariables.EDITOR;
  visual = h.home.sessionVariables.VISUAL;
  terminal = h.home.sessionVariables.TERMINAL or null;
  assertions = map (a: a.message) (builtins.filter (a: !a.assertion) h.assertions);
}
'''.replace('ROOT', json.dumps(str(root)))
result = subprocess.run(
    ['nix', '--extra-experimental-features', 'nix-command flakes',
     'eval', '--impure', '--json', '--expr', expr],
    capture_output=True, text=True,
    env=os.environ.copy(),
)
if result.returncode:
    raise SystemExit(result.stderr)
data = json.loads(result.stdout)
assert data['system'] == 'aarch64-linux', data
assert data['home'] == '/data/data/com.termux.nix/files/home', data
assert data['username'] == 'nix-on-droid', data
assert data['shell'].endswith('/bin/zsh'), data
assert data['editor'] == 'hx' and data['visual'] == 'hx', data
assert data['activation'].endswith('.drv'), data
assert data['terminal'] is None, data
assert not data['desktopOptions'], data
assert data['themeDirectory'] == '', data
assert not data['services'], data
assert not data['assertions'], data
packages = set(data['packages'])
assert {'zsh', 'sheldon', 'git', 'fzf', 'yazi', 'helix', 'neovim'} <= packages, data
for forbidden in ('hyprland', 'quickshell', 'rio', 'fcitx', 'mozkey', 'rclone',
                  'tuios', 'jeebis-desktop', 'jeebis-shell', 'steel'):
    assert not any(forbidden in p.lower() for p in packages), (forbidden, packages)
for name in data['files']:
    assert not any(part in name for part in (
        'hypr/', 'omarchy/', 'jeebis-desktop/', 'quickshell/', 'rio/',
        'fcitx5/', 'mozkey-ibg/', 'systemd/user/', 'helix/init.scm',
    )), name
assert '.zshrc' in data['files'] and '.zshenv' in data['files'], data
print('Android configuration passed: aarch64, Nix-on-Droid identity, shared CLI, no PC modules/files/services.')
print(f"Evaluated {len(packages)} packages and {len(data['files'])} managed files; no ARM build or device activation performed.")

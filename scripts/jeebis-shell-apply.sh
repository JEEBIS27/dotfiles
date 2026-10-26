#!/usr/bin/env bash
# Apply only the editable shell and personal Hyprland settings, not all of HM.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export JEEBIS_SHELL_REPO="$repo"
state="${XDG_STATE_HOME:-$HOME/.local/state}/jeebis-shell"
mkdir -p "$state"
nix_flags=(--extra-experimental-features 'nix-command flakes')
nix "${nix_flags[@]}" build --impure --out-link "$state/build" --expr '
  let repo = builtins.getEnv "JEEBIS_SHELL_REPO";
      flake = builtins.getFlake ("path:" + repo);
      pkgs = flake.inputs.nixpkgs-apps.legacyPackages.x86_64-linux;
  in import (builtins.toPath (repo + "/packages/jeebis-shell.nix")) {
    inherit pkgs;
    native = builtins.pathExists /etc/NIXOS;
  }'
built=$(readlink -f "$state/build")
hypr_source=$(nix "${nix_flags[@]}" store add-path "$repo/files/hypr")
nix-store --add-root "$state/hypr-source-root" --realise "$hypr_source" >/dev/null
python3 - "$built" "$hypr_source" "$state" <<'PY'
from pathlib import Path
import os, sys, json, tarfile, time
built, source, state = map(Path, sys.argv[1:])
home = Path.home()
config = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
host = 'jeebis-desktop' if Path('/etc/NIXOS').exists() else 'omarchy'
backup = state / ('backup-' + str(time.time_ns()))
backup.mkdir()
links = {
    config / host / 'plugins': built / 'plugins',
    config / 'jeebis/motion.lua': built / 'hyprland/jeebis-motion.lua',
    config / 'jeebis/curvature.lua': built / 'hyprland/jeebis-curvature.lua',
    **{config / 'hypr' / f: source / f for f in ('looknfeel.lua', 'window-animations.lua', 'hyprland.lua')},
}
for target in links.values():
    if not target.exists():
        raise SystemExit(f'Missing build input: {target}')
records = []
with tarfile.open(backup / 'config.tar.gz', 'w:gz', dereference=True) as archive:
    for path, target in links.items():
        if path.exists() or path.is_symlink():
            archive.add(path, arcname=str(path.relative_to(config)))
        records.append({'path': str(path), 'previous_link': os.readlink(path) if path.is_symlink() else None, 'existed': path.exists() or path.is_symlink(), 'new_link': str(target)})
(backup / 'links.json').write_text(json.dumps(records, indent=2) + '\n')
# Cache keys retain the same ~/.config URL and Nix mtimes; force fresh QML.
cache = Path(os.environ.get('XDG_CACHE_HOME', home / '.cache')) / 'quickshell/qmlcache'
if cache.exists():
    cache.rename(backup / 'qmlcache')
for path, target in links.items():
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.jeebis-' + str(os.getpid()))
    temporary.symlink_to(target)
    os.replace(temporary, path)
print(f'Backup: {backup}')
PY
hyprctl reload
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
  printf '%s\n' "$errors" >&2
  exit 1
fi
# A cold QML cache can take longer than Omarchy's short readiness deadline.
if ! jeebis-desktop shell restart >"$state/restart.log" 2>&1; then
  ready=false
  for ((attempt=0; attempt<40; attempt++)); do
    if jeebis-desktop shell shell ping >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 0.5
  done
  if [[ $ready != true ]]; then
    cat "$state/restart.log" >&2
    exit 1
  fi
fi
printf 'Applied shell and personal Hyprland settings.\n'

#!/usr/bin/env python3
"""Import reviewed GUI preferences or merge a Home Manager declaration."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def read(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f'{path}: expected a JSON object')
    return value


def write(path, value):
    content = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n'
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(content)
            handle.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['import', 'apply'])
    parser.add_argument('declaration', type=Path)
    parser.add_argument('--config', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'tide-island/userconfig.json')
    parser.add_argument('--managed', type=Path, help='integration settings enforced by the desktop')
    args = parser.parse_args()
    declaration = read(args.declaration)
    local = read(args.config) if args.config.exists() else {}
    if args.action == 'import':
        if not args.config.exists():
            parser.error(f'{args.config} does not exist')
        # Only reviewed keys enter Git/Nix store. Nested keys are filtered too.
        def select(schema, source):
            return {key: (source[key] if key == 'positions' else select(value, source[key]))
                    if isinstance(value, dict) and isinstance(source.get(key), dict)
                    else source.get(key, value)
                    for key, value in schema.items()}
        write(args.declaration, select(declaration, local))
    else:
        baseline = args.config.with_name('userconfig.defaults.json')
        previous = read(baseline) if baseline.exists() else {}

        def apply_defaults(local, old, new):
            result = dict(local)
            for key, value in new.items():
                if key not in local or (key in old and local[key] == old[key]):
                    result[key] = value
                elif key != 'positions' and isinstance(value, dict) and isinstance(local[key], dict):
                    old_child = old.get(key)
                    result[key] = apply_defaults(local[key], old_child if isinstance(old_child, dict) else {}, value)
            return result

        result = apply_defaults(local, previous, declaration)
        if args.managed:
            result.update(read(args.managed))
        if args.config.exists() and local != result:
            write(args.config.with_name('userconfig.before-home-manager.json'), local)
        write(args.config, result)
        write(baseline, declaration)


if __name__ == '__main__':
    main()

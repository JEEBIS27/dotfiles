"""Reconcile only declared Herdr preferences; never import session/auth state."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def read_object(path):
    if not path.exists():
        return {}
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def merge(old, owned):
    result = dict(old)
    for key, value in owned.items():
        result[key] = merge(result.get(key, {}) if isinstance(result.get(key), dict) else {}, value) if isinstance(value, dict) else value
    return result


def write_json(path, value, backup=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f"{path}: refusing to replace a user-provided symlink")
    text = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    if path.exists() and path.read_text() == text:
        return
    if backup and path.exists():
        saved = path.with_name(path.name + ".before-home-manager")
        if not saved.exists():
            descriptor = os.open(saved, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(path.read_bytes())
    descriptor, temporary = tempfile.mkstemp(prefix=".jeebis-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(text)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--preferences", type=Path)
    parser.add_argument("--theme", required=True, type=Path)
    args = parser.parse_args()
    # Parse and validate everything before changing any file.
    theme = read_object(args.theme)
    if not theme or not isinstance(theme.get("ansi"), list) or len(theme["ansi"]) != 16:
        raise ValueError("Herdr theme needs a complete 16-color palette")
    updates = []
    if args.preferences:
        preferences = read_object(args.preferences)
        for name in ["settings", "programs"]:
            path = args.root / (name + ".json")
            updates.append((path, merge(read_object(path), preferences[name])))
    theme_path = args.root / "themes/jeebis.json"
    for path in [theme_path] + [path for path, _ in updates]:
        if path.is_symlink():
            raise ValueError(f"{path}: refusing to replace a user-provided symlink")
    write_json(theme_path, theme)
    for path, value in updates:
        write_json(path, value, backup=True)


if __name__ == "__main__":
    main()

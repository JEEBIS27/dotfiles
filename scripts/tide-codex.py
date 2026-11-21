"""Register Tide's MCP question tool and lifecycle hooks alongside local Codex settings."""
import argparse
import json
import os
import shlex
import tempfile
import tomllib
from pathlib import Path


def update(path, text):
    if path.exists() and path.read_text() == text:
        return
    target = path.resolve() if path.is_symlink() else path
    fd, name = tempfile.mkstemp(dir=target.parent, prefix=".tide-")
    try:
        with os.fdopen(fd, "w") as out:
            out.write(text)
        os.replace(name, target)
    finally:
        Path(name).unlink(missing_ok=True)


def configure(directory, command):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    config = directory / "config.toml"
    current = config.read_text() if config.exists() else ""
    if "tide_island" not in tomllib.loads(current).get("mcp_servers", {}):
        update(config, current.rstrip() + '\n\n[mcp_servers.tide_island]\ncommand = ' + json.dumps(str(command)) +
               '\nargs = ["mcp"]\ntool_timeout_sec = 3600\n'
               '[mcp_servers.tide_island.env]\nTIDE_SOURCE_APP = "Codex"\nTIDE_SOURCE_DESKTOP = "chatgpt"\n')
    hooks = directory / "hooks.json"
    data = json.loads(hooks.read_text()) if hooks.exists() else {}
    events = data.setdefault("hooks", {})
    invocation = shlex.join([str(command), "hook", "--app", "Codex", "--desktop", "chatgpt"])
    for name in ("UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "Interrupt", "SessionEnd"):
        groups = events.setdefault(name, [])
        if not any(h.get("command") == invocation for g in groups for h in g.get("hooks", [])):
            groups.append({"hooks": [{"type": "command", "command": invocation, "timeout": 4}]})
    update(hooks, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("command", type=Path)
    args = parser.parse_args()
    configure(args.directory, args.command)

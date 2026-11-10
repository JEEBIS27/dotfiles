#!/usr/bin/env python3
"""Run rotation independently of shell visibility; greeter never calls shell IPC."""
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

helper, mode, *rest = sys.argv[1:]
if mode not in ("session", "greeter"):
    raise SystemExit("Expected session or greeter")
config = {"automatic": True, "animation": False, "normalYSign": -1, "delayMs": 1000}
if mode == "session":
    config.update(json.loads(Path(rest[0]).read_text()))
else:
    # Login has its own compositor and state; no access to the user's home.
    config.update({"automatic": False, "touchDevices": []})
    if rest:
        config.update(json.loads(Path(rest[0]).read_text()))
    os.environ["XDG_STATE_HOME"] = str(Path(os.environ["XDG_RUNTIME_DIR"]) / "jeebis-greeter")
spec = importlib.util.spec_from_file_location("rotation", helper)
rotation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rotation)
sys.argv = [helper, "watch", "--config", json.dumps(config)]
sys.exit(rotation.main())

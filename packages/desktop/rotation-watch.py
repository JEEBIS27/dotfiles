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
    text = Path(rest[0]).read_text()
    names = {"output": "displayRotationOutput", "automatic": "displayAutoRotate",
             "sensor": "displayRotationSensor", "normalYSign": "displayRotationNormalYSign",
             "animation": "displayRotationAnimationEnabled", "animationDuration": "displayRotationAnimationDuration",
             "animationSpeed": "animationSpeed", "delayMs": "displayRotationStableMs", "touchDevices": "displayRotationTouchDevices"}
    for key, name in names.items():
        match = re.search(r"^var " + re.escape(name) + r"\s*=\s*(.*?);", text, re.M)
        if match:
            config[key] = json.loads(match.group(1))
else:
    # Login has its own compositor and state; no access to the user's home.
    config["touchDevices"] = ["elan3233:00-04f3:423e", "elan3233:00-04f3:423e-unknown", "elan3233:00-04f3:423e-stylus"]
    os.environ["XDG_STATE_HOME"] = str(Path(os.environ["XDG_RUNTIME_DIR"]) / "jeebis-greeter")
spec = importlib.util.spec_from_file_location("rotation", helper)
rotation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rotation)
sys.argv = [helper, "watch", "--config", json.dumps(config)]
sys.exit(rotation.main())

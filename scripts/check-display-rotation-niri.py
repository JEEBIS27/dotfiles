#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rotation", root / "packages/desktop/display-rotation.py")
rotation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rotation)

normal = json.dumps({
    "eDP-1": {
        "name": "eDP-1",
        "logical": {"x": 0, "y": 0, "width": 1280, "height": 800,
                    "scale": 1.5, "transform": "Normal"},
    },
})
inverted = normal.replace('"Normal"', '"_180"')
calls = []

def fake_run(*args):
    calls.append(args)
    if args == ("niri", "msg", "--json", "outputs"):
        return inverted if any(call[-2:] == ("transform", "180") for call in calls) else normal
    if args == ("niri", "msg", "output", "eDP-1", "transform", "180"):
        return "Output configuration applied."
    raise AssertionError(args)

config = {"compositor": "niri", "output": "eDP-1"}
with patch.object(rotation, "run", fake_run):
    monitor = rotation.select_monitor(rotation.monitors(config), "eDP-1")
    assert monitor == {"name": "eDP-1", "transform": 0}
    rotation.apply(monitor, 2, config)
    assert rotation.select_monitor(rotation.monitors(config), "eDP-1")["transform"] == 2

stable = rotation.StableOrientation(1)
assert stable.update(2, 0) is None
assert stable.update(2, 1) == 2
# Return the settled value again so a compositor config reload can be repaired.
assert stable.update(2, 2) == 2
assert rotation.orientation([0, -1, 0], -1) == 0
assert rotation.orientation([0, 1, 0], -1) == 2
print("Niri rotation: JSON output parsed, transform applied, settled orientation retained.")

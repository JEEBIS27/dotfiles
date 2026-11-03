#!/usr/bin/env python3
# Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
"""Owned internal-display rotation control; no root or sensor daemon required."""
import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=6)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Command failed")
    return result.stdout


def monitors():
    return json.loads(run("hyprctl", "monitors", "-j"))


def select_monitor(items, output=""):
    if output:
        return next((m for m in items if m["name"] == output), None)
    return next((m for m in items if m["name"].startswith(("eDP-", "LVDS-", "DSI-"))), None)


def sensor_path(config):
    override = config.get("sensor", "")
    if override:
        candidates = [Path(override)]
    else:
        candidates = sorted(Path("/sys/bus/iio/devices").glob("iio:device*"))
    for candidate in candidates:
        if all(os.access(candidate / ("in_accel_" + axis + "_raw"), os.R_OK) for axis in "xyz"):
            return candidate
    return None


def read_vector(path):
    vector = [float((path / ("in_accel_" + a + "_raw")).read_text()) for a in "xyz"]
    # Hardware-provided mounting matrix takes precedence over raw sensor axes.
    matrix = path / "in_accel_mount_matrix"
    if matrix.exists():
        rows = [[float(x.strip()) for x in row.split(",")] for row in matrix.read_text().split(";")]
        if len(rows) != 3 or any(len(row) != 3 for row in rows):
            raise ValueError("Invalid accelerometer mount matrix")
        vector = [sum(row[i] * vector[i] for i in range(3)) for row in rows]
    return vector


def orientation(vector, normal_y_sign=-1):
    x, y, z = vector
    magnitude = math.sqrt(x*x + y*y + z*z)
    if not math.isfinite(magnitude) or magnitude <= 0 or abs(y) < magnitude * .65:
        return None  # Flat, sideways or moving: retain the current orientation.
    return 0 if y * normal_y_sign > 0 else 2


class StableOrientation:
    def __init__(self, delay):
        self.delay = delay
        self.candidate = None
        self.since = 0

    def update(self, value, now):
        if value is None:
            self.candidate = None
            return None
        if value != self.candidate:
            self.candidate, self.since = value, now
        return value if now - self.since >= self.delay else None


def lua(value):
    # JSON strings/numbers used here are valid Lua literals; no shell interpolation.
    return json.dumps(value, ensure_ascii=False)


def rotation_command(monitor, transform, touch_devices):
    # Explicitly retain the actual mode, scale, placement, VRR and color settings.
    # A transform-only hl.monitor() rule would reset optional fields to defaults.
    width, height = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    fields = {
        "output": monitor["name"],
        "mode": f'{width}x{height}@{monitor["refreshRate"]:.5f}',
        "position": f'{monitor["x"]}x{monitor["y"]}',
        "scale": monitor["scale"], "transform": transform,
        "vrr": monitor.get("vrr", 0),
        "cm": monitor.get("colorManagementPreset", "srgb"),
        "sdrbrightness": monitor.get("sdrBrightness", 1),
        "sdrsaturation": monitor.get("sdrSaturation", 1),
    }
    if monitor.get("mirrorOf", "none") != "none":
        fields["mirror"] = monitor["mirrorOf"]
    if "10" in monitor.get("currentFormat", ""):
        fields["bitdepth"] = 10
    commands = ["hl.monitor({" + ", ".join(k + " = " + lua(v) for k, v in fields.items()) + "})"]
    for name in touch_devices:
        commands.append("hl.device({ name = " + lua(name) + ", output = " + lua(monitor["name"]) + ", transform = " + str(transform) + " })")
    return "; ".join(commands)


def transition_ipc(method, *args):
    return run("omarchy-shell", "jeebis.display", method, *args)


def prepare_transition(monitor, transform, config):
    if not config.get("animation", False):
        return None
    token = uuid.uuid4().hex
    try:
        angle = "180" if transform > monitor["transform"] else "-180"
        transition_ipc("prepareRotation", monitor["name"], angle, token)
        duration = max(1, float(config.get("animationDuration", 650))) / 1000
        speed = max(.1, min(10, float(config.get("animationSpeed", 1))))
        deadline = time.monotonic() + min(35, duration / speed + 3)
        while time.monotonic() < deadline:
            state = json.loads(transition_ipc("rotationTransition"))
            if state.get("token") != token or state.get("phase") == "idle":
                break
            if state.get("phase") == "ready":
                return token
            time.sleep(.025)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        pass
    try:
        transition_ipc("abortRotation", token)
    except (OSError, RuntimeError, subprocess.SubprocessError):
        pass
    return None


def apply(monitor, transform, config):
    token = prepare_transition(monitor, transform, config)
    success = False
    try:
        devices = config.get("touchDevices", [])
        command = rotation_command(monitor, transform, devices)
        if token:
            # The overlay observes command completion directly and compensates
            # the captured frame before crossfading, without another IPC round trip.
            result = transition_ipc("applyRotation", token, command)
            if result.strip() != "true":
                raise RuntimeError("Rotation handoff was rejected")
        else:
            result = run("hyprctl", "eval", command)
            if "error" in result.lower():
                raise RuntimeError(result.strip())
        # Output reconfiguration can commit on a later compositor frame.
        deadline = time.monotonic() + 2
        while True:
            actual = select_monitor(monitors(), monitor["name"])
            if actual is not None and actual.get("transform") == transform:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError("Display rotation was not applied")
            time.sleep(.04)
        success = True
    finally:
        if token:
            try:
                if not success:
                    transition_ipc("abortRotation", token)
            except (OSError, RuntimeError, subprocess.SubprocessError):
                pass  # The overlay watchdog also releases the capture.


def load_state(path, config):
    try:
        value = json.loads(path.read_text())
        if not isinstance(value, dict):
            raise ValueError("Invalid state")
        return value
    except (OSError, ValueError):
        return {"version": 1, "automatic": config.get("automatic", False) is True}


def save_state(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".rotation-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def status(config, state):
    monitor = select_monitor(monitors(), config.get("output", ""))
    sensor = sensor_path(config)
    return {"available": monitor is not None, "output": monitor["name"] if monitor else "",
            "transform": monitor.get("transform", 0) if monitor else 0,
            "automatic": state.get("automatic") is True, "sensorAvailable": sensor is not None,
            "sensor": str(sensor) if sensor else "", "error": ""}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["status", "toggle", "toggle-auto", "watch"])
    parser.add_argument("--config", default="{}")
    args = parser.parse_args()
    config = json.loads(args.config)
    path = Path(os.environ.get("XDG_STATE_HOME", str(Path.home()/".local/state"))) / "jeebis-shell/display-rotation.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    # Serialize actions and the watcher, so a pending sensor decision cannot
    # overwrite a manual click that just disabled automatic rotation.
    lock = (path.parent / "display-rotation.lock").open("a")
    previous = None
    stable = StableOrientation(max(.5, min(10, float(config.get("delayMs", 1500))/1000)))
    while True:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = load_state(path, config)
            info = status(config, state)
            if args.action in ("toggle", "toggle-auto"):
                if not info["available"]:
                    raise RuntimeError("Internal display is unavailable")
                if args.action == "toggle-auto":
                    if not info["automatic"] and not info["sensorAvailable"]:
                        raise RuntimeError("Readable accelerometer is unavailable")
                    state.update(automatic=not info["automatic"], output=info["output"], transform=info["transform"])
                else:
                    current = select_monitor(monitors(), info["output"])
                    target = current["transform"] ^ 2
                    apply(current, target, config)
                    state.update(automatic=False, output=info["output"], transform=target)
                save_state(path, state)
                info = status(config, state)
            elif args.action == "watch":
                target = None
                if info["automatic"] and info["sensorAvailable"]:
                    value = orientation(read_vector(Path(info["sensor"])), int(config.get("normalYSign", -1)))
                    target = stable.update(value, time.monotonic())
                else:
                    stable.update(None, time.monotonic())
                    if state.get("output") == info["output"] and type(state.get("transform")) is int and state["transform"] in range(8):
                        target = state["transform"]
                if target is not None and info["available"] and target != info["transform"]:
                    current = select_monitor(monitors(), info["output"])
                    apply(current, target, config)
                    info = status(config, state)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            info = {"error": str(error), "available": False}
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
        line = json.dumps(info, ensure_ascii=True)
        if line != previous:
            print(line, flush=True)
            previous = line
        if args.action != "watch":
            return 1 if info.get("error") else 0
        time.sleep(.5 if info.get("automatic") else 2)


if __name__ == "__main__":
    sys.exit(main())

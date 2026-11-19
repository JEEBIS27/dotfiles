"""Niri 26.04 launch/close actions use captured, explicit window IDs."""
import argparse
from contextlib import nullcontext
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import uuid
from urllib.parse import urlsplit


def request(message):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(3)
        connection.connect(os.environ["NIRI_SOCKET"])
        connection.sendall(json.dumps(message).encode() + b"\n")
        with connection.makefile("rb") as stream:
            reply = json.loads(stream.readline())
    if "Err" in reply:
        raise RuntimeError(str(reply["Err"]))
    return reply["Ok"]


def query(name):
    return request(name)[name]


def action(name, **arguments):
    return request({"Action": {name: arguments}})


def focused_workspace():
    return next((w["id"] for w in query("Workspaces") if w.get("is_focused")), None)


def notify(message):
    print(message, file=sys.stderr)
    subprocess.run(["notify-send", "Niri launch", message], check=False)


def matches(app, window):
    identity = (window.get("app_id") or "").casefold()
    if identity in {value.casefold() for value in app["appIds"]}:
        return True
    if "url" in app:
        url = urlsplit(app["url"])
        prefix = "chrome-" + url.netloc + "_" + url.path.replace("/", "_") + "-"
        return identity.startswith(prefix.casefold())
    return False


def generation():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    target = runtime / "jeebis-niri-launch-generation"
    token = uuid.uuid4().hex
    descriptor, temporary = tempfile.mkstemp(prefix=".jeebis-niri-", dir=runtime)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(token)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return lambda: target.read_text() == token


def place_below(original, target, workspace, current_generation):
    """Consume a new tile, then order it immediately after the original tile."""
    windows = query("Windows")
    anchor = next((w for w in windows if w["id"] == original["id"]), None)
    target = next((w for w in windows if w["id"] == target["id"]), None)
    if not anchor or not target:
        return
    left = anchor.get("layout", {}).get("pos_in_scrolling_layout")
    right = target.get("layout", {}).get("pos_in_scrolling_layout")
    if anchor.get("is_floating") or target.get("is_floating") or not left or not right:
        notify("Split launch requires tiled windows; the new window was left in place.")
        return
    if anchor.get("workspace_id") != workspace or target.get("workspace_id") != workspace:
        return
    active = next((w for w in windows if w.get("is_focused")), None)
    if not active or active["id"] not in {anchor["id"], target["id"]}:
        return
    if not current_generation() or focused_workspace() != workspace:
        return
    if left[0] != right[0]:
        column = [w for w in windows if w.get("workspace_id") == workspace
                  and (w.get("layout", {}).get("pos_in_scrolling_layout") or [None])[0] == right[0]]
        if right[0] != left[0] + 1 or len(column) != 1:
            notify("New window is not a single tile beside the original column; left in place.")
            return
    # Niri 26.04 vertical moves address the focused tile rather than an ID.
    # Focus the verified new tile once, then recheck before every reorder.
    action("FocusWindow", id=target["id"])
    if left[0] != right[0]:
        if not current_generation() or focused_workspace() != workspace:
            return
        action("ConsumeOrExpelWindowLeft", id=target["id"])
    for _ in range(len(windows) + 2):
        if not current_generation() or focused_workspace() != workspace:
            return
        state = query("Windows")
        anchor = next((w for w in state if w["id"] == original["id"]), None)
        new = next((w for w in state if w["id"] == target["id"]), None)
        active = next((w for w in state if w.get("is_focused")), None)
        if not anchor or not new or not active or active["id"] != target["id"]:
            return
        if anchor.get("workspace_id") != workspace or new.get("workspace_id") != workspace:
            return
        above = anchor.get("layout", {}).get("pos_in_scrolling_layout")
        below = new.get("layout", {}).get("pos_in_scrolling_layout")
        if not above or not below or above[0] != below[0]:
            return
        if below[1] == above[1] + 1:
            return
        action("MoveWindowUp" if below[1] > above[1] + 1 else "MoveWindowDown")
        time.sleep(0.02)
    notify("Could not confirm the new window directly below the original window.")


def launch(catalog, name, below=False):
    app = catalog[name]
    current_generation = generation()
    workspace = focused_workspace()
    original = query("FocusedWindow")
    place_on_workspace = app.get("placeOnLaunchWorkspace", False)
    lock = nullcontext()
    if place_on_workspace:
        lock = (Path(os.environ["XDG_RUNTIME_DIR"]) / f"jeebis-niri-launch-{name}.lock").open("a")
    with lock as stream:
        if stream is not None:
            # Attribute newly mapped windows to one pending launch at a time.
            fcntl.flock(stream, fcntl.LOCK_EX)
        launch_window(app, workspace, original, current_generation, below, place_on_workspace)


def launch_window(app, workspace, original, current_generation, below, place_on_workspace):
    split = below and original is not None
    before = query("Windows")
    known = {w["id"] for w in before}
    argv = list(app["argv"])
    if app.get("terminal") and original and original.get("pid"):
        # Best effort only: compositor client cwd may differ from shell cwd.
        try:
            cwd = Path(f"/proc/{original['pid']}/cwd").resolve(strict=True)
            if cwd.is_dir():
                boundary = argv.index("--") if "--" in argv else len(argv)
                argv[boundary:boundary] = ["--cwd", str(cwd)]
        except OSError:
            pass
    action("Spawn", command=argv)
    if workspace is None or not (split or place_on_workspace):
        return
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if not place_on_workspace and (not current_generation() or focused_workspace() != workspace):
            return
        windows = query("Windows")
        active = next((w for w in windows if w.get("is_focused")), None)
        if not place_on_workspace and active and active["id"] not in known and not matches(app, active):
            return
        candidates = [w for w in windows if w["id"] not in known and matches(app, w)
                      and (place_on_workspace or w.get("workspace_id") == workspace)]
        target = next((w for w in candidates if w.get("is_focused")), None)
        if target is None and len(candidates) == 1:
            target = candidates[0]
        if target:
            if place_on_workspace and target.get("workspace_id") != workspace:
                if not any(w["id"] == workspace for w in query("Workspaces")):
                    notify(f"{app['name']}: the launch workspace disappeared.")
                    return
                # Keep the user's focus when a launch completes in the background.
                action("MoveWindowToWorkspace", reference={"Id": workspace},
                       window_id=target["id"], focus=False)
            if not current_generation() or focused_workspace() != workspace:
                return
            if split and active and active["id"] in {target["id"], original["id"]}:
                place_below(original, target, workspace, current_generation)
            elif place_on_workspace and (not active or active["id"] in
                                         {target["id"], (original or {}).get("id")}):
                action("FocusWindow", id=target["id"])
            return
        # No existing window is moved, including singleton apps that only
        # activate a window instead of opening another one.
        if not place_on_workspace and active and active["id"] != original["id"] and not matches(app, active):
            return
        time.sleep(0.1)
    notify(f"{app['name']}: no new matching window appeared; existing windows were not moved.")


def close_workspace():
    workspace = focused_workspace()
    if workspace is None:
        return
    # Snapshot first: closing windows changes focus and layout.
    targets = [w["id"] for w in query("Windows") if w.get("workspace_id") == workspace]
    for identifier in targets:
        try:
            action("CloseWindow", id=identifier)
        except RuntimeError:
            if identifier in {w["id"] for w in query("Windows")}:
                raise


def search_windows(desktop):
    windows = query("Windows")
    workspaces = {w["id"]: w.get("name") or w["idx"] for w in query("Workspaces")}
    entries = []
    for window in windows:
        title = window.get("title") or "(untitled)"
        app = window.get("app_id") or ""
        workspace = workspaces.get(window.get("workspace_id"), "?")
        entries.append({
            "id": str(window["id"]), "name": title, "icon": app,
            "comment": f"{app} · WS {workspace}",
        })
    # IPC treats a bare JSON array as multiple arguments. Quote it as a string.
    payload = json.dumps(json.dumps(entries, ensure_ascii=False), ensure_ascii=False)
    if subprocess.run([desktop, "shell", "tide", "toggleSearch", "windows", payload]).returncode:
        raise RuntimeError("could not open Tide window search")


def clipboard(operation):
    window = query("FocusedWindow") or {}
    identity = (window.get("app_id") or "").casefold()
    terminal = identity in {
        "com.mitchellh.ghostty", "ghostty", "rio", "alacritty", "kitty",
        "foot", "org.codeberg.dnkl.foot", "org.jeebis.terminal", "org.jeebis.tmux",
    } or identity.startswith(("org.omarchy.", "tui."))
    modifier, key = "ctrl", {"cut": "x", "copy": "c", "paste": "v"}[operation]
    if operation == "cut":
        modifier, key = "shift", "Delete"
    elif terminal:
        modifier, key = ("ctrl" if operation == "copy" else "shift"), "Insert"
    # Set the virtual keyboard's modifiers explicitly, excluding held Super.
    subprocess.run(["wtype", "-M", "logo", "-M", "shift", "-M", "alt", "-M", "ctrl",
                    "-m", modifier, "-k", key, "-M", modifier], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--desktop", default="jeebis-desktop")
    sub = parser.add_subparsers(dest="operation", required=True)
    launch_parser = sub.add_parser("launch")
    launch_parser.add_argument("application")
    launch_parser.add_argument("--below", action="store_true")
    sub.add_parser("close-workspace")
    sub.add_parser("search-windows")
    sub.add_parser("toggle-maximize")
    sub.add_parser("clipboard").add_argument("clipboard_operation", choices=["cut", "copy", "paste"])
    args = parser.parse_args()
    if args.operation == "clipboard":
        clipboard(args.clipboard_operation)
    elif args.operation == "close-workspace":
        close_workspace()
    elif args.operation == "search-windows":
        search_windows(args.desktop)
    elif args.operation == "toggle-maximize":
        window = query("FocusedWindow")
        if window:
            if window.get("is_floating"):
                action("MaximizeWindowToEdges", id=window["id"])
            else:
                subprocess.run(["jeebis-niri-resize", "toggle-maximize"], check=True)
    else:
        catalog = json.loads(args.catalog.read_text())
        if args.application not in catalog:
            parser.error("Unknown application")
        launch(catalog, args.application, args.below)


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, ValueError, RuntimeError) as error:
        print(f"jeebis-niri: {error}", file=sys.stderr)
        sys.exit(1)

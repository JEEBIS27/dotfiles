"""Open the source of a Tide activity and perform desktop selections."""
import asyncio
import json
import os
import re
from pathlib import Path


async def run(*args, check=True):
    proc = await asyncio.create_subprocess_exec(*map(str, args), stdout=-1, stderr=-1)
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), 15)
    except (TimeoutError, asyncio.CancelledError):
        if proc.returncode is None:
            proc.kill()
        await proc.wait()
        raise
    if check and proc.returncode:
        raise ValueError(stderr.decode(errors="replace").strip() or f"{args[0]} failed")
    return stdout.decode(errors="replace").strip()


def niri():
    return bool(os.environ.get("NIRI_SOCKET"))


async def windows():
    if niri():
        rows = json.loads(await run("niri", "msg", "-j", "windows"))
        return [(str(w["id"]), w["app_id"] or "", w.get("pid"), w["is_focused"]) for w in rows]
    rows = json.loads(await run("hyprctl", "-j", "clients"))
    return [(w["address"], w["class"], w["pid"], w.get("focusHistoryID") == 0) for w in rows]


def ancestors(pid):
    result = []
    try:
        while int(pid) > 1 and pid not in result:
            result.append(pid)
            pid = int(Path(f"/proc/{int(pid)}/stat").read_text().rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        pass
    return result


def app_key(name):
    return str(name).removesuffix(".desktop").casefold()


async def locate(source):
    rows = await windows()
    # PIDs identify the particular terminal or client among same-app windows.
    lineage = source.get("lineage") or ancestors(source.get("pid", 0))
    for pid in lineage:
        matches = [w for w in rows if w[2] == pid]
        if matches:
            return next((w for w in matches if w[3]), matches[0])
    names = {app_key(s) for s in (source.get("desktop"), source.get("app")) if s}
    matches = [w for w in rows if app_key(w[1]) in names]
    return next((w for w in matches if w[3]), matches[0] if matches else None)


def desktop_file(source):
    roots = [os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")]
    roots += os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    for name in (source.get("desktop"), source.get("app")):
        if not name or not re.fullmatch(r"[\w.+ -]+", name):
            continue
        for root in roots:
            apps = Path(root) / "applications"
            path = apps / (name.removesuffix(".desktop") + ".desktop")
            if path.is_file():
                return path
            if apps.is_dir():
                match = next((p for p in apps.glob("*.desktop") if app_key(p.name) == app_key(name)), None)
                if match:
                    return match
    return None


async def open_source(source):
    if source.get("terminal"):
        await run("herdr-app", "do", "agent.focus", "--terminal", source["terminal"], check=False)
        source = {**source, "app": "herdr-app"}
    rows = await windows()
    window = next((w for w in rows if w[0] == source.get("window") and
                   (not source.get("windowApp") or app_key(w[1]) == app_key(source["windowApp"]))), None)
    if not window:
        window = await locate(source)
    if window:
        if niri():
            await run("niri", "msg", "action", "focus-window", "--id", window[0])
        else:
            await run("hyprctl", "dispatch", "focuswindow", "address:" + window[0])
        return
    path = desktop_file(source)
    if path:
        await run("gio", "launch", path)
        return
    raise ValueError("No window or desktop entry is available for this app.")


async def outputs(kind):
    if kind == "audio":
        rows = json.loads(await run("pactl", "-f", "json", "list", "sinks"))
        current = await run("pactl", "get-default-sink")
        return [dict(id=w["name"], label=w["description"], selected=w["name"] == current) for w in rows]
    if niri():
        rows = json.loads(await run("niri", "msg", "-j", "outputs"))
        monitor = json.loads(await run("niri", "msg", "-j", "focused-output")) or {}
        return [dict(id=name, label=f"{w.get('model') or name} · {name}", selected=name == monitor.get("name"))
                for name, w in sorted(rows.items())]
    rows = json.loads(await run("hyprctl", "-j", "monitors", "all"))
    return [dict(id=w["name"], label=w.get("description") or w["name"], selected=w.get("focused", False)) for w in rows]


async def choose(kind, target):
    choices = await outputs(kind)
    selected = next((o for o in choices if o["id"] == target), None)
    if not selected:
        raise ValueError("Output disconnected. Open the list again.")
    if kind == "audio":
        await run("pactl", "set-default-sink", target)
        for stream in json.loads(await run("pactl", "-f", "json", "list", "sink-inputs")):
            await run("pactl", "move-sink-input", stream["index"], target, check=False)
    elif niri():
        if selected["selected"]:
            return
        workspaces = json.loads(await run("niri", "msg", "-j", "workspaces"))
        window = next((w.get("active_window_id") for w in workspaces if w["is_focused"]), None)
        await run("niri", "msg", "output", target, "on")
        if window:
            await run("niri", "msg", "action", "move-window-to-monitor", "--id", window, target)
        await run("niri", "msg", "action", "focus-monitor", target)
    else:
        if selected["selected"]:
            return
        window = json.loads(await run("hyprctl", "-j", "activewindow"))
        if window.get("address"):
            await run("hyprctl", "dispatch", "movewindow", f"mon:{target},address:{window['address']}")
        await run("hyprctl", "dispatch", "focusmonitor", target)


async def capture(mode):
    if mode not in ("region", "window", "screen"):
        raise ValueError("Unknown capture mode")
    if niri():
        action = {"region": "screenshot", "window": "screenshot-window", "screen": "screenshot-screen"}[mode]
        await run("niri", "msg", "action", action)
        return
    args = []
    if mode == "region":
        args = ["-g", await run("slurp")]
    elif mode == "window":
        w = json.loads(await run("hyprctl", "-j", "activewindow"))
        args = ["-g", "%d,%d %dx%d" % (*w["at"], *w["size"])]
    else:
        monitors = await outputs("video")
        args = ["-o", next(w["id"] for w in monitors if w["selected"])]
    await run("grim", *args)

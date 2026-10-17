#!/usr/bin/env python3
"""Report cumulative CPU ticks for each Hyprland workspace's window processes."""

import glob
import json
import os
import subprocess


def read_process_stats(path):
    try:
        raw = open(path, "r", encoding="utf-8").read()
        close = raw.rfind(")")
        if close < 0:
            return None
        fields = raw[close + 2 :].split()
        pid = int(os.path.basename(path))
        parent_pid = int(fields[1])
        cpu_ticks = int(fields[11]) + int(fields[12])
        return pid, parent_pid, cpu_ticks
    except (OSError, ValueError, IndexError):
        return None


def main():
    clients = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True))
    roots_by_workspace = {}
    for client in clients:
        workspace = client.get("workspace") or {}
        workspace_id = workspace.get("id") if isinstance(workspace, dict) else workspace
        try:
            workspace_id = str(int(workspace_id))
            pid = int(client.get("pid") or 0)
        except (TypeError, ValueError):
            continue
        if pid > 0:
            roots_by_workspace.setdefault(workspace_id, set()).add(pid)

    process_stats = {}
    children = {}
    for path in glob.glob("/proc/[0-9]*/stat"):
        stats = read_process_stats(path)
        if not stats:
            continue
        pid, parent_pid, cpu_ticks = stats
        process_stats[pid] = cpu_ticks
        children.setdefault(parent_pid, []).append(pid)

    totals = {}
    for workspace_id, roots in roots_by_workspace.items():
        seen = set()
        pending = list(roots)
        total_ticks = 0
        while pending:
            pid = pending.pop()
            if pid in seen:
                continue
            seen.add(pid)
            total_ticks += process_stats.get(pid, 0)
            pending.extend(children.get(pid, []))
        totals[workspace_id] = total_ticks

    print(json.dumps({
        "tickRate": os.sysconf("SC_CLK_TCK"),
        "workspaces": totals,
    }))


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        print(json.dumps({"tickRate": 100, "workspaces": {}}))

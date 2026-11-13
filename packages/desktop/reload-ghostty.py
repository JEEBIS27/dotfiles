"""Reload only this user's Ghostty processes with an installed SIGUSR2 handler."""
import os
import signal
from pathlib import Path

for process in Path("/proc").iterdir():
    if not process.name.isdecimal():
        continue
    try:
        if process.stat().st_uid != os.getuid():
            continue
        if (process / "comm").read_text().strip() != "ghostty":
            continue
        status = dict(line.split(":", 1) for line in (process / "status").read_text().splitlines() if ":" in line)
        # During GTK startup there may be no reload handler yet. Sending a
        # signal then would terminate the terminal instead of reloading it.
        if int(status.get("SigCgt", "0"), 16) & (1 << (signal.SIGUSR2 - 1)):
            os.kill(int(process.name), signal.SIGUSR2)
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        pass

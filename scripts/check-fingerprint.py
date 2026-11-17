#!/usr/bin/env python3
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = root / "scripts/fingerprint.sh"
with tempfile.TemporaryDirectory() as directory:
    bindir = Path(directory)
    log = bindir / "log"
    for name in ("fprintd-enroll", "fprintd-list", "fprintd-verify", "fprintd-delete"):
        command = bindir / name
        command.write_text(f'#!/bin/sh\nprintf \'%s\\n\' "{name} $*" >> "$FP_LOG"\n')
        command.chmod(0o755)
    env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", FP_LOG=str(log), USER="jeebis")
    subprocess.run([script, "enroll", "right-thumb"], env=env, check=True)
    subprocess.run([script, "list"], env=env, check=True)
    subprocess.run([script, "verify", "left-index-finger"], env=env, check=True)
    invalid = subprocess.run([script, "enroll", "not-a-finger"], env=env, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert invalid.returncode != 0
    assert log.read_text().splitlines() == [
        "fprintd-enroll -f right-thumb jeebis",
        "fprintd-list jeebis",
        "fprintd-verify -f left-index-finger jeebis",
    ]
print("Fingerprint helper: enroll, list, verify and finger validation passed.")

"""Add a Linux second-instance launch option to the pinned ChatGPT ASAR."""

import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def patch_archive(path):
    # ASAR has two Chromium Pickle headers, followed by the packed file data.
    with path.open("rb") as source:
        _, header_size, _, json_size = struct.unpack("<4I", source.read(16))
        header = json.loads(source.read(json_size))
        data_start = 8 + header_size
        files = header["files"][".vite"]["files"]["build"]["files"]
        entry = files["early-bootstrap-100-449e39ca9c7eadbd.js"]
        source.seek(data_start + int(entry["offset"]))
        original = source.read(entry["size"])
        if sha256(original) != entry["integrity"]["hash"]:
            raise ValueError("ChatGPT bootstrap integrity mismatch")

        hook = b"Z(e=>{let t=null!=B.windowsActivation?AE(e):null;"
        if original.count(hook) != 1:
            raise ValueError("ChatGPT second-instance handler has changed")
        # eW is the same fresh-window function used by File > New Window.
        # Retain the stock handler for ordinary launches and URL callbacks.
        patched = original.replace(
            hook,
            b'Z(e=>{if(e.includes("--jeebis-new-window"))return void eW("/").catch('
            b'e=>H.reportNonFatal(e,{kind:"second-instance-open-window-failed"}));'
            + hook.removeprefix(b"Z(e=>{"),
        )
        block_size = entry["integrity"]["blockSize"]
        entry.update(
            offset=str(path.stat().st_size - data_start),
            size=len(patched),
            integrity={
                "algorithm": "SHA256",
                "hash": sha256(patched),
                "blockSize": block_size,
                "blocks": [
                    sha256(patched[start:start + block_size])
                    for start in range(0, len(patched), block_size)
                ],
            },
        )
        encoded = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
        padding = (-len(encoded)) % 4
        temporary = path.with_suffix(".asar.tmp")
        with temporary.open("wb") as output:
            output.write(struct.pack("<4I", 4, 8 + len(encoded) + padding,
                                     4 + len(encoded) + padding, len(encoded)))
            output.write(encoded + b"\0" * padding)
            source.seek(data_start)
            shutil.copyfileobj(source, output)
            output.write(patched)
    temporary.replace(path)


if __name__ == "__main__":
    patch_archive(Path(sys.argv[1]))

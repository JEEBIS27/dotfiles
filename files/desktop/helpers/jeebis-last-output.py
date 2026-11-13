"""Extract the latest completed command from the private PTY output log."""
import os
import sys
import time
from pathlib import Path

import pyte


def last_output(data, token):
    prefix = b'\x1b]777;jeebis;' + token.encode() + b';'
    end = data.rfind(prefix + b'end\x07')
    start = data.rfind(prefix + b'start\x07', 0, end)
    if end < 0 or start < 0:
        raise ValueError('完了したコマンドの出力がありません。')
    return data[start + len(prefix + b'start\x07'):end]


def main():
    log = Path(os.environ['JEEBIS_OUTPUT_LOG'])
    token = os.environ['JEEBIS_OUTPUT_TOKEN']
    # script flushes asynchronously. Wait until this invocation's start marker
    # has reached the log, so the preceding completed region is available.
    marker = b'\x1b]777;jeebis;' + token.encode() + b';start\x07'
    for _ in range(100):
        data = log.read_bytes()
        if data.rfind(marker) > data.rfind(b';end\x07'):
            break
        time.sleep(.01)
    try:
        raw = last_output(data, token)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    if not raw:
        return 0
    # A wide virtual screen unwraps ordinary terminal line wrapping. Interpret
    # colors, carriage returns, backspaces and erase sequences as terminal text.
    screen = pyte.HistoryScreen(10000, 100, history=50000)
    pyte.Stream(screen).feed(raw.decode('utf-8', errors='replace'))
    lines = [''.join(line[x].data for x in range(max(line, default=-1) + 1)).rstrip()
             for line in [*screen.history.top, *[screen.buffer[y] for y in range(screen.cursor.y + 1)]]]
    newline = bool(lines and not lines[-1])
    if newline:
        lines.pop()
    sys.stdout.write('\n'.join(lines) + ('\n' if newline else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())

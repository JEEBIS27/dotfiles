"""Publish cell rectangles to the Ghostty surface displaying each tmux client."""
import fcntl
import os
import stat
import struct
import subprocess
import sys
import termios
from pathlib import Path

# Store each 24-bit word in the low two bits of four xterm cube colors.
# Indexed applications retain the cube shade to within 3/255 per channel.
FIRST = 160
WORDS = 11
CUBE = (0, 95, 135, 175, 215, 255)
MAGIC = 0x464F43
EMPTY = (0, 0, 0, 0)


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True).rstrip('\n')


def rect(x, y, w, h):
    return (x, y, x + w, y + h)


def editor_rects(view, x, y, w, h):
    values = view.split()
    if len(values) != 8 or not all(value.isascii() and value.isdecimal() for value in values):
        return EMPTY, EMPTY
    cols, rows, top, bottom, vx, vy, vw, vh = map(int, values)
    if (w, h) != (cols, rows):
        return EMPTY, EMPTY  # Wait for the editor's resize/redraw.
    frame = rect(x, y + top, w, h - top - bottom)
    active = rect(x + vx, y + vy, vw, vh)
    return (EMPTY, EMPTY) if active == frame else (frame, active)


def palette_entries(words):
    entries = []
    for offset, word in enumerate(words):
        for part in range(4):
            slot = FIRST + 4 * offset + part
            cube = slot - 16
            base = (CUBE[cube // 36], CUBE[cube // 6 % 6], CUBE[cube % 6])
            bits = word >> (18 - 6 * part)
            rgb = bytes((channel & 252) | ((bits >> shift) & 3)
                        for channel, shift in zip(base, (4, 2, 0)))
            entries.append(f'{slot};#{rgb.hex()}')
    return entries


def update(tty, grid, cell, rectangles):
    if not tty.startswith('/dev/pts/') or not tty[9:].isdecimal():
        return
    info = os.stat(tty)
    if not stat.S_ISCHR(info.st_mode) or info.st_uid != os.getuid():
        return
    cache = Path(os.environ['XDG_RUNTIME_DIR']) / f'jeebis-focus-{os.major(info.st_rdev)}-{os.minor(info.st_rdev)}'
    # Do not touch the terminal palette at all before the first split.
    values = (*grid, *cell, *(v for box in rectangles for v in box))
    enabled = (all(cell) and all(0 <= value <= 4095 for value in values)
               and any(frame != EMPTY for frame in rectangles[::2]))
    if not enabled and not cache.exists():
        return
    with cache.open('a+') as last:
        fcntl.flock(last, fcntl.LOCK_EX)
        last.seek(0)
        previous = last.read().splitlines()
        entries = []
        if enabled:
            packed = [MAGIC] + [(a << 12) | b for a, b in zip(values[::2], values[1::2])]
            entries = palette_entries(packed)
            changed = [entry for i, entry in enumerate(entries)
                       if i >= len(previous) or previous[i] != entry]
            if not changed:
                return
            message = '4;' + ';'.join(changed)
        elif previous:
            message = '104;' + ';'.join(str(i) for i in range(FIRST, FIRST + WORDS * 4))
        else:
            return
        with open(tty, 'wb', buffering=0) as output:
            output.write(f'\033]{message}\033\\'.encode())
        last.seek(0)
        last.truncate()
        last.write('\n'.join(entries))


def overlay_lock(tty):
    return Path(os.environ['XDG_RUNTIME_DIR']) / ('jeebis-focus-popup-' + Path(tty).name)


def popup(tty, command):
    # display-popup waits until the popup closes. Client-specific suspension
    # also works when another client is looking at the same session.
    with overlay_lock(tty).open('a') as overlay:
        fcntl.flock(overlay, fcntl.LOCK_EX)
        clients()
        try:
            return subprocess.call(command)
        finally:
            fcntl.flock(overlay, fcntl.LOCK_UN)
            clients()


def showing_popup(tty):
    lock = overlay_lock(tty)
    if not lock.exists():
        return False
    with lock.open('r') as overlay:
        try:
            fcntl.flock(overlay, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def clients():
    # Several clients and editor pipes can update the same tty. Take the
    # snapshot after acquiring the lock so an old layout cannot win a race.
    lock = Path(os.environ['XDG_RUNTIME_DIR']) / 'jeebis-pane-focus.lock'
    with lock.open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        publish_clients()


def publish_clients():
    fields = ('client_tty', 'client_termname', 'client_termtype', 'client_control_mode',
              'client_width', 'client_height', 'client_cell_width', 'client_cell_height',
              'window_width', 'window_height', 'pane_left', 'pane_top', 'pane_width', 'pane_height',
              'window_offset_x', 'window_offset_y', 'status', 'status-position', '@jeebis-editor-view')
    fmt = '|'.join('#{' + name + '}' for name in fields)
    for line in tmux('list-clients', '-F', fmt).splitlines():
        tty, term, kind, control, *fields = line.split('|')
        if control == '1' or not (term == 'xterm-ghostty' or kind.startswith('ghostty ')):
            continue
        if showing_popup(tty):
            update(tty, (0, 0), (0, 0), (EMPTY,) * 4)
            continue
        w, h, cw, ch, ww, wh, x, y, pw, ph, ox, oy = [int(v or 0) for v in fields[:12]]
        status, position, view = fields[12:]
        lines = int(status) if status.isdecimal() else int(status != 'off')
        top = lines if position == 'top' else 0

        # Outside the visible viewport the shader clips implicitly. For panned
        # windows a negative coordinate cannot be encoded; clip before packing.
        def visible(box):
            a, b, c, d = box
            return max(0, a), max(top, b), min(w, max(0, c)), min(h, max(top, d))

        frame = rect(0, top, min(w, ww), min(h - lines, wh))
        px, py = x - ox, y - oy + top
        active = visible(rect(px, py, pw, ph))
        hx_frame, hx_active = editor_rects(view, px, py, pw, ph)
        outer = (EMPTY, EMPTY) if active == frame else (frame, active)
        nested = (visible(hx_frame), visible(hx_active)) if hx_frame != EMPTY else (EMPTY, EMPTY)
        try:
            update(tty, (w, h), (cw, ch), outer + nested)
        except (FileNotFoundError, PermissionError):
            continue  # A detached client can disappear after list-clients.


def editor(view):
    if os.environ.get('TMUX') and os.environ.get('TMUX_PANE'):
        tmux('set-option', '-p', '-t', os.environ['TMUX_PANE'], '@jeebis-editor-view', view)
        clients()
    elif os.environ.get('TERM_PROGRAM') == 'ghostty' or os.environ.get('TERM') == 'xterm-ghostty':
        with open('/dev/tty', 'rb', buffering=0) as tty:
            rows, cols, width, height = struct.unpack('4H', fcntl.ioctl(tty, termios.TIOCGWINSZ, bytes(8)))
            # /dev/tty is the controlling-terminal alias; use the actual PTY
            # for the per-surface cache key.
            tiocgdev = 0x80045432  # Linux _IOR('T', 0x32, unsigned int)
            device = struct.unpack('I', fcntl.ioctl(tty, tiocgdev, bytes(4)))[0]
        if rows and cols:
            update(f'/dev/pts/{os.minor(device)}', (cols, rows), (width // cols, height // rows),
                   (EMPTY, EMPTY, *editor_rects(view, 0, 0, cols, rows)))


if __name__ == '__main__':
    if sys.argv[1] == 'clients':
        clients()
    elif sys.argv[1] == 'detach' and len(sys.argv) == 3:
        try:
            if sys.argv[2] in tmux('list-clients', '-F', '#{client_tty}').splitlines():
                clients()
            else:
                update(sys.argv[2], (0, 0), (0, 0), (EMPTY,) * 4)
        except FileNotFoundError:
            pass
    elif sys.argv[1] == 'popup':
        sys.exit(popup(sys.argv[2], sys.argv[3:]))
    elif sys.argv[1] == 'watch':
        # The pipe closes when Helix exits, including an abnormal exit.
        try:
            for line in sys.stdin:
                editor(line.strip())
        finally:
            try:
                editor('')
            except (OSError, subprocess.CalledProcessError):
                pass  # Closing the final tmux pane may already have removed it.

"""Measure fixed window edges in frames from an isolated Xvfb/Niri session.

Use fixtures/niri-layout-animation-test.kdl. The script refuses a compositor
containing windows, launches only fixture clients, and leaves the user's session
alone. XGetImage samples a 1-pixel scanline at 100 Hz; timeline PNG rows show
successive animation frames, rather than merely the final arrangement.
"""
import argparse
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'packages/desktop'))
import niri_resize as resize


class XImage(C.Structure):
    _fields_ = [('width', C.c_int), ('height', C.c_int), ('xoffset', C.c_int),
                ('format', C.c_int), ('data', C.c_void_p), ('byte_order', C.c_int),
                ('bitmap_unit', C.c_int), ('bitmap_bit_order', C.c_int),
                ('bitmap_pad', C.c_int), ('depth', C.c_int),
                ('bytes_per_line', C.c_int), ('bits_per_pixel', C.c_int),
                ('red_mask', C.c_ulong), ('green_mask', C.c_ulong), ('blue_mask', C.c_ulong)]


class Scanline:
    def __init__(self, display, library, width):
        self.lib = C.CDLL(library or ctypes.util.find_library('X11'))
        self.lib.XOpenDisplay.argtypes = [C.c_char_p]
        self.lib.XOpenDisplay.restype = C.c_void_p
        self.lib.XDefaultRootWindow.argtypes = [C.c_void_p]
        self.lib.XDefaultRootWindow.restype = C.c_ulong
        self.lib.XGetImage.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int,
                                      C.c_uint, C.c_uint, C.c_ulong, C.c_int]
        self.lib.XGetImage.restype = C.POINTER(XImage)
        self.lib.XDestroyImage.argtypes = [C.POINTER(XImage)]
        self.lib.XCloseDisplay.argtypes = [C.c_void_p]
        self.display = self.lib.XOpenDisplay(display.encode())
        if not self.display:
            raise RuntimeError('Cannot open isolated X11 display')
        self.root = self.lib.XDefaultRootWindow(self.display)
        self.width = width

    def read(self):
        image = self.lib.XGetImage(self.display, self.root, 0, 400, self.width, 1,
                                   C.c_ulong(-1).value, 2)
        if not image:
            raise RuntimeError('Cannot capture test scanline')
        try:
            value = image.contents
            if (value.bits_per_pixel, value.byte_order, value.red_mask,
                value.green_mask, value.blue_mask) != (32, 0, 0xff0000, 0xff00, 0xff):
                raise RuntimeError('Expected little-endian 32-bit Xvfb RGB pixels')
            data = C.string_at(value.data, self.width * 4)
            row = bytearray(self.width * 3)
            row[0::3], row[1::3], row[2::3] = data[2::4], data[1::4], data[0::4]
            return bytes(row)
        finally:
            self.lib.XDestroyImage(image)

    def close(self):
        self.lib.XCloseDisplay(self.display)


def request(name, **arguments):
    return resize.request({'Action': {name: arguments}})


def windows():
    return sorted(resize.request('Windows')['Windows'], key=lambda w: w['title'])


def wait(predicate, description):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.025)
    raise AssertionError(description)


def proportion(identifier):
    w = next(w for w in windows() if w['id'] == identifier)
    return resize.percentage(w, resize.output_width(w))


def color_span(row, color):
    locations = []
    for i in range(len(row) // 3):
        rgb = row[i*3:i*3+3]
        primary = rgb[color]
        others = [rgb[j] for j in range(3) if j != color]
        if primary > 100 and primary > max(others) * 1.6:
            locations.append(i)
    return (locations[0], locations[-1]) if locations else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--socket', required=True)
    parser.add_argument('--wayland-display', required=True)
    parser.add_argument('--x-display', required=True)
    parser.add_argument('--x11-library')
    parser.add_argument('--client', required=True)
    parser.add_argument('--artifacts', required=True)
    parser.add_argument('--expect-failure', action='store_true')
    args = parser.parse_args()
    os.environ['NIRI_SOCKET'] = args.socket
    if windows():
        raise RuntimeError('Refusing to test a compositor that already contains windows')
    outputs = resize.request('Outputs')['Outputs']
    width = next(iter(outputs.values()))['logical']['width']
    grabber = Scanline(args.x_display, args.x11_library, width)
    client_env = dict(os.environ, WAYLAND_DISPLAY=args.wayland_display)
    artifacts = Path(args.artifacts)
    artifacts.mkdir(parents=True, exist_ok=True)
    clients = []
    reports = []
    watcher = None
    try:
        with tempfile.TemporaryDirectory(prefix='niri-anchor-state-') as directory:
            os.environ['XDG_RUNTIME_DIR'] = directory
            log = (artifacts/'watcher.log').open('w')
            watcher = subprocess.Popen([sys.executable, str(ROOT/'packages/desktop/niri-auto-width.py')], stderr=log)

            def new_client(prefix, color):
                client = subprocess.Popen([args.client, '1', prefix, str(color)], env=client_env)
                clients.append(client)
                return client

            def identifier(prefix):
                return next(w['id'] for w in windows() if w['title'].startswith(prefix))

            def focus(identifier):
                request('FocusWindow', id=identifier)
                time.sleep(1)

            def capture(name, color, side, trigger):
                rows, times = [], []
                start = time.monotonic()
                triggered = False
                while time.monotonic() - start < 1.65:
                    now = time.monotonic() - start
                    if now >= 0.2 and not triggered:
                        trigger()
                        triggered = True
                    rows.append(grabber.read())
                    times.append(time.monotonic() - start)
                    time.sleep(0.01)
                spans = [color_span(row, color) for row in rows]
                valid = [span for span in spans if span is not None]
                edge = 0 if side == 'left' else 1
                initial = valid[0][edge]
                deviation = max(abs(span[edge] - initial) for span in valid)
                widths = {span[1] - span[0] + 1 for span in valid}
                raw = artifacts/(name+'.rgb')
                raw.write_bytes(b''.join(rows))
                subprocess.run(['magick', '-size', f'{width}x{len(rows)}', '-depth', '8',
                                'rgb:'+str(raw), str(artifacts/(name+'.png'))], check=True)
                report = dict(case=name, edge=side, initial_edge=initial,
                              max_deviation_px=deviation, frames=len(rows),
                              distinct_widths=len(widths), missing_frames=len(rows)-len(valid),
                              final_width=(valid[-1][1]-valid[-1][0]+1),
                              passed=deviation <= 2 and len(widths) >= 5 and len(valid) == len(rows))
                reports.append(report)
                (artifacts/(name+'.frames.json')).write_text(json.dumps(list(zip(times,spans))))
                print(('PASS' if report['passed'] else 'FAIL'), name,
                      f'edge deviation={deviation}px, frames={len(rows)}, widths={len(widths)}', flush=True)
                time.sleep(0.4)

            new_client('anchor-a', 0)
            wait(lambda: len(windows()) == 1, 'initial test window')
            a = identifier('anchor-a')
            wait(lambda: abs(proportion(a)-100) < 0.2, 'initial full-width window')
            time.sleep(1)
            capture('new-right-keeps-old-left', 0, 'left', lambda: new_client('anchor-b', 1))
            wait(lambda: len(windows()) == 2, 'second test window')
            b = identifier('anchor-b')
            wait(lambda: abs(proportion(a)-50) < 0.2 and abs(proportion(b)-50) < 0.2, 'split widths')
            focus(b)
            resize.resize(toggle=True)
            wait(lambda: abs(proportion(b)-100) < 0.2, 'right window maximized')
            time.sleep(1)
            capture('rightmost-restore-keeps-right', 1, 'right', lambda: resize.resize(toggle=True))
            wait(lambda: abs(proportion(b)-50) < 0.2, 'right window restored')

            new_client('anchor-c', 2)
            wait(lambda: len(windows()) == 3, 'third test window')
            c = identifier('anchor-c')
            time.sleep(1)
            focus(a)
            focus(b)
            resize.resize(toggle=True)
            wait(lambda: abs(proportion(b)-100) < 0.2, 'middle maximized from left pair')
            time.sleep(1)
            # A left-hand peer means the middle window's right edge stays fixed.
            capture('middle-left-peer-keeps-right', 1, 'right', lambda: resize.resize(toggle=True))
            wait(lambda: abs(proportion(b)-50) < 0.2, 'middle restored to left pair')
            focus(c)
            focus(b)
            resize.resize(toggle=True)
            wait(lambda: abs(proportion(b)-100) < 0.2, 'middle maximized from right pair')
            time.sleep(1)
            capture('middle-right-peer-keeps-left', 1, 'left', lambda: resize.resize(toggle=True))
            (artifacts/'results.json').write_text(json.dumps(reports, indent=2)+'\n')
            failed = [r for r in reports if not r['passed']]
            if args.expect_failure:
                assert failed, 'Baseline unexpectedly passed all animation cases'
            else:
                assert not failed, failed
    finally:
        if watcher:
            watcher.terminate()
            watcher.wait(timeout=5)
        for client in clients:
            client.terminate()
            client.wait(timeout=5)
        grabber.close()


if __name__ == '__main__':
    main()

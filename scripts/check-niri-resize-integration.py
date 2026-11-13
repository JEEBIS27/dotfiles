"""Run against an ISOLATED, patched Niri containing only the three test clients.

Build fixtures/niri-layout-client.c with wayland-client and generated xdg-shell
protocol headers. Start an isolated Niri with gaps=4, no borders, animations off.
This script launches the client and watcher, checks real IPC widths/focus and
screenshots via ImageMagick, then closes only the processes it started.
"""
import argparse
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


def action(name, **args):
    return resize.request({'Action': {name: args}})


def windows():
    return sorted(resize.request('Windows')['Windows'], key=lambda w: w['title'])


def wait(predicate, description):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.04)
    raise AssertionError(description)


def values():
    return [resize.percentage(w, resize.output_width(w)) for w in windows()]


def expect(expected):
    wait(lambda: all(abs(a-b) < 0.2 for a, b in zip(values(), expected)),
         f'expected {expected}, got {values()}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--socket', required=True)
    parser.add_argument('--wayland-display', required=True)
    parser.add_argument('--client', required=True)
    parser.add_argument('--artifacts', required=True)
    args = parser.parse_args()
    os.environ['NIRI_SOCKET'] = args.socket
    if resize.request('Windows')['Windows']:
        raise RuntimeError('Refusing to test in a compositor that already has windows')
    client_env = dict(os.environ, WAYLAND_DISPLAY=args.wayland_display)
    artifacts = Path(args.artifacts)
    artifacts.mkdir(parents=True, exist_ok=True)
    reports = []
    client = subprocess.Popen([args.client], env=client_env)
    watcher = None
    with tempfile.TemporaryDirectory(prefix='niri-pair-state-') as directory:
        os.environ['XDG_RUNTIME_DIR'] = directory  # State only; IPC path is absolute.
        try:
            wait(lambda: len(windows()) == 3, 'three test windows did not open')
            ids = [w['id'] for w in windows()]

            def focus(index):
                action('FocusWindow', id=ids[index])
                wait(lambda: resize.request('FocusedWindow')['FocusedWindow']['id'] == ids[index], 'focus')
                time.sleep(0.15)

            def raw(index, value):
                action('SetWindowWidth', id=ids[index], change={'SetProportion': float(value)})

            def screenshot(name, visible, focused):
                path = artifacts / (name + '.png')
                path.unlink(missing_ok=True)
                action('ScreenshotScreen', write_to_disk=True, show_pointer=False, path=str(path))
                wait(path.exists, 'screenshot not saved')
                data = subprocess.check_output(['magick', str(path), '-crop', '0x1+0+400', '-depth', '8', 'rgb:-'])
                palette = [(204,51,51), (51,204,51), (51,51,204)]
                counts = {i: 0 for i in range(3)}
                background = 0
                for offset in range(0, len(data), 3):
                    pixel = tuple(data[offset:offset+3])
                    if pixel in palette:
                        counts[palette.index(pixel)] += 1
                    else:
                        background += 1
                # Fractional column placement can expose at most 1–2 pixels of a
                # neighboring tile. A half-screen gap must never be tolerated.
                assert {i for i, count in counts.items() if count > 2} == set(visible), (name, counts)
                assert background <= 16, (name, 'blank area', background)
                current = resize.request('FocusedWindow')['FocusedWindow']['id']
                assert current == ids[focused], (name, 'focus changed')
                sizes = windows()
                for i in visible:
                    assert abs(counts[i] - sizes[i]['layout']['tile_size'][0]) <= 2, (name, counts)
                reports.append(dict(case=name, widths=[round(v,2) for v in values()], visible=visible,
                                    focused=focused, background_pixels=background, screenshot=str(path)))
                print('PASS', name, reports[-1]['widths'], 'blank pixels:', background, flush=True)

            def reset(partner=0):
                nonlocal watcher
                if watcher:
                    watcher.terminate()
                    watcher.wait(timeout=5)
                for i in range(3):
                    raw(i, 50)
                expect([50,50,50])
                resize.lock_path().with_suffix('.json').unlink(missing_ok=True)
                focus(partner)
                watcher = subprocess.Popen([sys.executable, str(ROOT/'packages/desktop/niri-auto-width.py')],
                                           stdout=subprocess.DEVNULL, stderr=log)
                time.sleep(0.3)
                focus(1)
                time.sleep(0.15)

            with (artifacts/'watcher.log').open('w') as log:
                reset()
                screenshot('initial-left-pair', [0,1], 1)
                raw(1,40)
                expect([60,40,50])
                time.sleep(0.15)
                screenshot('middle-40', [0,1], 1)
                focus(2)
                expect([60,40,60])
                time.sleep(0.15)
                screenshot('focus-right-keeps-middle-40', [1,2], 2)
                raw(2,70)
                expect([60,30,70])
                focus(1)
                focus(0)
                expect([70,30,70])
                time.sleep(0.15)
                screenshot('return-left-keeps-middle-30', [0,1], 0)

                reset()
                focus(2)
                raw(2,100)
                expect([50,50,100])
                time.sleep(0.4)
                raw(2,50)
                expect([50,50,50])
                time.sleep(0.5)
                screenshot('rightmost-100-to-50', [1,2], 2)

                for peer, name in [(0,'left'), (2,'right')]:
                    reset(peer)
                    raw(1,100)
                    expect([50,100,50])
                    time.sleep(0.4)
                    raw(1,50)
                    expect([50,50,50])
                    time.sleep(0.5)
                    screenshot('middle-100-to-50-restores-'+name, sorted([1,peer]), 1)

                reset()
                raw(1,100)
                expect([50,100,50])
                raw(1,50)
                expect([50,50,50])
                time.sleep(0.5)
                screenshot('fast-middle-full-width-round-trip', [0,1], 1)

                reset()
                resize.resize(-10)
                expect([60,40,50])
                original_pixels = windows()[1]['layout']['window_size'][0]
                for _ in range(5):
                    resize.resize(toggle=True)
                    expect([60,100,50])
                    resize.resize(toggle=True)
                    expect([60,40,50])
                    assert windows()[1]['layout']['window_size'][0] == original_pixels, 'round-trip width drift'
                time.sleep(0.4)
                screenshot('keyboard-full-width-restores-original-40', [0,1], 1)
            (artifacts/'results.json').write_text(json.dumps(reports, indent=2)+'\n')
        finally:
            if watcher:
                watcher.terminate()
                watcher.wait(timeout=5)
            client.terminate()
            client.wait(timeout=5)


if __name__ == '__main__':
    main()

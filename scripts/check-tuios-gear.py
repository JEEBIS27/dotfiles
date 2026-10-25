#!/usr/bin/env python3
"""Exercise the patched native menu in a real PTY and save screen artifacts.

Requires pyte (install into a temporary venv). Uses only a private XDG tree and
private daemon; never attaches to or terminates the desktop's sessions.
"""
import argparse
import codecs
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import time
import tomllib
import pyte

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tuios', required=True)
parser.add_argument('--artifacts', type=Path, required=True)
a = parser.parse_args()
binary = str(Path(a.tuios).resolve())
repo = Path(__file__).resolve().parent.parent
a.artifacts.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tuios-gear-test-') as temp:
    root = Path(temp)
    for name in ['home', 'config/tuios', 'state', 'cache', 'runtime', 'data', 'bin']:
        (root/name).mkdir(parents=True)
    (root/'runtime').chmod(0o700)
    conf = root/'config/tuios'
    (conf/'config.toml').write_text('include = ["defaults.toml", "local.toml"]\n')
    defaults = (repo/'files/tuios/config.toml').read_text().replace('preferred_shell = "zsh"', 'preferred_shell = "/bin/sh"')
    (conf/'defaults.toml').write_text(defaults)
    (conf/'config.toml').chmod(0o444)
    (conf/'defaults.toml').chmod(0o444)
    (conf/'local.toml').touch()
    editor = root/'bin/editor'
    editor.write_text('#!/bin/sh\nprintf "%s" "$1" > "$HOME/editor-opened"\nsleep 30\n')
    editor.chmod(0o755)
    env = {k:v for k,v in os.environ.items() if not k.startswith(('TUIOS', 'TMUX', 'HERDR')) and k != 'NO_COLOR'}
    env.update(HOME=str(root/'home'), XDG_CONFIG_HOME=str(root/'config'),
               XDG_STATE_HOME=str(root/'state'), XDG_CACHE_HOME=str(root/'cache'),
               XDG_RUNTIME_DIR=str(root/'runtime'), XDG_DATA_HOME=str(root/'data'),
               PATH=f"{root/'bin'}:{repo/'files/desktop/helpers'}:{os.environ['PATH']}",
               SHELL='/bin/sh', TERM='xterm-256color', COLORTERM='truecolor', EDITOR=str(editor))
    env.pop('VISUAL', None)
    screen = pyte.Screen(120, 40)
    stream = pyte.Stream(screen)
    decode = codecs.getincrementaldecoder('utf-8')('replace')
    raw = bytearray()
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(temp)
        os.execvpe(binary, [binary, 'new', 'gear-test'], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 1200, 800))

    def pump(seconds=.2):
        deadline = time.monotonic()+seconds
        while time.monotonic() < deadline:
            if select.select([fd], [], [], min(.05, max(0, deadline-time.monotonic())))[0]:
                data = os.read(fd, 65536)
                if not data:
                    raise AssertionError('UI exited unexpectedly')
                raw.extend(data)
                stream.feed(decode.decode(data))
                if b'\x1b[6n' in data:
                    os.write(fd, b'\x1b[1;1R')
                if b'\x1b[c' in data:
                    os.write(fd, b'\x1b[?62;4;6;22c')

    def text():
        return '\n'.join(screen.display)

    def wait(check):
        until = time.monotonic()+8
        while time.monotonic() < until:
            pump()
            if check():
                return
        raise AssertionError(text())

    def keys(data):
        os.write(fd, data)
        pump(.3)

    def click(x=119, y=1):
        keys(f'\x1b[<0;{x};{y}M\x1b[<0;{x};{y}m'.encode())

    def save(name):
        (a.artifacts/(name+'.txt')).write_text(text())

    def run(*args):
        p = subprocess.run([binary, *args], env=env, capture_output=True, text=True, timeout=15)
        assert p.returncode == 0, (args, p.stdout, p.stderr)
        return p.stdout

    try:
        wait(lambda: '' in screen.display[0][-3:])
        assert screen.buffer[0][118].bg == 'default', 'Gear must not set an opaque background'
        save('01-overlay')
        click()
        wait(lambda: 'Edit configuration' in text())
        assert 'Diagnostics' not in text()
        save('02-menu')
        keys(b'\r')
        wait(lambda: 'Dim unfocused' in text())
        save('03-display')
        keys(b'j'*9+b'\r\x1537\r')
        wait(lambda: tomllib.loads((conf/'local.toml').read_text()).get('appearance', {}).get('dim_unfocused') == 37)
        keys(b'\x1b[D')
        wait(lambda: tomllib.loads((conf/'local.toml').read_text())['appearance']['dim_unfocused'] == 36)
        keys(b'\x1b[C')
        wait(lambda: tomllib.loads((conf/'local.toml').read_text())['appearance']['dim_unfocused'] == 37)
        save('04-dim-37')
        keys(b'\x1b')
        run('set-config', 'dockbar_position', 'top', '-s', 'gear-test')
        pump(1)
        assert text().count('') == 1, text()
        click()
        wait(lambda: 'Edit configuration' in text())
        save('05-gear-on-bar')
        # Enter the Tools group and verify the actual configured shortcut hint.
        keys(b'j'*6+b'\r')
        wait(lambda: 'Yazi' in text() and 'Inbox' in text())
        assert 'alt+y' in text().lower() or 'Alt+y' in text(), text()
        save('06-tools')
        keys(b'\x1b')
        click()
        keys(b'j'*4+b'\r')
        wait(lambda: 'BSP tiling' in text())
        keys(b'j'*2+b'\r')
        wait(lambda: 'Scrolling ✓' in text())
        save('07-scrolling-layout')
        keys(b'\x1b')
        click()
        keys(b'j'*2+b'\r')
        wait(lambda: 'Split right' in text())
        before = json.loads(run('list-windows', '-s', 'gear-test', '--json'))['total']
        keys(b'j\r')
        wait(lambda: json.loads(run('list-windows', '-s', 'gear-test', '--json'))['total'] == before+1)
        click()
        keys(b'j'*2+b'\r')
        keys(b'\x1b[Fk\r')
        wait(lambda: 'Stop processes?' in text())
        save('08-close-confirmation')
        keys(b'\x1b')
        click()
        keys(b'j'*9+b'\r')
        wait(lambda: (root/'home/editor-opened').exists())
        assert (root/'home/editor-opened').read_text() == str(conf/'local.toml')
        assert (conf/'defaults.toml').read_text() == defaults
        assert (conf/'config.toml').read_text() == 'include = ["defaults.toml", "local.toml"]\n'
        (a.artifacts/'local.toml').write_text((conf/'local.toml').read_text())
        print('PASS: gear overlay, mouse menu, display controls, numeric edit, 1% steps, writable override, bar relocation, live shortcut hints, scrolling layout, real pane split, close confirmation, config editor')
    finally:
        (a.artifacts/'terminal.ansi').write_bytes(raw)
        save('last-screen')
        subprocess.run([binary, 'kill-server'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        os.close(fd)
        os.waitpid(pid, 0)

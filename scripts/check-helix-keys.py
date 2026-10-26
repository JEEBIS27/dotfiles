#!/usr/bin/env python3
"""Exercise unified Helix keys in private PTYs. Requires pyte in a test venv."""
import argparse
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


class TerminalScreen(pyte.Screen):
    # Termina emits DEC private cursor queries that pyte does not implement.
    def report_device_status(self, mode, private=False):
        if not private:
            return super().report_device_status(mode)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--helix', default=shutil.which('hx'))
parser.add_argument('--tuios', help='Test through a private TUIOS daemon as well')
a = parser.parse_args()
assert a.helix, 'Pass --helix /path/to/hx'
if a.tuios:
    a.tuios = str(Path(shutil.which(a.tuios) or a.tuios).resolve())
repo = Path(__file__).resolve().parent.parent
config = tomllib.loads((repo/'files/helix/config.toml').read_text())
for mode in ['normal', 'select', 'insert']:
    keys = config['keys'][mode]
    assert keys['C-s'] == ':write'
    assert keys['C-S-s'] == ('commit_undo_checkpoint' if mode == 'insert' else 'save_selection')
    assert all(value == 'no_op' for key, value in keys.items() if key.startswith('A-'))
    if mode != 'insert':
        menu = keys['space']['m']
        assert menu[';'] == 'flip_selections' and menu['d'] == 'delete_selection_noyank'
        assert menu['e'] == ('extend_parent_node_end' if mode == 'select' else 'move_parent_node_end')

with tempfile.TemporaryDirectory(prefix='helix-keys-') as temp:
    root = Path(temp)
    conf = root/'config/helix'
    (conf/'themes').mkdir(parents=True)
    shutil.copy2(repo/'files/helix/config.toml', conf/'config.toml')
    (conf/'themes/Desktop.toml').write_text('inherits = "default"\n')
    (root/'runtime').mkdir(mode=0o700)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('TUIOS', 'HERDR', 'TMUX'))}
    env.update(HOME=str(root), XDG_CONFIG_HOME=str(root/'config'),
               XDG_CACHE_HOME=str(root/'cache'), XDG_RUNTIME_DIR=str(root/'runtime'),
               XDG_STATE_HOME=str(root/'state'), XDG_DATA_HOME=str(root/'data'),
               SHELL='/bin/sh', TERM='xterm-256color')
    if a.tuios:
        (root/'config/tuios').mkdir()
        (root/'config/tuios/config.toml').write_text(
            (repo/'files/tuios/config.toml').read_text().replace('preferred_shell = "zsh"', 'preferred_shell = "/bin/sh"'))

    def tuios(*arguments):
        p = subprocess.run([a.tuios, *arguments], env=env, capture_output=True, text=True, timeout=30)
        assert p.returncode == 0, (arguments, p.stdout, p.stderr)
        return p.stdout

    class Editor:
        def __init__(self, name, text):
            self.path = root/(name+'.txt')
            self.path.write_text(text)
            self.fd, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 36, 120, 0, 0))
            self.screen = TerminalScreen(120, 36)
            self.stream = pyte.ByteStream(self.screen)
            self.output = b''
            command = [a.helix, str(self.path)]
            if a.tuios:
                tuios('new', name, '--detach')
                first = json.loads(tuios('list-windows', '-s', name, '--json'))['windows'][0]['window_id']
                tuios('new-window', 'helix', '-s', name, '--', *command)
                tuios('close-window', '-s', name, first)
                command = [a.tuios, 'attach', name]
            self.process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env)
            os.close(slave)
            self.pump(2 if a.tuios else 1)

        def pump(self, duration=.15):
            deadline = time.monotonic()+duration
            while time.monotonic() < deadline:
                if not select.select([self.fd], [], [], .025)[0]:
                    continue
                try:
                    data = os.read(self.fd, 65536)
                except OSError:
                    break
                self.output += data
                self.stream.feed(data)
                if b'\x1b[?6n' in data:
                    os.write(self.fd, b'\x1b[?1;1R')
                if b'\x1b[6n' in data:
                    os.write(self.fd, b'\x1b[1;1R')
                if b'\x1b[c' in data:
                    os.write(self.fd, b'\x1b[?1;2c')

        def keys(self, packet):
            os.write(self.fd, packet)
            self.pump()

        def save(self):
            self.keys(b'\x13')
            return self.path.read_text()

        def close(self):
            self.keys(b':quit-all!\r')
            if a.tuios and self.process.poll() is None:
                self.keys(b'\x1bd')
            if self.process.poll() is None:
                self.process.terminate()
            self.process.wait(timeout=5)
            assert b'Bad config' not in self.output and b'Failed to parse' not in self.output

    editors = []
    try:
        e = Editor('undo', '')
        editors.append(e)
        e.keys(b'iaaa')
        e.keys(b'\x1b[83;6u')  # Shifted Unicode S with Ctrl+Shift
        assert e.path.read_text() == '', 'Shifted save unexpectedly wrote the file'
        e.keys(b'bbb')
        e.keys(b'\x1b')
        e.keys(b'u')
        assert e.save() == 'aaa\n', 'Undo checkpoint rescue failed'
        e.close()

        e = Editor('jump', 'zero\none\ntwo\nthree\n')
        editors.append(e)
        e.keys(b'ggj')
        e.keys(b'\x1b[83;6u')
        e.keys(b'jj')
        e.keys(b'\x1b[83;6u')
        e.keys(b'\x0f')
        e.keys(b'iMARK')
        e.keys(b'\x1b')
        assert e.save().splitlines()[1] == 'MARKone', 'Jumplist rescue failed'
        e.close()

        e = Editor('flip', 'abcd\n')
        editors.append(e)
        e.keys(b'vll')
        e.keys(b' m;')
        e.keys(b';iZ')
        e.keys(b'\x1b')
        assert e.save() == 'Zabcd\n', 'Selection flip rescue failed'
        e.close()

        e = Editor('noyank', 'abcd\n')
        editors.append(e)
        e.keys(b'yl')
        e.keys(b' md')
        e.keys(b'p')
        assert e.save() == 'acad\n', 'No-yank deletion changed the register'
        e.close()

        e = Editor('words', '')
        editors.append(e)
        e.keys(b'iaa bb cc')
        e.keys(b'\x1b[127;5u')
        e.keys(b'\x1b')
        assert e.save().strip() == 'aa bb', 'Ctrl+Backspace rescue failed'
        e.keys(b'ggi')
        e.keys(b'\x1b[3;5~')
        e.keys(b'\x1b')
        result = e.save()
        assert result.strip() == 'bb', ('Ctrl+Delete rescue failed', result)
        e.close()

        e = Editor('layout', 'abcd\n')
        editors.append(e)
        e.keys(b'\x1b[13;5u')
        e.keys(b'l')  # right view cursor differs from the original left view
        e.keys(b'\x08')  # Ctrl+H must return to the left cursor
        e.keys(b'iXY')
        e.keys(b'\x1b[3;6~')
        e.keys(b'\x1b')
        result = e.save()
        assert result == 'XY\n', ('Split/focus or Ctrl+Shift+Delete rescue failed', result)
        e.keys(b'\x17')
        assert e.process.poll() is None and 'NOR' in ' '.join(e.screen.display), 'Closing one split closed both'
        e.close()
    finally:
        for e in editors:
            if e.process.poll() is None:
                e.process.terminate()
                e.process.wait(timeout=5)
            os.close(e.fd)
        if a.tuios:
            tuios('kill-server')
print('PASS: save, undo checkpoint, jumplist, selection flip, no-yank register, word deletion, split/focus, insert rescue, close')

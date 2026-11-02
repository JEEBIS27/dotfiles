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
        assert keys['del'] == 'delete_selection_noyank'
        assert keys['ret'] == 'open_below' and keys['S-ret'] == 'open_above'
        assert all(keys[key] == keys['g'][key] for key in ('w', 'b', 'W', 'B'))
        assert keys['u'] == 'undo' and keys['U'] == 'redo'
        assert keys['g']['k'] == ('goto_file_start' if mode == 'normal' else 'extend_to_file_start')
        assert keys['g']['j'] == ('goto_file_end' if mode == 'normal' else 'extend_to_file_end')
        assert keys['space'] == 'no_op'
        assert all(keys[key] == 'no_op' for key in ('n', 'N'))
        assert keys['e'] == ':jeebis-end-word' and keys['E'] == ':jeebis-end-WORD'
        assert keys['G'][';'] == 'flip_selections'
        assert keys['G']['b'] == 'extend_prev_word_start'
        assert keys['G']['w'] == 'extend_next_word_start'
        assert keys['C-g']['/'] == 'global_search'
        assert keys['C-S-g']['r'] == 'rename_symbol'

with tempfile.TemporaryDirectory(prefix='helix-keys-') as temp:
    root = Path(temp)
    conf = root/'config/helix'
    (conf/'themes').mkdir(parents=True)
    shutil.copy2(repo/'files/helix/config.toml', conf/'config.toml')
    motions = (repo/'files/helix/steel/init.scm').read_text().split(';; BEGIN cursor motions\n')[1].split(';; END cursor motions')[0]
    (conf/'init.scm').write_text(motions)

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
            (repo/'files/tuios/config.toml').read_text().replace('preferred_shell = "@fish@"', 'preferred_shell = "/bin/sh"'))

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
        e.keys(b'\x1a')
        result = e.save()
        assert result == 'aaa\n', ('Undo checkpoint rescue failed', result, '\n'.join(e.screen.display))
        e.close()

        e = Editor('jump', 'zero\none\ntwo\nthree\n')
        editors.append(e)
        e.keys(b'gkj')
        e.keys(b'\x1b[83;6u')
        e.keys(b'jj')
        e.keys(b'\x1b[83;6u')
        e.keys(b'gub')
        e.keys(b'iMARK')
        e.keys(b'\x1b')
        assert e.save().splitlines()[1] == 'MARKone', 'Jumplist rescue failed'
        e.close()

        e = Editor('flip', 'abcd\n')
        editors.append(e)
        e.keys(b'vll')
        e.keys(b'G;')
        e.keys(b';iZ')
        e.keys(b'\x1b')
        assert e.save() == 'Zabcd\n', 'Selection flip rescue failed'
        e.close()

        e = Editor('noyank', 'abcd\n')
        editors.append(e)
        e.keys(b'yl')
        e.keys(b'd')
        e.keys(b'p')
        assert e.save() == 'acad\n', 'No-yank deletion changed the register'
        e.close()

        for mode, select_keys, expected in [('normal', b'', 'acad\n'), ('select', b'vl', 'ada\n')]:
            e = Editor('delete-'+mode, 'abcd\n')
            editors.append(e)
            e.keys(b'yl'+select_keys)
            e.keys(b'\x1b[3~')
            e.keys(b'p')
            assert e.save() == expected, ('Delete changed the yank register', mode)
            e.close()

        for mode, select_keys in [('normal', b''), ('select', b'v')]:
            e = Editor('enter-'+mode, 'original\n')
            editors.append(e)
            e.keys(select_keys+b'\r')
            e.keys(b'below')
            e.keys(b'\x1b')
            e.keys(b'gk'+select_keys)
            e.keys(b'\x1b[13;2u')
            e.keys(b'above')
            e.keys(b'\x1b')
            assert e.save() == 'above\noriginal\nbelow\n', ('Enter/Shift+Enter failed', mode)
            e.close()

        e = Editor('file-bounds', 'first\nmiddle\nlast\n')
        editors.append(e)
        e.keys(b'gj')
        e.keys(b'iEND')
        e.keys(b'\x1b')
        e.save()
        e.keys(b'gk')
        e.keys(b'iTOP')
        e.keys(b'\x1b')
        assert e.save() == 'TOPfirst\nmiddle\nlast\nEND\n', 'g k/j file bounds failed'
        e.keys(b'u')
        result=e.save()
        assert result == 'first\nmiddle\nlast\nEND\n', ('u undo alias failed', result)
        e.keys(b'U')
        assert e.save() == 'TOPfirst\nmiddle\nlast\nEND\n', 'U redo alias failed'
        e.close()

        # Unit selection and endpoint operations compose independently.
        for name, text, packets, expected in [
            ('word', 'alpha beta.foo gamma\n', [b'w', b'e', b'aX'], 'alpha betaX.foo gamma\n'),
            ('WORD', 'alpha beta.foo gamma\n', [b'W', b'e', b'aX'], 'alpha beta.fooX gamma\n'),
            ('WORD-E', 'alpha beta.foo gamma\n', [b'W', b'E', b'aX'], 'alpha beta.fooX gamma\n'),
            ('word-E', 'alpha beta.foo gamma\n', [b'w', b'E', b'aX'], 'alpha betaX.foo gamma\n'),
            ('single-char-E', 'alpha x.foo gamma\n', [b'w', b'E', b'aX'], 'alpha xX.foo gamma\n'),
            ('word-unicode', 'alpha 日本語.foo gamma\n', [b'w', b'e', b'aX'], 'alpha 日本語X.foo gamma\n'),
            ('WORD-unicode', 'alpha 日本語.foo gamma\n', [b'W', b'E', b'aX'], 'alpha 日本語.fooX gamma\n'),
            ('word-combining', 'alpha café.foo gamma\n', [b'w', b'e', b'aX'], 'alpha caféX.foo gamma\n'),
            ('WORD-back', 'alpha beta.foo gamma\n', [b'2W', b'B', b'e', b'aX'], 'alpha beta.fooX gamma\n'),
            ('word-alone', 'alpha.foo beta\n', [b'e', b'aX'], 'alphaX.foo beta\n'),
            ('WORD-alone', 'alpha.foo beta\n', [b'E', b'aX'], 'alpha.fooX beta\n'),
            ('selection-end', 'alpha beta\n', [b'vll', b'e', b'aX'], 'alpXha beta\n'),
            ('reverse-end', 'alpha beta\n', [b'vll', b'G;', b'e', b'aX'], 'alpXha beta\n'),
            ('word-back', 'alpha beta gamma\n', [b'w', b'b', b'iX'], 'Xalpha beta gamma\n'),
        ]:
            e = Editor(name, text)
            editors.append(e)
            for packet in packets:
                e.keys(packet)
            e.keys(b'\x1b')
            result = e.save()
            assert result == expected, (name, result, '\n'.join(e.screen.display))
            e.close()

        e = Editor('multi-end', 'alpha beta\n')
        editors.append(e)
        e.keys(b'\x01')  # Select all, then split into two selected targets.
        e.keys(b'G/alpha|beta\r')
        e.keys(b'e')
        e.keys(b'aX')
        e.keys(b'\x1b')
        assert e.save() == 'alphaX betaX\n', 'Endpoint operation lost multicursors'
        e.close()

        e = Editor('prefix-count', 'alpha beta gamma delta\n')
        editors.append(e)
        e.keys(b'2gw')
        e.keys(b'iX')
        e.keys(b'\x1b')
        assert e.save() == 'alpha beta Xgamma delta\n', 'Count affected the cursor adjustment'
        e.close()

        e = Editor('prefix-code', '1\n')
        editors.append(e)
        e.keys(b'\x1b[71;6u')  # Ctrl+Shift+G, then number, next.
        e.keys(b'nw')
        result=e.save()
        assert result == '2\n', ('Ctrl+Shift+G number increment failed', result, '\n'.join(e.screen.display))
        e.keys(b'\x1b[71;6u')
        e.keys(b'nb')
        assert e.save() == '1\n', 'Ctrl+Shift+G number decrement failed'
        e.close()

        e = Editor('words', '')
        editors.append(e)
        e.keys(b'iaa bb cc')
        e.keys(b'\x1b[127;5u')
        e.keys(b'\x1b')
        assert e.save().strip() == 'aa bb', 'Ctrl+Backspace rescue failed'
        e.keys(b'gki')
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
print('PASS: directional prefixes, word movement/extension, save, undo checkpoint, jumplist, selection flip, no-yank register, word deletion, split/focus, insert rescue, close')

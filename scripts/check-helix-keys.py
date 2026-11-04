#!/usr/bin/env python3
"""Exercise unified Helix keys in private PTYs. Requires pyte in a test venv."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import pty
import re
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
parser.add_argument('--boolswitcher', type=Path, default=Path.home()/'.local/share/jeebis-helix-steel/cogs/boolswitcher.hx')
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
        assert all(keys[key] == keys['g'][key] for key in ('w', 'e', 'W', 'E'))
        assert keys['u'] == 'undo' and keys['U'] == 'redo'
        assert keys['g']['k'] == (':jeebis-smooth-file-start' if mode == 'normal' else ':jeebis-smooth-extend-file-start')
        assert keys['g']['j'] == (':jeebis-smooth-file-end' if mode == 'normal' else ':jeebis-smooth-extend-file-end')
        assert keys['space'] == 'command_mode'
        assert keys['n']['f'] == ':jeebis-target call next' and keys['N']['f'] == ':jeebis-target call prev'
        assert keys['b'] == ':jeebis-word-start' and keys['B'] == ':jeebis-WORD-start'
        assert keys['i'] == 'insert_mode' and keys['I'] == 'append_mode'
        assert keys['D'] == 'delete_selection' and keys['C'] == 'change_selection'
        assert keys['C-a'] == 'select_all' and keys['V'] == ':jeebis-line-mode'
        assert keys['q'] == ':write-quit' and keys['Q'] == ':quit!'
        assert keys['G'][';'] == 'flip_selections'
        assert keys['G']['e'] == 'extend_prev_word_start'
        assert keys['G']['w'] == 'extend_next_word_start'
        assert keys['C-g']['/'] == 'global_search'
        assert keys['C-S-g']['r'] == 'rename_symbol'

with tempfile.TemporaryDirectory(prefix='helix-keys-') as temp:
    root = Path(temp)
    conf = root/'config/helix'
    (conf/'themes').mkdir(parents=True)
    shutil.copy2(repo/'files/helix/config.toml', conf/'config.toml')
    motions = (repo/'files/helix/steel/init.scm').read_text().split(';; BEGIN cursor motions\n')[1].split(';; END cursor motions')[0]
    smooth = (repo/'files/helix/steel/init.scm').read_text().split(';; BEGIN smooth scrolling\n')[1].split(';; END smooth scrolling')[0]
    (conf/'init.scm').write_text(motions + '\n' + smooth + '\n(define (test-half-down) (motion.half_page_down))\n(define (test-file-start) (motion.goto_file_start) (motion.align_view_top))\n(define (test-file-end) (motion.goto_file_end) (motion.align_view_bottom))\n(define (test-extend-end) (motion.extend_to_file_end))\n')

    (conf/'themes/Desktop.toml').write_text('inherits = "default"\n')
    cogs = root/'data/jeebis-helix-steel/cogs'
    cogs.mkdir(parents=True)
    (cogs/'boolswitcher.hx').symlink_to(a.boolswitcher.resolve())
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
            self.scroll_frames = []
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
                marker = re.search(r'ROW_(\d{4})', '\n'.join(self.screen.display))
                if marker and (not self.scroll_frames or self.scroll_frames[-1] != int(marker[1])):
                    self.scroll_frames.append(int(marker[1]))
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
        e = Editor('smooth-scroll', ''.join(f'ROW_{i:04d}\n' for i in range(200)))
        editors.append(e)
        def scroll_top():
            return int(re.search(r'ROW_(\d{4})', '\n'.join(e.screen.display))[1])
        e.keys(b':test-half-down\r')
        half = scroll_top()
        assert half > 5, ('Native half-page baseline failed', half)
        e.keys(b'gk')
        e.scroll_frames.clear()
        os.write(e.fd, b'\x1b[6~')
        e.pump(.45)
        assert scroll_top() == half, ('Smooth page distance differs from native half-page', half, scroll_top(), e.scroll_frames, '\n'.join(e.screen.display))
        assert len(set(e.scroll_frames)) >= 4, ('No intermediate animation frames', e.scroll_frames)
        e.keys(b'gk')
        os.write(e.fd, b'\x1b[6~')
        e.pump(.035)
        os.write(e.fd, b'\x1b[6~')
        e.pump(.45)
        assert scroll_top() == 2*half, ('Repeated pages lost distance', scroll_top(), half)
        e.keys(b'gk')
        os.write(e.fd, b'\x1b[6~')
        e.pump(.035)
        os.write(e.fd, b'\x1b[5~')
        e.pump(.45)
        assert scroll_top() == 0, ('Reversing did not cancel accumulated distance', scroll_top())
        os.write(e.fd, b'\x1b[6~')
        e.pump(.035)
        e.keys(b'l')
        stopped = scroll_top()
        e.pump(.3)
        assert scroll_top() == stopped, 'Scrolling continued after cursor input'
        e.keys(b'gk')
        os.write(e.fd, b'\x1b[6~')
        e.pump(.025)
        os.write(e.fd, b'2')
        e.pump(.35)
        e.keys(b'l')
        e.keys(b'iX')
        e.keys(b'\x1b')
        assert 'ROXW_' in e.save(), 'Animation clobbered a numeric prefix'
        e.close()

        file_text = ''.join(f'ROW_{i:04d}\n' for i in range(400))
        e = Editor('smooth-file', file_text)
        editors.append(e)
        def file_top():
            return int(re.search(r'ROW_(\d{4})', '\n'.join(e.screen.display))[1])
        e.keys(b':test-file-end\r')
        end_top = file_top()
        assert end_top > 300, ('Native EOF fixture did not scroll', '\n'.join(e.screen.display))
        e.keys(b':test-file-start\r')
        e.scroll_frames.clear()
        e.keys(b'gj')
        e.pump(.25)
        assert file_top() == end_top, ('Animated EOF differs from native', file_top(), end_top)
        assert len(set(e.scroll_frames)) >= 4, ('File end was not animated', e.scroll_frames)
        e.keys(b'Nu')
        assert file_top() == 0, 'Intermediate frames polluted the jumplist'
        e.keys(b':test-file-end\r')
        e.scroll_frames.clear()
        e.keys(b'gk')
        e.pump(.25)
        assert file_top() == 0 and len(set(e.scroll_frames)) >= 4, 'File start was not animated'
        e.keys(b':test-file-end\r')
        os.write(e.fd, b'gk')
        e.pump(.025)
        e.keys(b'iTOP')
        e.keys(b'\x1b')
        assert e.save() == 'TOP'+file_text, 'Fast edit acted on an intermediate file position'
        e.keys(b'u')
        e.keys(b':test-file-start\r')
        e.keys(b':test-extend-end\r')
        e.keys(b'd')
        expected_selection = e.save()
        e.keys(b'u')
        e.keys(b':test-file-start\r')
        e.keys(b'Gj')
        e.pump(.25)
        e.keys(b'd')
        assert e.save() == expected_selection, 'G j did not preserve native selection bounds'
        e.close()

        e = Editor('smooth-large-file', ''.join(f'LARGE_{i:06d}\n' for i in range(20000)))
        editors.append(e)
        started = time.monotonic()
        e.keys(b'gj')
        e.pump(.25)
        e.keys(b'iEND')
        e.keys(b'\x1b')
        assert e.save().endswith('END\n'), 'Large-file jump did not reach EOF'
        assert time.monotonic()-started < 2, 'File animation scales with line count'
        e.close()

        for mode, enter in [('normal', b''), ('select', b'v')]:
            e = Editor('line-select-'+mode, 'one\ntwo\nthree\n')
            editors.append(e)
            if enter:
                e.keys(enter)
            e.keys(b'x')
            e.keys(b'd')
            assert e.save() == 'two\nthree\n', ('x line selection failed', mode)
            e.keys(b'u')
            e.keys(b'j')
            if enter:
                e.keys(enter)
            e.keys(b'X')
            e.keys(b'd')
            assert e.save() == 'one\nthree\n', ('X line selection failed', mode)
            e.close()

        e = Editor('keybinding-search', 'one\n')
        editors.append(e)
        e.keys(b'\x10')
        e.pump(.4)
        e.keys(b'select_line_below')
        assert 'select_line_below' in '\n'.join(e.screen.display) and 'bindings' in '\n'.join(e.screen.display), ('Ctrl+P keybinding search missing', '\n'.join(e.screen.display))
        e.keys(b'\x15')
        e.keys(b'%bindings x')
        assert 'select_line_below' in '\n'.join(e.screen.display), 'Binding-column search missing'
        e.keys(b'\x1b')
        e.close()

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
        e.keys(b'gk')
        e.keys(b'j')
        e.keys(b'\x1b[83;6u')
        e.keys(b'jj')
        e.keys(b'\x1b[83;6u')
        e.keys(b'Nu')
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
            e.keys(b'gk')
            if select_keys:
                e.keys(select_keys)
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

        # Direction-first units, containing units, and start/insert compose.
        for name, text, packets, expected in [
            ('word', 'alpha beta.foo gamma\n', [b'w', b'IX'], 'alpha betaX.foo gamma\n'),
            ('WORD', 'alpha beta.foo gamma\n', [b'W', b'IX'], 'alpha beta.fooX gamma\n'),
            ('word-unicode', 'alpha 日本語.foo gamma\n', [b'w', b'IX'], 'alpha 日本語X.foo gamma\n'),
            ('word-combining', 'alpha café.foo gamma\n', [b'w', b'IX'], 'alpha caféX.foo gamma\n'),
            ('WORD-back', 'alpha beta.foo gamma\n', [b'2W', b'E', b'IX'], 'alpha beta.fooX gamma\n'),
            ('word-back', 'alpha beta gamma\n', [b'w', b'e', b'iX'], 'Xalpha beta gamma\n'),
            ('word-start', 'alpha beta gamma\n', [b'w', b'b', b'iX'], 'alpha Xbeta gamma\n'),
            ('WORD-start', 'alpha beta.foo gamma\n', [b'W', b'B', b'iX'], 'alpha Xbeta.foo gamma\n'),
            ('containing', 'SUPER next\n', [b'2l', b't', b'd'], ' next\n'),
        ]:
            e = Editor(name, text)
            editors.append(e)
            for packet in packets:
                e.keys(packet)
            e.keys(b'\x1b')
            result = e.save()
            assert result == expected, (name, result, '\n'.join(e.screen.display))
            e.close()

        e = Editor('multi-start', 'alpha beta\n')
        editors.append(e)
        e.keys(b'\x01')
        e.keys(b'G/alpha|beta\r')
        e.keys(b'b')
        e.keys(b'iX')
        e.keys(b'\x1b')
        assert e.save() == 'Xalpha Xbeta\n', 'Word-start operation lost multicursors'
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
        e.keys(b'ne')
        assert e.save() == '1\n', 'Ctrl+Shift+G number decrement failed'
        e.close()

        e = Editor('words', '')
        editors.append(e)
        e.keys(b'iaa bb cc')
        e.keys(b'\x1b[127;5u')
        e.keys(b'\x1b')
        assert e.save().strip() == 'aa bb', 'Ctrl+Backspace rescue failed'
        e.keys(b'gk')
        e.keys(b'i')
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

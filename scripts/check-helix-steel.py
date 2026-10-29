#!/usr/bin/env python3
"""Exercise Steel startup and user commands in an isolated PTY (requires pyte)."""
import argparse
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import shutil
import struct
import subprocess
import tempfile
import termios
import time
import pyte


class TerminalScreen(pyte.Screen):
    # Termina emits DEC private cursor queries that pyte does not implement.
    def report_device_status(self, mode, private=False):
        if not private:
            return super().report_device_status(mode)

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--helix', required=True)
p.add_argument('--plugins', required=True)
p.add_argument('--native', required=True)
p.add_argument('--fish', default=shutil.which('fish'))
p.add_argument('--yazi', default=shutil.which('yazi'))
a = p.parse_args()
repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='helix-steel-test-') as temporary:
    root = Path(temporary)
    conf = root/'config/helix'
    (conf/'themes').mkdir(parents=True)
    (root/'runtime').mkdir(mode=0o700)
    home = root/'data/jeebis-helix-steel'
    home.mkdir(parents=True)
    (home/'cogs').mkdir()
    for plugin in Path(a.plugins).resolve().iterdir():
        (home/'cogs'/plugin.name).symlink_to(plugin)
    yazi_config = root/'config/yazi'
    (yazi_config/'plugins/helix-open.yazi').mkdir(parents=True)
    shutil.copy(repo/'files/yazi/keymap.toml', yazi_config/'keymap.toml')
    shutil.copy(repo/'files/yazi/plugins/helix-open.yazi/main.lua',
                yazi_config/'plugins/helix-open.yazi/main.lua')
    (home/'native').symlink_to(Path(a.native).resolve()/'lib')
    shutil.copy(repo/'files/helix/config.toml', conf/'config.toml')
    (conf/'themes/Desktop.toml').write_text('inherits = "default"\n"ui.background" = { fg = "#a9b1d6" }\n"ui.text" = { fg = "#a9b1d6" }\n')
    (conf/'helix.scm').write_text('')
    (root/'config/fish').mkdir()
    shutil.copy(repo/'files/fish/prompt.fish', root/'config/fish/config.fish')
    init = (repo/'files/helix/steel/init.scm').read_text().replace('@fish@', a.fish)
    # Prove the last statement ran: an earlier require failure must fail the test.
    init += '\n(require (prefix-in test.hx. "helix/static.scm"))\n(define (test-only) (test.hx.wonly))\n'
    init += f"""\n(call-with-output-file "{root}/loaded" (lambda (p) (write-string "ok" p)) #:exists 'truncate)\n"""
    (conf/'init.scm').write_text(init)
    binary = root/'bin'
    binary.mkdir()
    helper = (repo/'files/desktop/helpers/jeebis-helix-yazi').read_text().replace('@yazi@', a.yazi)
    (binary/'jeebis-helix-yazi').write_text(helper)
    (binary/'jeebis-helix-yazi').chmod(0o700)
    sample = root/'original.txt'
    sample.write_text('alpha beta gamma\nsecond line\n')
    env = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root/'config'),
               XDG_DATA_HOME=str(root/'data'), XDG_CACHE_HOME=str(root/'cache'),
               XDG_STATE_HOME=str(root/'state'), XDG_RUNTIME_DIR=str(root/'runtime'),
               HELIX_STEEL_CONFIG=str(conf), STEEL_HOME=str(home), HELIX_YAZI_FILE=str(root/'runtime/yazi-state'),
               TERM='xterm-256color', PATH=str(binary)+':'+os.environ['PATH'])
    for key in list(env):
        if key.startswith(('TUIOS', 'HERDR', 'TMUX')):
            del env[key]
    fd, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 140, 0, 0))
    screen = TerminalScreen(140, 40)
    stream = pyte.ByteStream(screen)
    output = bytearray()
    def child_setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    child = subprocess.Popen([a.fish, '--no-config', '--interactive'],
                             stdin=slave, stdout=slave, stderr=slave, env=env,
                             cwd=root, preexec_fn=child_setup)
    os.close(slave)
    def pump(seconds=.3):
        until = time.monotonic()+seconds
        while time.monotonic() < until:
            if not select.select([fd], [], [], .025)[0]:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            output.extend(data)
            stream.feed(data)
            if b'\x1b[?6n' in data:
                os.write(fd, b'\x1b[?1;1R')
            if b'\x1b[6n' in data:
                os.write(fd, b'\x1b[1;1R')
            if b'\x1b[?u' in data:
                os.write(fd, b'\x1b[?0u')
            if b'\x1b[0c' in data:
                os.write(fd, b'\x1b[?1;2c')
            if b'\x1b[c' in data:
                os.write(fd, b'\x1b[?1;2c')
    def send(packet, seconds=.3):
        os.write(fd, packet)
        pump(seconds)
    def command(text):
        send(b'\x1b')
        send((':'+text+'\r').encode(), .5)
        assert 'no such command' not in '\n'.join(screen.display).lower(), text
        assert 'unbound' not in '\n'.join(screen.display).lower(), text
    # Find the actual editor below the interactive shell / supervisor.
    def find_editor(parent):
        children = subprocess.run(['pgrep', '-P', str(parent)], capture_output=True, text=True).stdout.split()
        for pid in map(int, children):
            if Path(f'/proc/{pid}/exe').resolve().name == 'hx':
                return pid
            found = find_editor(pid)
            if found:
                return found
    try:
        pump(1)
        send(b"function fish_prompt; echo HELIX_TEST_SHELL_PROMPT; end\n", .5)
        send((shlex.join([a.helix, '--log', str(root/'helix.log'), str(sample)])+'\n').encode(), 5)
        assert (root/'loaded').exists(), '\n'.join(screen.display)
        print('startup OK', flush=True)
        for name in ['flash', 'recentf-open-files', 'microscope-file-explorer']:
            command(name)
            send(b'\x1b')
        command('notify Steel-test')
        command('moka-disable!')
        command('moka-enable!')
        command('vsplit')
        command('zoom')
        command('zoom')
        command('matte')
        command('matte')
        print('extension commands OK', flush=True)
        # Ctrl+T opens a centered floating terminal and preserves its shell.
        send(b'\x14', 2)
        def floating_bounds():
            corners = [(x, y) for y, line in enumerate(screen.display)
                       for x, char in enumerate(line) if char == '╭']
            assert len(corners) == 1, '\n'.join(screen.display)
            left, top = corners[0]
            right = screen.display[top].index('╮', left)
            bottom = next(y for y in range(top + 1, screen.lines)
                          if screen.display[y][left] == '╰')
            assert abs(left - (screen.columns - right - 1)) <= 1
            assert abs(top - (screen.lines - bottom - 1)) <= 2
            assert .80 < (right-left+1)/screen.columns < .90
            assert .70 < (bottom-top+1)/screen.lines < .80
            return left, top, right, bottom
        floating_bounds()
        def terminal_command(packet):
            # Give the embedded terminal event loop time between keystrokes.
            for byte in packet:
                send(bytes([byte]), .04)
            pump(1)
        terminal_command(b"set -g HELIX_TERM_TEST retained; printf 'STEEL_PTY_OK\\n'\r")
        assert 'STEEL_PTY_OK' in '\n'.join(screen.display), '\n'.join(screen.display)
        # Truecolor foreground/background and a reset after explicit colors.
        terminal_command(b"printf '\\033[38;2;218;218;218;48;2;48;48;48mRGB_MARK\\033[0m RESET_MARK\\n'\r")
        matches = [(x, y) for y, line in enumerate(screen.display)
                   for x in range(screen.columns) if line[x:].startswith('RGB_MARK RESET_MARK')]
        assert matches, '\n'.join(screen.display)
        x, y = matches[-1]
        assert screen.buffer[y][x].fg == 'dadada', screen.buffer[y][x]
        assert screen.buffer[y][x].bg == '303030', screen.buffer[y][x]
        assert screen.buffer[y][x+9].fg == 'a9b1d6', screen.buffer[y][x+9]
        assert screen.buffer[y][x+9].bg == 'default', screen.buffer[y][x+9]
        send(b'\x14', .5)
        assert '╭' not in '\n'.join(screen.display), 'Ctrl+T did not hide terminal'
        send(b'\x14', .5)
        floating_bounds()
        terminal_command(b'echo SHELL_$HELIX_TERM_TEST\r')
        assert 'SHELL_retained' in '\n'.join(screen.display), 'terminal shell was restarted'
        # Recompute placement and PTY dimensions when the outer terminal shrinks.
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 100, 0, 0))
        screen.resize(lines=30, columns=100)
        pump(1)
        floating_bounds()
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 140, 0, 0))
        screen.resize(lines=40, columns=140)
        pump(1)
        floating_bounds()
        send(b'\x14', .5)
        command('kill-active-terminal')
        print('terminal OK: floating, Ctrl+T toggle, retained shell, truecolor/reset, resize', flush=True)
        send(b'A unsaved\x1b')
        os.kill(find_editor(child.pid), signal.SIGUSR1)
        pump(2)
        prompt_start = len(output)
        send(b'\x19', .5)
        pump(3)
        assert b'HELIX_TEST_SHELL_PROMPT' not in output[prompt_start:], 'fish reclaimed the terminal during Yazi'
        send(b'q', 2)
        assert 'unsaved' in '\n'.join(screen.display), '\n'.join(screen.display)
        assert sample.read_text() == 'alpha beta gamma\nsecond line\n'
        # Real Yazi chooser: only one candidate, with a deliberately awkward name.
        chosen = root/'space 日本語 "quoted".txt'
        chosen.write_text('chosen-content\n')
        prompt_start = len(output)
        command('yazi')
        pump(3)
        assert b'HELIX_TEST_SHELL_PROMPT' not in output[prompt_start:], 'fish reclaimed the terminal during Yazi'
        # Choose through Yazi's search so this is independent of directory ordering.
        send(b'fspace', .5)
        send(b'\r', 1)
        send(b'\r', 1)
        assert 'chosen-content' in '\n'.join(screen.display), '\n'.join(screen.display)
        assert sample.read_text() == 'alpha beta gamma\nsecond line\n'
        send(b'A saved\x1b')
        send(b'\x13', .5)
        assert 'saved' in chosen.read_text(), chosen.read_text()
        # Distinct buffers on both sides prove the split direction and focus.
        for packet, back, label in [(b'\x1b[13;5u', b'\x08', 'vertical'),
                                     (b'\x1b[13;6u', b'\x0b', 'horizontal')]:
            command('test-only')
            command('open '+str(sample))
            command('yazi')
            pump(3)
            send(b'fspace', .5)
            send(b'\r', .5)
            send(packet, 1)
            assert 'chosen-content' in '\n'.join(screen.display), label
            # Ctrl+H/K are the shared move-to-left/up bindings.
            send(back)
            send(b'A split-'+label.encode()+b'\x1b')
            send(b'\x13', .5)
            assert 'split-'+label in sample.read_text(), (label, sample.read_text())
            assert 'split-'+label not in chosen.read_text(), chosen.read_text()
        command('quit-all!')
        send(b'exit\n')
        child.wait(timeout=5)
        log = (root/'helix.log').read_text()
        assert 'UnboundIdentifier' not in log and 'Error loading' not in log, log[-6000:]
        print('PASS: interactive fish job control, Ctrl+Y, seven extensions, terminal command, zoom, Yazi chooser, original buffer unchanged, Yazi vertical/horizontal split')
    except BaseException:
        Path('/tmp/helix-steel-test.log').write_text((root/'helix.log').read_text() if (root/'helix.log').exists() else '')
        Path('/tmp/helix-steel-test.screen').write_text('\n'.join(screen.display))
        Path('/tmp/helix-steel-test.raw').write_bytes(output)
        raise
    finally:
        editor_pid = find_editor(child.pid)
        if editor_pid:
            try:
                editor_group = os.getpgid(editor_pid)
                os.killpg(editor_group, signal.SIGCONT)
                os.killpg(editor_group, signal.SIGTERM)
            except ProcessLookupError:
                pass
        if child.poll() is None:
            child.send_signal(signal.SIGCONT)
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        os.close(fd)

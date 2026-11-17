"""Exercise the generated config through a real attached PTY, without user sessions."""
import argparse
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import tempfile
import termios
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--config', required=True)
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='tmux-workflow-') as directory:
    cmd = ['tmux', '-S', directory + '/socket']
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 140, 0, 0))

    def tmux(*argv):
        return subprocess.check_output([*cmd, *argv], text=True).strip()

    def drain():
        while select.select([master], [], [], 0)[0]:
            os.read(master, 65536)

    def keys(value, pause=0.25):
        os.write(master, value)
        time.sleep(pause)
        drain()

    def until(check):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            drain()
            if check():
                return
            time.sleep(0.05)
        raise AssertionError('tmux did not reach the expected state')

    try:
        tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'test', '-n', 'first', '/bin/sh')
        tmux('source-file', str(Path(args.config).resolve()))
        first = tmux('display-message', '-p', '#{window_id}')
        second = tmux('new-window', '-P', '-F', '#{window_id}', '-n', 'second', '/bin/sh')
        tmux('select-window', '-t', first)
        client = subprocess.Popen([*cmd, 'attach', '-t', 'test'], stdin=slave,
            stdout=slave, stderr=slave, env=dict(os.environ, TERM='xterm-256color'),
            start_new_session=True)
        os.close(slave)
        until(lambda: tmux('list-clients') != '')
        keys(b'\x1bs')
        assert tmux('display-message', '-p', '#{pane_mode}') == 'tree-mode'
        keys(b'\x1b[B')  # Highlight the other window, without selecting it.
        # The shell-launched helper opens its prompt asynchronously.
        keys(b'r', pause=1)
        keys(b'\x15renamed "quote"; literal\r')
        until(lambda: tmux('display-message', '-p', '-t', second, '#{window_name}') == 'renamed "quote"; literal')
        assert tmux('display-message', '-p', '-t', first, '#{window_name}') == 'first'
        assert tmux('display-message', '-p', '#{pane_mode}') == 'tree-mode'
        keys(b'R', pause=1)
        keys(b'\x15renamed-session\r')
        until(lambda: tmux('display-message', '-p', '#{session_name}') == 'renamed-session')
        # Delete acts on the highlighted window, with cancel and confirmation.
        keys(b'\x1b[3~')
        keys(b'n')
        assert second in tmux('list-windows', '-F', '#{window_id}').splitlines()
        keys(b'\x1b[3~')
        keys(b'y')
        until(lambda: second not in tmux('list-windows', '-F', '#{window_id}').splitlines())
        assert first in tmux('list-windows', '-F', '#{window_id}').splitlines()
        assert tmux('display-message', '-p', '#{pane_mode}') == 'tree-mode'
        keys(b'q')
        # Session parent deletion uses the native selected target as well.
        tmux('new-session', '-d', '-s', 'delete-me', '/bin/sh')
        keys(b'\x1bS')
        keys(b'\x1b[F')
        keys(b'\x1b[3~')
        keys(b'\r')  # The default choice is Cancel.
        assert 'delete-me' in tmux('list-sessions', '-F', '#{session_name}').splitlines()
        keys(b'\x1b[3~')
        keys(b'\x1b')
        assert 'delete-me' in tmux('list-sessions', '-F', '#{session_name}').splitlines()
        keys(b'\x1b[3~')
        keys(b'y')
        until(lambda: 'delete-me' not in tmux('list-sessions', '-F', '#{session_name}').splitlines())
        assert 'renamed-session' in tmux('list-sessions', '-F', '#{session_name}').splitlines()
        keys(b'q')
        keys(b'\x1bt')
        until(lambda: '__popup_$0:1' in tmux('list-sessions', '-F', '#{session_name}:#{session_attached}'))
        keys(b'\x1bt')
        until(lambda: '__popup_$0:0' in tmux('list-sessions', '-F', '#{session_name}:#{session_attached}'))
        keys(b'\x1bt')
        until(lambda: '__popup_$0:1' in tmux('list-sessions', '-F', '#{session_name}:#{session_attached}'))
        keys(b'\x1bt')
        # Outside the chooser, r/R must still reach the application literally.
        keys(b'printf rR-forwarded\\n\r')
        assert 'rR-forwarded' in tmux('capture-pane', '-p')
        assert tmux('show-options', '-gv', 'status') == 'on'
        # Resolve the real foreground tool/cwd through the recording PTY.
        repo = Path(directory) / 'repo'
        (repo / 'nested').mkdir(parents=True)
        pane = tmux('new-window', '-P', '-F', '#{pane_id}', '-c', str(repo),
                    "script -q -c 'cd nested; sleep 60' /dev/null")
        config = Path(args.config).read_text()
        helper = re.search(r'#\((/nix/store/[^ ]+/bin/jeebis-tmux-status) directory', config).group(1)
        def context(action):
            return subprocess.check_output([helper, action, pane, '180'], text=True,
                env=dict(os.environ, TMUX=f'{directory}/socket,1,0'))
        until(lambda: context('tool').strip() == 'sleep')
        assert 'nested' in context('directory'), context('directory')
        print('PASS: selected-window/session rename, quoted names, Delete confirm/cancel, popup toggle, literal input, one-row status, foreground tool/cwd')
    finally:
        subprocess.run([*cmd, 'kill-server'], check=False, capture_output=True)
        os.close(master)

#!/usr/bin/env python3
"""Exercise TUIOS session/key routing in a private HOME and PTY; no desktop apply."""
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
import threading
import time
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tuios', default='tuios')
a = parser.parse_args()
tuios = shutil.which(a.tuios)
if not tuios:
    parser.error('tuios 0.10.1 must be available')
repo = Path(__file__).resolve().parent.parent
for path in [repo/'files/rio/config.toml', repo/'files/tuios/config.toml']:
    with path.open('rb') as f:
        tomllib.load(f)

with tempfile.TemporaryDirectory(prefix='dotfiles-terminal-') as tmp:
    root = Path(tmp)
    for d in ['home', 'config/tuios', 'runtime', 'state', 'cache', 'data', 'bin']:
        (root/d).mkdir(parents=True, exist_ok=True)
    (root/'runtime').chmod(0o700)
    (root/'bin/tuios').symlink_to(tuios)
    config = (repo/'files/tuios/config.toml').read_text()
    # Test shell must not source any of the user's startup files.
    (root/'config/tuios/config.toml').write_text(config.replace('preferred_shell = "zsh"', 'preferred_shell = "/bin/sh"'))
    env = {k: v for k, v in os.environ.items() if not k.startswith(('TUIOS', 'HERDR', 'TMUX'))}
    env.update(HOME=str(root/'home'), XDG_CONFIG_HOME=str(root/'config'),
               XDG_RUNTIME_DIR=str(root/'runtime'), XDG_STATE_HOME=str(root/'state'),
               XDG_CACHE_HOME=str(root/'cache'), XDG_DATA_HOME=str(root/'data'),
               SHELL='/bin/sh', TERM='xterm-256color', COLORTERM='truecolor',
               PATH=f"{root/'bin'}:{repo/'files/desktop/helpers'}:{os.environ['PATH']}")

    def run(*args):
        p = subprocess.run([tuios, *args], env=env, capture_output=True, text=True, timeout=30)
        assert p.returncode == 0, (args, p.stdout, p.stderr)
        return p.stdout

    def windows(session='test'):
        return json.loads(run('list-windows', '-s', session, '--json'))

    def eventually(check):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if check():
                return
            time.sleep(.05)
        raise AssertionError('TUIOS did not reach expected state')

    # Check launcher argument boundaries without opening a graphical terminal.
    (root/'bin/rio').write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
    (root/'bin/rio').chmod(0o755)
    got = json.loads(subprocess.check_output([str(repo/'files/desktop/helpers/jeebis-terminal'),
        '--app-id=org.test.rio', '--cwd', tmp, '--', '/bin/echo', 'a b;$(literal)'], env=env, text=True))
    assert got == ['--app-id', 'org.test.rio', '--working-dir', tmp, '-e', 'jeebis-tuios', '/bin/echo', 'a b;$(literal)'], got
    # Normal startup must retain the package's Rio identity and configured shell.
    plain = json.loads(subprocess.check_output([str(repo/'files/desktop/helpers/jeebis-terminal'),
        '--cwd', tmp], env=env, text=True))
    assert plain == ['--working-dir', tmp], plain
    # Render every managed palette through the real shared theme generator.
    for palette in (repo/'files/desktop/themes').glob('*.toml'):
        theme = root/palette.stem
        theme.mkdir()
        shutil.copyfile(palette, theme/'colors.toml')
        subprocess.run(['bash', str(repo/'packages/desktop/render-theme.sh'),
                        str(repo/'files/desktop/templates'), str(theme)], env=env, check=True,
                       capture_output=True, text=True)
        with (theme/'rio.toml').open('rb') as f:
            colors = tomllib.load(f)['colors']
        assert len(colors) == 21 and all(v.startswith('#') and len(v) == 7 for v in colors.values()), colors
    pid = fd = None
    stop = threading.Event()
    try:
        doctor = json.loads(run('keybinds', 'doctor', '--json'))
        for field in ['collisions', 'key_problems', 'command_problems', 'copy_mode_problems']:
            assert not doctor.get(field), (field, doctor.get(field))
        taken = {b['key'] for b in doctor['terminal_mode_swallowed']}
        for key in ['ctrl+p', 'ctrl+n', 'ctrl+f', 'ctrl+y', 'ctrl+v', 'shift+pgup', 'shift+pgdown', 'shift+enter']:
            assert key not in taken, key
        run('new', 'other', '--detach', '--cwd', tmp)
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(tmp)
            os.execvpe(tuios, [tuios, 'new', 'test'], env)
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 140, 1400, 800))

        def drain():
            while not stop.is_set():
                try:
                    if select.select([fd], [], [], .1)[0]:
                        data = os.read(fd, 65536)
                        if not data:
                            break
                        if b'\x1b[6n' in data:
                            os.write(fd, b'\x1b[1;1R')
                        if b'\x1b[c' in data:
                            os.write(fd, b'\x1b[?62;4;6;22c')
                except OSError:
                    break

        thread = threading.Thread(target=drain, daemon=True)
        thread.start()
        # Allow terminal negotiation before exercising screen-dependent verbs.
        time.sleep(2)
        eventually(lambda: windows()['total'] == 1)
        assert windows()['windows'][0]['cwd'] == tmp
        run('split-window', 'vertical', '-s', 'test')
        assert windows()['total'] == 2
        os.write(fd, b'\x1b\r')  # Alt+Enter, legacy encoding
        eventually(lambda: windows()['total'] == 3)
        os.write(fd, b'\x1b[110;4u')  # Alt+Shift+N, Kitty encoding
        eventually(lambda: windows()['current_workspace'] == 2)
        os.write(fd, b'\x1bn')
        eventually(lambda: windows()['total'] == 5)
        assert windows('other')['total'] == 1
        run('new-window', 'probe', '-s', 'test', '--', '/bin/sh', '-c', 'printf terminal-marker; sleep 60')
        window_id = windows()['focused_window_id']
        eventually(lambda: 'terminal-marker' in run('capture-pane', '-s', 'test', '-w', window_id))
        ids = {w['window_id'] for w in windows()['windows']}
        os.write(fd, b'\x1bd')
        eventually(lambda: not next(s for s in json.loads(run('ls', '--json')) if s['name'] == 'test')['attached'])
        assert {w['window_id'] for w in windows()['windows']} == ids
        os.waitpid(pid, 0)
        pid = None
        stop.set()
        thread.join(timeout=1)
        os.close(fd)
        fd = None
        # Reattach explicitly and confirm that no pane was replaced.
        stop.clear()
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe(tuios, [tuios, 'attach', 'test'], env)
        thread = threading.Thread(target=drain, daemon=True)
        thread.start()
        eventually(lambda: next(s for s in json.loads(run('ls', '--json')) if s['name'] == 'test')['attached'])
        assert {w['window_id'] for w in windows()['windows']} == ids
        time.sleep(.3)
        os.write(fd, b'\x1bd')
        eventually(lambda: not next(s for s in json.loads(run('ls', '--json')) if s['name'] == 'test')['attached'])
        os.waitpid(pid, 0)
        pid = None
        stop.set()
        thread.join(timeout=1)
        os.close(fd)
        fd = None
        # A noninteractive launcher fails at attach, after preparing its session.
        # The command itself must still be isolated and have only one pane.
        p = subprocess.run([str(repo/'files/desktop/helpers/jeebis-tuios'), '/bin/sh', '-c',
                            'printf launcher-marker; sleep 60'], env=env, capture_output=True, text=True, timeout=20)
        assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
        session = next(s['name'] for s in json.loads(run('ls', '--json')) if s['name'].startswith('rio-'))
        assert windows(session)['total'] == 1
        window_id = windows(session)['focused_window_id']
        eventually(lambda: 'launcher-marker' in run('capture-pane', '-s', session, '-w', window_id))
        # The worktree popup uses the native CLI without a nested client.
        git_repo = root/'repository'
        git_repo.mkdir()
        subprocess.run(['git', 'init', '-q', '--initial-branch=main', str(git_repo)], check=True, env=env)
        subprocess.run(['git', '-C', str(git_repo), '-c', 'user.name=Terminal Test',
                        '-c', 'user.email=terminal@example.invalid', '-c', 'commit.gpgsign=false',
                        'commit', '-q', '--allow-empty', '-m', 'fixture'], check=True, env=env)
        p = subprocess.run([str(repo/'files/desktop/helpers/jeebis-tuios-worktree')],
                           input='feature-terminal\n\n', env=env, cwd=git_repo,
                           capture_output=True, text=True, timeout=30)
        assert p.returncode == 0 and 'Created. Select the session' in p.stdout, (p.stdout, p.stderr)
        assert 'feature-terminal' in subprocess.check_output(['git', '-C', str(git_repo), 'worktree', 'list'], text=True)
        print('PASS: TOML, theme generation, binding diagnostics, application key forwarding, PTY split/workspace/new-window/detach/reattach, session isolation, command launcher, worktree popup')
    finally:
        stop.set()
        if fd is not None:
            os.close(fd)
        if pid is not None:
            os.waitpid(pid, 0)
        run('kill-server')

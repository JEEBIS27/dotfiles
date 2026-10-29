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
    (root/'config/tuios/config.toml').write_text(config.replace('preferred_shell = "@fish@"', 'preferred_shell = "/bin/sh"'))
    env = {k: v for k, v in os.environ.items() if not k.startswith(('TUIOS', 'HERDR', 'TMUX'))}
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
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
    (root/'bin/rio').write_text('#!/usr/bin/env python3\nimport json,os,sys\nassert \"NO_COLOR\" not in os.environ, \"KGP image IDs require colours\"\nprint(json.dumps(sys.argv[1:]))\n')
    (root/'bin/rio').chmod(0o755)
    got = json.loads(subprocess.check_output([str(repo/'files/desktop/helpers/jeebis-terminal'),
        '--app-id=org.test.rio', '--cwd', tmp, '--', '/bin/echo', 'a b;$(literal)'], env=dict(env, NO_COLOR='1'), text=True))
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
        # Reopen via the normal launcher and confirm it resumes with every pane.
        stop.clear()
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe(str(repo/'files/desktop/helpers/jeebis-tuios'), ['jeebis-tuios', '--attach', 'test'], env)
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
        # An application owns one fixed session and one pane across launches.
        helper = str(repo/'files/desktop/helpers/jeebis-tuios')
        for _ in range(2):
            p = subprocess.run([helper, '/bin/sh', '-c', 'printf launcher-marker; sleep 60'],
                               env=env, capture_output=True, text=True, timeout=20)
            assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
        assert windows('main')['total'] == 2
        window_id = next(w['window_id'] for w in windows('main')['windows'] if w['workspace'] == 6)
        eventually(lambda: 'launcher-marker' in run('capture-pane', '-s', 'main', '-w', window_id))
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
        assert p.returncode == 0 and 'Created. Select the workspace' in p.stdout, (p.stdout, p.stderr)
        assert 'feature-terminal' in subprocess.check_output(['git', '-C', str(git_repo), 'worktree', 'list'], text=True)
        # The first command launch against a stopped, empty daemon creates
        # exactly one session and replaces only its placeholder shell.
        for session in json.loads(run('ls', '--json')):
            run('kill-session', session['name'])
        run('kill-server')
        for n in range(2):
            p = subprocess.run([helper, '/bin/sh', '-c', 'sleep 60'],
                               env=env, capture_output=True, text=True, timeout=20)
            assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
            sessions = json.loads(run('ls', '--json'))
            assert len(sessions) == 1 and sessions[0]['name'] == 'main', sessions
            assert windows('main')['total'] == 2
        # Model desktop workspace changes without touching the real compositor.
        mock = root/'bin/hyprctl'
        mock.write_text('#!/usr/bin/env python3\nimport json,os\nprint(json.dumps({"name":os.environ["TEST_WORKSPACE"]}))\n')
        mock.chmod(0o755)
        for workspace in ['1', '2', '1', 'special:notes', 'named notes']:
            p = subprocess.run([helper, '/bin/sh', '-c', 'sleep 60'],
                env=dict(env, HYPRLAND_INSTANCE_SIGNATURE='fixture', TEST_WORKSPACE=workspace, JEEBIS_TUIOS_ROLE='yazi'),
                capture_output=True, text=True, timeout=20)
            assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
        assert windows('desktop-1')['total'] == 2
        assert windows('desktop-2')['total'] == 2
        sessions = json.loads(run('ls', '--json'))
        assert len(sessions) == 5, sessions  # main + 4 distinct desktop workspaces
        for role in ['codex', 'yazi', 'codex']:
            p = subprocess.run([helper, '/bin/sh', '-c', 'sleep 60'],
                env=dict(env, HYPRLAND_INSTANCE_SIGNATURE='fixture', TEST_WORKSPACE='1', JEEBIS_TUIOS_ROLE=role),
                capture_output=True, text=True, timeout=20)
            assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
        role_windows = windows('desktop-1')['windows']
        assert sorted(w['workspace'] for w in role_windows) == [1,2,3], role_windows
        labels = {w['workspace']: w['name'] for w in json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']}
        assert labels[1] == 'Terminal' and labels[2] == 'Yazi' and labels[3] == 'Codex', labels
        run('call', 'set-workspace-name', json.dumps({'session':'desktop-1','workspace':3,'name':'My Codex'}))
        subprocess.run([helper, '/bin/sh', '-c', 'sleep 60'],
            env=dict(env, HYPRLAND_INSTANCE_SIGNATURE='fixture', TEST_WORKSPACE='1', JEEBIS_TUIOS_ROLE='codex'),
            capture_output=True, text=True, timeout=20)
        labels = {w['workspace']: w['name'] for w in json.loads(run('list-workspaces','-s','desktop-1','--json'))['workspaces']}
        assert labels[3] == 'My Codex', labels
        sessions = json.loads(run('ls', '--json'))
        before = {s['name']: s['window_count'] for s in sessions}
        p = subprocess.run([helper], env=dict(env, HYPRLAND_INSTANCE_SIGNATURE='fixture', TEST_WORKSPACE='1', JEEBIS_TUIOS_ROLE='yazi'),
                           capture_output=True, text=True, timeout=20)
        assert p.returncode != 0 and 'interactive terminal' in p.stderr, p.stderr
        assert {s['name']: s['window_count'] for s in json.loads(run('ls', '--json'))} == before
        stop.clear()
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe(helper, [helper, '/bin/sh', '-c', 'sleep 60'],
                       dict(env, HYPRLAND_INSTANCE_SIGNATURE='fixture', TEST_WORKSPACE='99', JEEBIS_TUIOS_ROLE='desktop'))
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 140, 1400, 800))
        thread = threading.Thread(target=drain, daemon=True)
        thread.start()
        eventually(lambda: any(s['name'] == 'desktop-99' and s['attached'] for s in json.loads(run('ls','--json'))))
        time.sleep(.4)
        run('new-window', 'survivor', '-s', 'desktop-99', '--no-focus', '--', '/bin/sh', '-c', 'sleep 60')
        eventually(lambda: windows('desktop-99')['total'] == 2)
        os.write(fd, b'\x1bw')  # Alt+W closes only the focused pane.
        eventually(lambda: windows('desktop-99')['total'] == 1)
        assert any(s['name'] == 'desktop-99' for s in json.loads(run('ls','--json')))
        os.write(fd, b'\x1bW')  # Alt+Shift+W ends the session and client.
        eventually(lambda: not any(s['name'] == 'desktop-99' for s in json.loads(run('ls','--json'))))
        os.waitpid(pid, 0)
        pid = None
        stop.set()
        thread.join(timeout=1)
        os.close(fd)
        fd = None
        print('PASS: TOML, theme generation, binding diagnostics, application key forwarding, PTY split/workspace/new-window/detach/reattach, session isolation, command launcher, worktree popup')
    finally:
        stop.set()
        if fd is not None:
            os.close(fd)
        if pid is not None:
            os.waitpid(pid, 0)
        run('kill-server')

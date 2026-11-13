"""Regression checks for tmux's SHELL and default-shell -c invocation."""
import argparse
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', required=True, type=Path)
    args = parser.parse_args()
    wrapper = str(args.wrapper.resolve())
    with tempfile.TemporaryDirectory(prefix='recorded-fish-check-') as directory:
        root = Path(directory)
        (root / 'fish').mkdir()
        (root / 'runtime').mkdir(mode=0o700)
        (root / 'bin').mkdir()
        clipboard = root / 'bin/wl-copy'
        clipboard.write_text('#!/bin/sh\ncat > "$TEST_CLIPBOARD"\n')
        clipboard.chmod(0o755)
        (root / 'fish/config.fish').write_text(
            f'source {ROOT}/files/fish/functions.fish\n'
            f'source {ROOT}/files/fish/prompt.fish\n'
            'function fish_prompt\n printf "READY> "\nend\n')
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('JEEBIS_OUTPUT_', 'GHOSTTY_'))}
        env.update(SHELL=wrapper, XDG_CONFIG_HOME=directory,
                   XDG_RUNTIME_DIR=str(root / 'runtime'), TERM='dumb',
                   PATH=str(root / 'bin') + ':' + os.environ['PATH'],
                   TEST_CLIPBOARD=str(root / 'clipboard'))
        result = subprocess.run([wrapper, '-c', "printf 'command-mode-ok'"],
                                env=env, capture_output=True, timeout=10, check=True)
        assert result.stdout == b'command-mode-ok', result
        master, slave = pty.openpty()
        process = subprocess.Popen([wrapper], stdin=slave, stdout=slave, stderr=slave, env=env)
        os.close(slave)
        def ready(completed=True):
            output = b''
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if select.select([master], [], [], .1)[0]:
                    output += os.read(master, 65536)
                    if b'READY> ' in output and (not completed or b';end\x07' in output):
                        return output
            raise AssertionError(output)
        try:
            ready(False)
            os.write(master, "printf '日本語\\n二行目\\n'; printf 'error\\n' >&2\n".encode())
            ready()
            os.write(master, b'copy-last-output\n')
            ready()
            assert (root / 'clipboard').read_text() == '日本語\n二行目\nerror\n'
            os.write(master, "printf '日本語\\n二行目\\n'; printf 'error\\n' >&2\n".encode())
            ready()
            os.write(master, f'save-last-output {root}/saved\n'.encode())
            ready()
            assert (root / 'saved').read_text() == '日本語\n二行目\nerror\n'
            os.write(master, b'exit\n')
            process.wait(timeout=5)
            assert not list((root / 'runtime').glob('jeebis-output.*'))
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            os.close(master)
        config = root / 'tmux.conf'
        config.write_text(f'set -g default-shell {shlex.quote(wrapper)}\n')
        tmux = ['tmux', '-S', str(root / 'tmux.sock')]
        marker = root / 'tmux-command'
        try:
            subprocess.run([*tmux, '-f', str(config), 'new-session', '-d', '-s', 'check',
                            f"printf tmux-ok > {shlex.quote(str(marker))}; sleep 30"],
                           env=env, check=True, timeout=10)
            deadline = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(.05)
            assert marker.read_text() == 'tmux-ok'
        finally:
            subprocess.run([*tmux, 'kill-server'], capture_output=True)
    print('Passed: recursive SHELL regression, -c arguments, PTY output capture, cleanup and tmux tool command')


if __name__ == '__main__':
    main()

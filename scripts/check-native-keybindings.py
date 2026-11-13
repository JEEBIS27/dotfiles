"""Check native key ownership and load tmux bindings in an isolated server.

Usage: python scripts/check-native-keybindings.py --tmux-config FILE --ghostty-config FILE
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmux-config', required=True)
    parser.add_argument('--ghostty-config', required=True)
    args = parser.parse_args()
    subprocess.run(['ghostty', '+validate-config', '--config-file=' + args.ghostty_config], check=True)
    with tempfile.TemporaryDirectory(prefix='ghostty-keys-') as directory:
        config = Path(directory) / 'ghostty/config'
        config.parent.mkdir()
        config.write_bytes(Path(args.ghostty_config).read_bytes())
        bindings = subprocess.check_output(['ghostty', '+list-keybinds'], text=True,
            env=dict(os.environ, XDG_CONFIG_HOME=directory))
    for key in ['ctrl+enter', 'ctrl+shift+enter', 'ctrl+tab', 'ctrl+page_up', 'ctrl+page_down',
                'ctrl+shift+w', 'ctrl+shift+n', 'ctrl+shift+f', 'ctrl+shift+p',
                'ctrl+0', 'ctrl+1', 'alt+1', 'shift+page_up', 'shift+arrow_left']:
        assert f'keybind = {key}=' not in bindings, f'Ghostty steals {key}'
    for binding in ['ctrl+alt+enter=new_split:right', 'ctrl+alt+shift+enter=new_split:down',
                    'ctrl+insert=copy_to_clipboard', 'shift+insert=paste_from_clipboard']:
        assert binding in bindings, binding
    with tempfile.TemporaryDirectory(prefix='native-keys-') as directory:
        command = ['tmux', '-S', str(Path(directory) / 'socket')]
        def tmux(*argv):
            return subprocess.check_output([*command, *argv], text=True)
        try:
            tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'keys', '/bin/sh')
            tmux('source-file', str(Path(args.tmux_config).resolve()))
            root = tmux('list-keys', '-T', 'root')
            for key, action in {'M-h':'select-pane -L', 'M-j':'select-pane -D',
                                'M-k':'select-pane -U', 'M-l':'select-pane -R',
                                'M-H':'resize-pane -L 5', 'M-Enter':'split-window -h',
                                'M-S-Enter':'split-window -v', 'M-n':'new-window',
                                'M-N':'new-session', 'M-Y':'copy-mode', 'M-t':'display-popup'}.items():
                assert any(key in line.split() and action in line for line in root.splitlines()), (key, action)
            assert '1' == tmux('show-options', '-gv', 'base-index').strip()
            copy = tmux('list-keys', '-T', 'copy-mode-vi')
            for key, action in {'h':'cursor-left','a':'cursor-down','o':'cursor-up','e':'cursor-right','l':'next-word-end'}.items():
                assert any(key in line.split() and action in line for line in copy.splitlines()), (key, action)
            assert 'wl-copy' in copy
            assert 'swap-pane' in tmux('list-keys', '-T', 'exchange')
        finally:
            subprocess.run([*command, 'kill-server'], check=False, capture_output=True)
    keys = json.loads((ROOT / 'files/herdr-app/keys.json').read_text())
    commands = {c['name']: c for c in json.loads(subprocess.check_output(['herdr-app','commands'], text=True))}
    for section in keys.values():
        for value in section.values():
            name = value['command'] if isinstance(value, dict) else value.split(':',1)[0]
            assert name == 'terminal' or name in commands, name
            if isinstance(value, dict):
                assert set(value.get('args', {})) <= {a['name'] for a in commands[name]['args']}
    for number in range(1,10):
        assert keys['global'][f'alt-{number}'] == f'tab.select:{number}'
        assert keys['terminal'][f'ctrl-{number}'] == 'terminal'
    for key in ['ctrl-tab','ctrl-shift-tab','ctrl-pageup','ctrl-pagedown','ctrl-backspace','ctrl-v']:
        assert keys['terminal'][key] == 'terminal'
    for key,direction in zip('hjkl',['left','down','up','right']):
        assert keys['global'][f'alt-e {key}'] == 'pane.swap:' + direction
        assert keys['global'][f'ctrl-alt-{key}'] == 'pane.swap:' + direction
        assert keys['global'][f'ctrl-alt-{direction}'] == 'pane.swap:' + direction
        assert keys['global'][f'alt-shift-{key}'] == 'terminal'
    spec = importlib.util.spec_from_file_location('herdr_config', ROOT / 'packages/desktop/herdr-config.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    old = {'global': {'alt-1': 'space.select:1', 'f12': 'app.help'}, 'mod:custom': {'ctrl-s':'custom.save'}}
    updated = module.merge(old, keys)
    assert updated['global']['alt-1'] == 'tab.select:1'
    assert updated['global']['f12'] == 'app.help'
    assert updated['mod:custom'] == old['mod:custom']
    assert old['global']['alt-1'] == 'space.select:1'
    print('Native key ownership, isolated tmux, Herdr commands and preference merge passed')


if __name__ == '__main__':
    main()

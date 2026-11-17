"""Local tmux status and rename helpers; never query 1Password on a timer."""
import json
import hashlib
import shlex
import unicodedata
from pathlib import Path
import subprocess
import sys


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True, timeout=2).rstrip('\n')


def clean(text):
    return ''.join(c for c in text if c.isprintable()).replace('#', '##')


def foreground(pid, fallback):
    # script(1) creates another PTY, so pane_current_command can remain bash.
    # Walk only this pane's descendants and prefer their foreground group leader.
    pending = [(int(pid), 0)]
    candidates = []
    for _ in range(128):
        if not pending:
            break
        current, depth = pending.pop()
        try:
            root = Path(f'/proc/{current}')
            stat = (root / 'stat').read_text().rsplit(')', 1)[1].split()
            children = (root / f'task/{current}/children').read_text().split()
            pending.extend((int(child), depth + 1) for child in children)
            name = (root / 'comm').read_text().strip().removeprefix('.').removesuffix('-wrapped')
            if int(stat[2]) == int(stat[5]) and name not in {'script', 'env'} and not name.startswith('jeebis-record'):
                candidates.append((depth, name, int(stat[2]) == current, current))
        except (OSError, ValueError, IndexError):
            continue
    shells = {'sh', 'bash', 'fish', 'zsh', 'dash'}
    leaders = [item for item in candidates if item[2] and item[1] not in shells]
    chosen = max(leaders or candidates, default=(0, fallback, False, int(pid)))
    try:
        cwd = str(Path(f'/proc/{chosen[3]}/cwd').resolve(strict=True))
    except OSError:
        cwd = None
    return chosen[1], cwd


def visible(text):
    return sum(2 if unicodedata.east_asian_width(c) in {'W', 'F'} else 1 for c in text)


def clip(text, width):
    if visible(text) <= width:
        return text
    output = ''
    for char in text:
        if visible(output + char) > width - 1:
            break
        output += char
    return output + '…'


def context(pane):
    path, pid, command = tmux('display-message', '-p', '-t', pane,
                              '#{pane_current_path}\t#{pane_pid}\t#{pane_current_command}').split('\t', 2)
    command, actual_path = foreground(pid, command)
    return command, actual_path or path


def directory(pane, width):
    _, path = context(pane)
    label = '~' if path == str(Path.home()) else Path(path).name or '/'
    label = clean(clip(label, max(6, min(24, width // 3))))
    print('#[fg=#f5c2e7,bg=default]#[fg=#1e1e2e,bg=#f5c2e7] '
          f'#[fg=default,bg=#181825] {label} #[fg=#181825,bg=default]#[default]')


def tool(pane):
    command, _ = context(pane)
    print(clean(clip(command, 16)))


def topology():
    layout = tmux('list-panes', '-a', '-F',
                  '#{session_id}:#{window_index}:#{window_id}:#{pane_index}:#{pane_id}')
    return hashlib.sha256(layout.encode()).hexdigest()


def confirm_delete(client, pane):
    # The overlay blocks navigation. If the tree changes externally while it is
    # open, the callback refuses to act on a potentially different selection.
    callback = shlex.join([sys.executable, __file__, 'delete-confirmed', client, pane, topology()])
    subprocess.run(['tmux', 'display-menu', '-c', client, '-t', pane,
                    '-b', 'rounded', '-x', 'C', '-y', 'C', '-C', '0',
                    '-T', '#[fg=red,bold] Close selected item? ',
                    '-s', 'fg=default,bg=default', '-S', 'fg=blue,bg=default',
                    '-H', 'fg=#1e1e2e,bg=blue,bold', '--',
                    '-Running processes will be stopped.', '', '', '',
                    'Cancel', 'n', '',
                    'Close selected item', 'y', 'run-shell ' + shlex.quote(callback)], check=True)


def delete_confirmed(client, pane, expected):
    if topology() != expected or tmux('display-message', '-p', '-t', pane, '#{pane_mode}') != 'tree-mode':
        tmux('display-message', '-c', client, 'List changed. Select the item again.')
        return
    # Capture and confirm the exact native item only after the modal accepts.
    tmux('send-keys', '-t', pane, 'x')
    tmux('send-keys', '-K', '-c', client, 'y')


def rename(kind, client):
    ident, name = tmux('display-message', '-p', '-t', '~',
                       f'#{{{kind}_id}}\t#{{{kind}_name}}').split('\t', 1)
    # Capture the chosen target before opening the prompt; don't leave it marked.
    tmux('select-pane', '-M')
    # A parsed command block substitutes the name as one literal argument,
    # preserving quotes/semicolons instead of reparsing the user's input.
    initial = json.dumps(name, ensure_ascii=False).replace('$', r'\$')
    command = (f'command-prompt -b -l -t {client} -I {initial} -p "Rename {kind}" '
               f'{{ rename-{kind} -t {ident} -- "%%" }}')
    subprocess.run(['tmux', 'source-file', '-'], input=command, text=True,
                   check=True, timeout=2)


if __name__ == '__main__':
    try:
        if sys.argv[1] == 'directory':
            directory(sys.argv[2], int(sys.argv[3]))
        elif sys.argv[1] == 'tool':
            tool(sys.argv[2])
        elif sys.argv[1] == 'confirm-delete':
            confirm_delete(sys.argv[2], sys.argv[3])
        elif sys.argv[1] == 'delete-confirmed':
            delete_confirmed(sys.argv[2], sys.argv[3], sys.argv[4])
        elif sys.argv[1] == 'rename':
            rename(sys.argv[2], sys.argv[3])
    except (OSError, ValueError, subprocess.SubprocessError):
        pass  # A pane/session may disappear between refreshes.

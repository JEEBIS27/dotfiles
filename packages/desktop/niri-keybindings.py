"""Search the active, generated Niri keybindings without executing selections."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess

DESCRIPTIONS = {
    'toggle-overview': '全体を俯瞰 Overview ワークスペース一覧',
    'focus-column-left': '左の列へ移動 focus left',
    'focus-column-right': '右の列へ移動 focus right',
    'focus-window-down': '下のウィンドウへ移動 focus down',
    'focus-window-up': '上のウィンドウへ移動 focus up',
    'swap-window-left': '左と交換 swap left', 'swap-window-right': '右と交換 swap right',
    'move-column-left': '列を左へ移動 move column left',
    'move-column-right': '列を右へ移動 move column right',
    'move-window-down': 'ウィンドウを下へ移動 move down',
    'move-window-up': 'ウィンドウを上へ移動 move up',
    'set-column-width': '列の幅を変更 resize width',
    'set-window-height': '高さを変更 resize height',
    'focus-workspace': 'ワークスペースを選択 workspace',
    'move-window-to-workspace': 'ウィンドウを指定ワークスペースへ移動 workspace',
    'focus-workspace-down': '次のワークスペース next workspace',
    'focus-workspace-up': '前のワークスペース previous workspace',
    'focus-workspace-previous': '以前のワークスペース previous workspace',
    'move-window-to-workspace-down': '次のワークスペースへ移動 move workspace',
    'move-window-to-workspace-up': '前のワークスペースへ移動 move workspace',
    'focus-monitor-next': '次のモニター monitor',
    'focus-monitor-previous': '前のモニター monitor',
    'close-window': 'ウィンドウを閉じる close window',
    'switch-preset-column-width': '列幅プリセットを切替 column width',
    'fullscreen-window': '全画面 fullscreen',
    'switch-focus-between-floating-and-tiling': 'フローティングとタイルのフォーカス切替 floating tiling',
    'toggle-window-floating': 'フローティング切替 floating',
    'toggle-column-tabbed-display': 'タブ表示を切替 tabbed layout',
    'consume-or-expel-window-left': '左の列へ取り込み・分離 consume expel',
    'consume-or-expel-window-right': '右の列へ取り込み・分離 consume expel',
    'quit': 'Niriからログアウト logout quit',
    'screenshot': 'スクリーンショット screenshot',
    'show-hotkey-overlay': 'Niri標準キー一覧 hotkey overlay',
}


def describe(action, applications):
    words = shlex.split(action.rstrip(';').strip())
    if not words:
        return ''
    name, *args = words
    if name != 'spawn':
        return DESCRIPTIONS.get(name, name) + ('  ' + ' '.join(args) if args else '')
    if not args:
        return 'spawn'
    program = Path(args[0]).name
    tail = args[1:]
    if program == 'jeebis-niri' and tail:
        if tail[0] == 'clipboard' and len(tail) > 1:
            return {'cut': '切り取り cut', 'copy': 'コピー copy', 'paste': '貼り付け paste'}.get(tail[1], tail[1])
        if tail[0] == 'launch' and len(tail) > 1:
            app = applications.get(tail[1], {})
            return app.get('name', tail[1]) + (' — 下に起動 below' if '--below' in tail else ' — 起動 launch')
        return {'close-workspace': '現在のワークスペースのウィンドウを閉じる close workspace',
                'toggle-maximize': '最大化・復元 maximize restore'}.get(tail[0], ' '.join(tail))
    if program == 'jeebis-niri-resize':
        return '隣の列と幅を調整 paired resize ' + ('+10%' if tail == ['grow'] else '-10%')
    if program == 'jeebis-desktop':
        command = ' '.join(tail)
        return {
            'lock': '画面をロック lock',
            'settings': 'Tide設定 settings',
            'shell tide togglePowerMenu': '電源メニュー power shutdown reboot suspend logout',
            'shell tide toggleApplicationLauncher': 'アプリランチャー launcher',
            'shell island toggle': 'Tide Island表示切替 toggle',
            'shell island show': 'Tide Island表示 show',
            'shell island hide': 'Tide Island非表示 hide',
            'theme cycle': 'テーマ切替 theme',
        }.get(command, command)
    if program == 'jeebis-terminal':
        return 'Ghostty ターミナル terminal'
    if program == 'jeebis-niri-keybindings':
        return 'キーバインドを絞り込み検索 keybindings shortcuts search'
    if program == 'wpctl':
        return '音量・ミュート volume mute  ' + ' '.join(tail)
    if program == 'brightnessctl':
        return '画面の明るさ brightness  ' + ' '.join(tail)
    return ' '.join([program, *tail])


def entries(config, applications):
    # The managed template and generated application/workspace binds are all
    # single-line KDL nodes. Anchor both ends so unrelated sections are ignored.
    pattern = re.compile(r'^\s*([\w+]+)((?:\s+[\w-]+=(?:"(?:\\.|[^"\\])*"|[^\s{]+))*)\s*\{\s*(.*?)\s*\}\s*(?://.*)?$')
    rows = []
    in_binds = False
    for line in config.splitlines():
        if line.strip() == 'binds {':
            in_binds = True
            continue
        if line.strip() == '}':
            in_binds = False
        if not in_binds:
            continue
        match = pattern.match(line)
        if not match:
            continue
        key, properties, action = match.groups()
        if not action.endswith(';'):
            continue
        title = re.search(r'hotkey-overlay-title=("(?:\\.|[^"\\])*")', properties)
        description = json.loads(title[1]) if title else describe(action, applications)
        key = '+'.join({'Mod': 'Super', 'Return': 'Enter', 'Escape': 'Esc',
                       'Page_Up': 'PageUp', 'Page_Down': 'PageDown'}.get(part, part) for part in key.split('+'))
        rows.append(f'{key:<30} {description}')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--applications', required=True, type=Path)
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    rows = entries(args.config.read_text(), json.loads(args.applications.read_text()))
    if not rows:
        parser.error('No managed keybindings found')
    text = '\n'.join(rows) + '\n'
    if args.list:
        print(text, end='')
        return
    result = subprocess.run(['fuzzel', '--dmenu', '--only-match', '--match-mode=fzf',
                             '--prompt', 'キー検索: ', '--width=100', '--lines=18', '--counter'],
                            input=text, text=True, stdout=subprocess.DEVNULL)
    if result.returncode not in (0, 1, 2):
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()

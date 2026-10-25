# ターミナルのキー移行表

調査元は移行前の `files/wezterm/keybinds.lua`、`wezterm.lua`、`files/tmux.conf`、`files/herdr/config.toml`。旧設定そのものはGit履歴にだけ残す。Alt層をTUIOSへ集約し、Ctrl+Alt層の主要操作も別名として残す。

## 通常操作

| 旧キー | 旧担当・意味 | Rio + TUIOS |
|---|---|---|
| Alt+H/J/K/L、Alt+矢印 | Herdr/tmuxのペイン移動 | TUIOSの方向移動 |
| Alt+Shift+H/J/K/L、Alt+Shift+矢印 | ペインを5単位リサイズ | TUIOSの5単位リサイズ |
| Alt+Enter / Shift+Enter | 左右 / 上下分割 | TUIOSのvertical / horizontal split |
| Alt+N | Herdrタブ / tmuxウィンドウ | TUIOS新規ウィンドウ（ペイン） |
| Alt+Shift+N | 新規ワークスペース / セッション | TUIOSの最初の空ワークスペースにペイン作成 |
| Alt+1〜9 | タブ / ウィンドウ選択 | 現ワークスペースのTUIOSウィンドウ選択 |
| Alt+Tab / Shift+Tab | 次 / 前タブ | 次 / 前TUIOSウィンドウ |
| Alt+PageDown / PageUp | 次 / 前タブ | 同上、端末側のFキー変換不要 |
| Alt+Shift+PageDown / PageUp | 次 / 前ワークスペース | ペインがある次 / 前ワークスペース |
| Alt+F | WezTermの画面検出→コピー→検索 | TUIOS `copy_mode_search_backward`、1操作で検索 |
| Alt+Shift+Y | コピーモード | TUIOSコピーモード |
| Alt+Y | cwdを継承してYazi | TUIOSカスタムpaneコマンド `zsh -i -c y` |
| Alt+T | シェルpopup | TUIOSの永続scratch、同じキーで表示/非表示 |
| Alt+Shift+T | tmuxレイアウト切替 | TUIOSレイアウト切替 |
| Alt+G | ワークスペース選択 | TUIOSワークスペース選択 |
| Alt+E → H/J/K/L、矢印 | ペイン交換 | TUIOS prefix→方向交換 |
| Alt+B | Herdrサイドバー | TUIOSセッション・エージェントrail |
| Alt+O | 通知対象へ移動 | TUIOSの最新メッセージ対象へ移動 |
| Alt+D | デタッチ | TUIOSデタッチ、プロセスを保持 |
| Alt+W | ペインを閉じる | TUIOSウィンドウを閉じる |
| Alt+Shift+W | タブ内全ペインを閉じる | 未移行。TUIOSには独立したタブコンテナがない |
| Alt+Shift+D | ワークスペースを閉じる | TUIOSの現ワークスペース全ペインを閉じる（確認あり） |
| Alt+Shift+F | ズーム | TUIOSズーム |
| Alt+; | 前のペイン | TUIOS last pane |
| Alt+R | タブ名変更 | TUIOSウィンドウ名変更（階層差あり） |
| Alt+Shift+P | ペイン名変更 | TUIOSウィンドウ名変更 |
| Alt+Shift+R | ワークスペース名変更 | TUIOSワークスペース名変更 |
| Alt+P | Herdr goto | TUIOSコマンドパレット（完全に同じpickerではない） |
| Alt+Shift+E | スクロールバック編集 | TUIOSスクロールバックbrowser（外部エディター編集とは異なる） |
| Alt+, / Alt+Shift+, | 設定 / 再読込 | TUIOS設定 / 再読込 |
| Alt+/ | ヘルプ | TUIOSヘルプ |
| Alt+Shift+G | Herdr worktree作成 | popupでブランチ入力→`tuios worktree new --detach`。作成後はrailで選択 |

TUIOSでは **session → workspace → window（PTYペイン）**。Herdrの **workspace → tab → pane** と階層の名前・切替対象が違う。Alt+Nで複数ペインを束ねた独立タブは作られない。9ワークスペースを使い切るとAlt+Shift+Nは新規作成できない。通常の新規Rioウィンドウは新しいsessionを作る。

## Ctrl+Alt層・端末操作

| 旧キー | 移行先 / 差異 |
|---|---|
| Ctrl+Alt+H/J/K/L、矢印、Shift付き | Alt層と同じ移動・リサイズ |
| Ctrl+Alt+Enter、Shift付き | TUIOS左右・上下分割 |
| Ctrl+Alt+Shift+F | TUIOSズーム |
| Ctrl+Alt+W | TUIOSウィンドウを閉じる |
| Ctrl+Alt+Shift+W | 旧タブ全体の削除は未移行 |
| Ctrl+Alt+N | TUIOS新規ウィンドウ |
| Ctrl+Alt+Shift+N | 旧OSウィンドウ作成は未移行。Super+Nを使用 |
| Ctrl+Alt+R / Shift+R | TUIOSウィンドウ / ワークスペース名変更 |
| Ctrl+Alt+Tab、Shift+Tab、PageUp/Down、Shift+PageUp/Down、1〜9 | Alt層と同じウィンドウ・ワークスペース切替 |
| Ctrl+Alt+G / Shift+G | TUIOSワークスペース選択 / 新規作成（旧名前入力promptとは異なる） |
| Ctrl+Alt+E | 旧WezTerm pane selector交換は未移行。Alt+E→方向を使用 |
| Ctrl+Alt+F、Shift+Y、Y | TUIOS検索・コピー・Yazi |
| Ctrl+Alt+P | TUIOSコマンドパレット |
| Ctrl+Alt+, / Shift+, | TUIOS再読込 / 設定画面（旧ファイルをエディターで開く操作とは異なる） |
| Ctrl+Alt+= / - / 0 | Rioのフォント拡大 / 縮小 / リセット |
| Ctrl+Alt+U、Shift+U | WezTerm独自の透過切替を削除。透明度はHyprlandのlooknfeelで管理 |
| Ctrl+Alt+I | 旧Herdr起動を削除。TUIOS Inboxを表示 |
| Ctrl+Alt+Shift+I | 外部`chat`起動は未移行（リポジトリにコマンド本体なし） |
| Ctrl+Alt+Home / End | Rio独自スクロールは削除。TUIOSコピー内のg/Gを使用 |
| Ctrl+Insert / Shift+Insert | Rioコピー / 貼付け |
| Ctrl+Shift+C / V | Rio標準コピー / 貼付け |
| Shift+Enter | 固定CSI-uパケット注入を削除、Kitty Keyboard Protocolで転送 |
| 左クリック選択・離す | アプリのマウスイベントを優先。TUIOSコピーやShift付き端末選択を使用 |
| Alt+F5〜F9 | 旧Page/BackTab変換用aliasを削除。実際のPage/Tabキーを使用 |
| Alt+E→PageUp/Down、F5/F6 | 旧タブ順交換は未移行。タブ階層なし |
| Ctrl+Space / Ctrl+B prefix、prefix q / ? | 旧tmux prefixを削除。TUIOSはAlt+E、再読込Alt+Shift+,、ヘルプAlt+/ |

## コピーモード

旧WezTermの `h/j/k/l`・矢印、`^/$/0`、Home/End、`w/b/e`、`f/F/t/T/;`、`g/G`、Ctrl+Home/End、`H/M/L`、Ctrl+B/F/U/D、PageUp/Down、`v/V/Ctrl+V`、`o/O`、`y`、Enter、Esc、Ctrl+C、qを調査した。

TUIOS標準のVim移動・`v/V`選択・`/ ? n N`検索・`y`コピーを使用する。旧 `o/O` の選択端交換、Ctrl+Vの矩形選択、Home/End/Ctrl+Home/End、EnterでPRIMARYにもコピーする挙動、Ctrl+Cで終了する挙動までの完全一致は保証しない。コピーと選択の詳細はTUIOSのヘルプで確認する。動かない互換アクションは追加していない。

## 内側アプリとの境界

Ctrl+P/N/F/Y/V、Shift+Enter、Shift+PageUp/Down、Shift+矢印は内側アプリへ渡す。ZshのCtrl+F/G/D/Y/Rや既存CSI-u/legacy widget対応、Yaziの`d/D/x/X`などの操作は維持する。Rio標準のCtrl+Shift+P/F/B/NとCtrl+Lは明示的に転送へ変更した。

Alt+H/J/K/L・Alt+矢印など、この表で予約したキーは内側アプリへ届かない。ZshのAlt+矢印による単語移動は元からペイン移動との競合対象であり、Ctrl+矢印を使う。CodexのAlt+キー操作と衝突する場合もTUIOS層が優先する。`tuios keybinds doctor --guest nvim`等は参考情報であり、実機入力確認の代わりではない。

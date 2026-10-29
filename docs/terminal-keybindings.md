# ターミナルのキー移行表

調査元は移行前の `files/wezterm/keybinds.lua`、`wezterm.lua`、`files/tmux.conf`、`files/herdr/config.toml`。旧設定そのものはGit履歴にだけ残す。Alt層をTUIOSへ集約し、Ctrl+Alt層の主要操作も別名として残す。

## 通常操作

| 旧キー | 旧担当・意味 | Rio + TUIOS |
|---|---|---|
| Alt+H/J/K/L、Alt+矢印 | Herdr/tmuxのペイン移動 | TUIOSの方向移動 |
| Alt+Shift+H/J/K/L、Alt+Shift+矢印 | ペインを5単位リサイズ | TUIOSの5単位リサイズ |
| Alt+Enter / Shift+Enter | 左右 / 上下分割 | TUIOSのvertical / horizontal split |
| Alt+N | Herdrタブ / tmuxウィンドウ | TUIOS新規ウィンドウ（ペイン） |
| Alt+Shift+N | 新規Tab / Workspace | TUIOSの最初の空Tabにペイン作成 |
| Alt+1〜9 | タブ / ウィンドウ選択 | 現TabのTUIOSウィンドウ選択 |
| Alt+Tab / Alt+Shift+Tab | 次 / 前タブ | 次 / 前TUIOS Tab |
| Alt+PageDown / PageUp | 次 / 前タブ | 同上、端末側のFキー変換不要 |
| Alt+Shift+PageDown / PageUp | 次 / 前Tab | ペインがある次 / 前Tab |
| Alt+F | WezTermの画面検出→コピー→検索 | TUIOS `copy_mode_search_backward`、1操作で検索 |
| Alt+Shift+Y | コピーモード | TUIOSコピーモード |
| Alt+Y | cwdを継承してYazi | TUIOSカスタムpaneコマンド `yazi` |
| Alt+T | シェルpopup | TUIOSの永続scratch、同じキーで表示/非表示 |
| Alt+Shift+T | tmuxレイアウト切替 | TUIOSレイアウト切替 |
| Alt+S（Alt+Gも可） | Tab検索 | TUIOS Tab選択 |
| Alt+Shift+S | Workspace検索 | 内蔵検索でEnter切替・Delete削除確認 |
| Alt+E → H/J/K/L、矢印 | ペイン交換 | TUIOS prefix→方向交換 |
| Alt+B | Herdrサイドバー | TUIOS Workspace・エージェントrail |
| Alt+O | 通知対象へ移動 | TUIOSの最新メッセージ対象へ移動 |
| Alt+D | デタッチ | TUIOSデタッチ、プロセスを保持 |
| Alt+W | ペインを閉じる | TUIOSウィンドウを閉じる |
| Alt+Shift+W | Workspace全体を閉じる | 現Workspaceを全プロセスごと削除し、TUIOSを終了 |
| Alt+Shift+D | Tabを閉じる | TUIOSの現Tab全ペインを閉じる（確認あり） |
| Alt+Shift+F | ズーム | TUIOSズーム |
| Alt+; | 前のペイン | TUIOS last pane |
| Alt+R | タブ名変更 | TUIOSウィンドウ名変更（階層差あり） |
| Alt+Shift+P | ペイン名変更 | TUIOSウィンドウ名変更 |
| Alt+Shift+R | Tab名変更 | TUIOS Tab名変更 |
| Alt+P | Herdr goto | TUIOSコマンドパレット（完全に同じpickerではない） |
| Alt+Shift+E | スクロールバック編集 | TUIOSスクロールバックbrowser（外部エディター編集とは異なる） |
| Alt+, / Alt+Shift+, | 設定 / 再読込 | TUIOS設定 / 再読込 |
| Alt+/ | ヘルプ | TUIOSヘルプ |
| Alt+Shift+G | Herdr worktree作成 | popupでブランチ入力→`tuios worktree new --detach`。作成後はrailで選択 |

TUIOSの表示名は **Workspace → Tab → Pane**（内部識別子は従来の `session → workspace → window`）。Herdrの **workspace → tab → pane** と階層の名前・切替対象が違う。Alt+Nで複数ペインを束ねた独立タブは作られない。9Tabを使い切るとAlt+Shift+Nは新規作成できない。通常のRioはHyprland Workspaceごとの既存Workspaceへ再接続する。

## Ctrl+Alt層・端末操作

| 旧キー | 移行先 / 差異 |
|---|---|
| Ctrl+Alt+H/J/K/L、矢印、Shift付き | Alt層と同じ移動・リサイズ |
| Ctrl+Alt+Enter、Shift付き | TUIOS左右・上下分割 |
| Ctrl+Alt+Shift+F | TUIOSズーム |
| Ctrl+Alt+W | TUIOSウィンドウを閉じる |
| Ctrl+Alt+Shift+W | 旧タブ全体の削除は未移行 |
| Ctrl+Alt+N | TUIOS新規ウィンドウ |
| Ctrl+Alt+Shift+N | 旧OSウィンドウ作成は未移行。Super+Alt+Enterを使用（FullwidthはSuper+Alt+Shift+Enter） |
| Ctrl+Alt+R / Shift+R | TUIOSウィンドウ / Tab名変更 |
| Ctrl+Alt+Tab、Shift+Tab、PageUp/Down、Shift+PageUp/Down、1〜9 | Alt層と同じウィンドウ・Tab切替 |
| Ctrl+Alt+G / Shift+G | TUIOS Tab選択 / 新規作成（旧名前入力promptとは異なる） |
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

Ctrl+P/N/F/Y/V、Shift+Enter、Shift+PageUp/Down、Shift+矢印は内側アプリへ渡す。fishのCtrl+F/G/D/Y/Rとネイティブのキー処理、Yaziの`d/D/x/X`などの操作は維持する。Rio標準のCtrl+Shift+P/F/B/NとCtrl+Lは明示的に転送へ変更した。

Alt+H/J/K/L・Alt+矢印など、この表で予約したキーは内側アプリへ届かない。fishのAlt+矢印による単語移動は元からペイン移動との競合対象であり、Ctrl+矢印を使う。CodexのAlt+キー操作と衝突する場合もTUIOS層が優先する。`tuios keybinds doctor --guest nvim`等は参考情報であり、実機入力確認の代わりではない。

fishの画面消去＋一覧表示はCtrl+Esc。Ctrl+Lはfishで処理しない。シェルの移行内容と出力保存は[fish-migration.md](fish-migration.md)を参照。

## デスクトップのアプリ起動

キーの割り当ては `files/hypr/app-bindings.lua` 先頭の `APP_KEYS` に集約する。
例: `O = "obsidian"`。`false` はこの表から起動キーを生成しない。
空き文字キーも残し、H/J/K/Lは移動操作用に予約する。

各キーにSuper+Alt（通常起動）とSuper+Alt+Shift（同じアプリのFullwidth起動）を自動生成する。
FullwidthはScrollingで列幅100%、Dwindle/Floatingで最大化。起動元Tabの対象アプリを待ち、既存の全幅を解除しない。
端末の右/下分割（Super+Enter / Super+Shift+Enter）は配置操作として維持する。
1Password・Tensaku・Ploverはランチャーから起動する。

## Yazi画像プレビュー

Super+Yは `jeebis-terminal` → Rio → TUIOS → fish → Yazi で起動する。
通常のTUIOSペインから開くYaziも含め、Rioの描画は `Webgpu` に揃える。
ネイティブVulkan経路では画像プレビュー中のリサイズとIntel GPUハングが対応していた。
`jeebis-terminal` は `NO_COLOR` を解除する。Kitty画像プロトコルは文字色に画像IDを埋め込むため、
TUIOSの描画から色を省くと画像が表示されない。GUI検証を直接起動する場合も `env -u NO_COLOR` を使う。


## Workspaceと役割Tab

HyprlandのWorkspace1はTUIOSの `desktop-1` Workspace、2は `desktop-2` Workspaceを使う。
名前付き・specialのHyprland Workspaceも、独立したTUIOS Workspaceに対応する。
その中でTUIOS Tab1=Terminal、2=Yazi、3=Codex、4=Helix、5=btop、6=その他を使い分ける。
再起動では同じ役割のTabへ戻り、ペインを追加しない。空の場合だけ作り直す。

- Alt+Shift+S: 内蔵Workspace検索。入力で絞り込み、Enterで切り替え、Delete（またはCtrl+D）で削除確認、Escで戻る。
- Alt+S（Alt+Gも可）: TUIOS Tab検索。
- Alt+Tab / Alt+PgDn: 次のTUIOS Tab。
- Alt+Shift+Tab / Alt+PgUp: 前のTUIOS Tab。
- Super+W: Rioを閉じる。Workspaceと実行中プロセスは保持する。
- Alt+W: 現在のペインを閉じる。
- Alt+Shift+W: 現在のWorkspace全体を削除してTUIOSを終了する。

歯車マークは表示しない。過去の役割別Workspaceは自動削除せず、必要ならAlt+Shift+Sから削除する。

Tab検索には役割名・ペインタイトル・選択中Tabの作業ディレクトリを表示する。名前・タイトル・ディレクトリで絞り込める。役割名は未命名の場合だけ設定し、Ctrl+Rで変更した名前は保持する。

## 表示名と内部識別子

UIは旧SessionをWorkspace、旧WorkspaceをTabと呼ぶ。Alt+SはTab検索、Alt+Shift+SはWorkspace検索。
既存設定・CLIとの互換性のため、`prefix_session_switcher`、`prefix_workspace_switcher`、`tuios attach`などの内部名やコマンド名は変更しない。

# 現環境のキーバインド

Niri + Ghostty + fish、必要に応じてtmuxまたはHerdr Appを使う。
旧Hyprland環境の階層を維持する：Superはデスクトップ、Ctrl+Altは端末、Altは多重化、Ctrlは内側アプリ。
TUIOS時代の対応表は[tuios-terminal-keybindings.md](tuios-terminal-keybindings.md)に保存した。

## tmux / Herdr App

| キー | tmux | Herdr App |
| --- | --- | --- |
| Alt+J/K/I/L・矢印 | ペイン移動 | ペイン移動 |
| Alt+Shift+方向 | 5セルのリサイズ | App 0.1.13には非対応。マウスで境界をドラッグ |
| Alt+E → H/A/O/E・矢印 | ペイン交換 | ペイン交換（GPUIのキーシーケンス） |
| Alt+Ctrl+J/K/I/L・矢印 | 端末側の操作 | 隣接ペインとの交換（`pane.swap`） |
| Alt+Enter / Alt+Shift+Enter | 左右 / 上下分割 | 同じ |
| Alt+W / Alt+Shift+W | ペイン / ウィンドウを閉じる | ペイン / タブを閉じる |
| Alt+Shift+F | ペインのズーム切替 | 同じ |
| Alt+N / Alt+Shift+N | 新規ウィンドウ / セッション | 新規タブ / スペース |
| Alt+R / Alt+Shift+R | ウィンドウ / セッションの名前変更 | タブ / スペースの名前変更 |
| Alt+1〜9 | ウィンドウ選択（1始まり） | タブ選択。標準のスペース選択を変更 |
| Alt+Tab・Alt+PageDown / Shift+Tab・PageUp | 次 / 前ウィンドウ | 次 / 前タブ |
| Alt+Shift+PageDown / PageUp | 次 / 前セッション | 次 / 前スペース |
| Alt+S / Alt+G | ウィンドウ / セッション一覧（rでウィンドウ名、Shift+Rでセッション名を変更） | スペース・タブ・エージェントのpicker |
| Alt+F | コピーモードを開いて検索 | 端末の検索バー |
| Alt+Shift+Y | コピーモード | Appには旧版のキーボードコピーモードがない |
| Alt+Y | 右分割でfishのYazi関数を起動 | 同じ |
| Alt+T | シェルpopupの表示／非表示（80%、シェルの状態を保持） | Appには旧版のシェルpopupがない |
| Alt+Shift+T | ペインレイアウト切替 | Appの画面レイアウト切替 |
| Alt+D | デタッチ | ウィンドウを閉じる。coreの端末は保持 |
| Alt+Shift+D | セッションを閉じる（確認あり） | スペースを閉じる |
| Alt+/ | キー一覧 | ヘルプ |
| Alt+B・Alt+Shift+B | 未割当て | サイドバー表示切替 |

Herdr TUIとHerdr Appは別製品。Appの公開コマンドにはpane.resize、copy_mode、
rename_pane、last_pane、new_worktree、edit_scrollbackがないため、架空の操作を割り当てない。
旧Alt+Shift+方向がApp標準の「ペイン交換」にならないよう、その割当ても解除する。
Appのキー設定はライブ反映。旧Alt+Shift+,の明示的な設定再読込は不要。
旧Alt+Oの通知対象への移動も同等コマンドがないため未割当て。

Appに残っていたCtrl+数字・Ctrl+Tab・Ctrl+PageUp/Down・Ctrl+Shift+W/N等は
端末フォーカス中に内側アプリへ渡す。Ctrl+Backspaceの旧`send:Ctrl+W`変換も外し、
fishの割り込みキーCtrl+Wと混同しないようにする。コピー/貼付けのCtrl+Shift+C/VとInsert系は維持。
独自のローカルキーとmodセクションは、宣言したキー以外を保持してマージする。

## Ghostty

`files/ghostty/keybindings.nix`で標準キーをclearした上で必要な端末操作だけを宣言する。
Alt+数字、Ctrl+Enter、Ctrl+Shift+Enter、Ctrl+Tab、Ctrl+数字、Shift+PageUp/Down、
Shift+矢印は内側アプリへ届く。これがHelix・Yazi・fishの共通キーを有効にする。

| キー | 操作 |
| --- | --- |
| Ctrl+Insert / Ctrl+Shift+C | コピー |
| Shift+Insert / Ctrl+Shift+V | クリップボード貼付け |
| Ctrl+Alt+= / - / 0 | 文字サイズ拡大 / 縮小 / リセット |
| Ctrl+Alt+J/K/I/L・矢印 | Ghosttyの分割移動 |
| Ctrl+Alt+Shift+方向 | Ghosttyの分割リサイズ（5px。旧WezTermの5セルとは単位が違う） |
| Ctrl+Alt+Enter / Ctrl+Alt+Shift+Enter | 左右 / 上下分割 |
| Ctrl+Alt+Shift+F | 分割のズーム切替 |
| Ctrl+Alt+W / Ctrl+Alt+Shift+W | 現在の分割 / タブを閉じる |
| Ctrl+Alt+N / Ctrl+Alt+Shift+N | 新規タブ / OSウィンドウ |
| Ctrl+Alt+Tab・PageDown / Shift+Tab・PageUp | 次 / 前タブ |
| Ctrl+Alt+Shift+PageDown / PageUp | 次 / 前OSウィンドウ。WezTermのWorkspaceとは異なる |
| Ctrl+Alt+1〜9 | タブ選択 |
| Ctrl+Alt+R / Ctrl+Alt+G | タブ名変更 / タブ一覧 |
| Ctrl+Alt+F / Ctrl+Alt+P | 検索 / コマンドパレット |
| Ctrl+Alt+, / Ctrl+Alt+Shift+, | 再読込 / 設定ファイルを開く |
| Ctrl+Alt+Home / End | スクロールの先頭 / 末尾 |

WezTermのWorkspace・pane selector交換・透過段階切替・Vimコピーモードに完全一致する
Ghostty操作はない。Alt層のtmuxでセッション・ペイン交換・コピーを使う。

## 内側アプリとデスクトップ

Helix、Yazi、fish、Neovimのキー設定はHyprlandからの移行で変更されていない。
方向は左・下・上・右の順に論理 `hjkl` で定義する。実キーは一打ごとに決まり、Graphite の単独・Shift のみは `haoe`、Ctrl・Alt・Super を含む方向指定は `jkil`。通常配列では `files/helix/key-layout.nix` の `directionKeys` を `"jkil"` にすると単独・Shift も同じ配置になる。
たとえば tmux で上ペインに移るのは Alt+I、Alt+E を離して上ペインと交換するのは O。検索文字と挿入文字は入力どおりに扱う。

- [Helix](helix-keybindings.md)、[共通Ctrl操作](editor-keybindings.md)
- [Yazi](yazi-keybindings.md)、[fish](fish-migration.md)
- [Niriのデスクトップ操作と移行差分](niri-keybindings.md)

Niriの既存アプリ起動・上下配置・ワークスペース操作を維持する。Hyprland固有の
special workspace、Dwindle、Super+Eのexchange submapはNiriの同等機能がなく、
現行Super+Ctrl+方向の交換操作を使う。Shift付きアプリ起動は現在の下配置を維持。

## 反映と検証

Home ManagerがGhostty/tmuxの設定とHerdr Appへのキーのマージを管理する。
既存tmuxには`tmux source-file ~/.config/tmux/tmux.conf`で反映でき、paneのプロセスは継続する。
Ghosttyは再読込、Herdr Appは次回起動またはライブ反映で更新する。

`scripts/check-native-keybindings.py --tmux-config FILE --ghostty-config FILE`は
Ghosttyの実効キー、私有tmuxサーバーの各テーブル、Herdrの公開コマンドとローカル設定の
マージを検証する。物理キー・IME・Herdr GUIの各機能は別途実機確認が必要。

tmux のペイン名変更は `Ctrl+Space` → `Shift+P`（または `Ctrl+B` → `Shift+P`）。端末応答との衝突を避けるため、単独の `Alt+Shift+P` は使わない。

ステータスバーとプラグインの設定は [tmux-customization.md](tmux-customization.md) を参照。

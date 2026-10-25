# Helixと統一キー

AltはTUIOS、Ctrlは内側アプリの共通操作に使う。文字キーの編集モデル・LSP・整形はHelix標準を使う。公式Helix 25.07.1向けの設定で、本体パッチは追加しない。

## 共通操作と元機能の退避

| キー | 操作 | 元のHelix機能の扱い |
|---|---|---|
| Ctrl+S | 保存 | 元の固有機能はCtrl+Shift+Sへ |
| Ctrl+Shift+S（normal/select） | 選択位置をjumplistへ保存 | 元のCtrl+S。ファイル保存ではない |
| Ctrl+Shift+S（insert） | Undoの区切りを作成 | 元のCtrl+S。ファイル保存ではない |
| Ctrl+H/J/K/L、Ctrl+矢印 | 分割移動 | insertのCtrl+HはBackspace、Ctrl+JはEnter、Ctrl+KはCtrl+Shift+Deleteへ |
| Ctrl+Enter / Ctrl+Shift+Enter | 縦 / 横分割 | 編集モードの既定割当てなし |
| Ctrl+W | 現在のviewを閉じる | windowメニューはSpace→w。insertの単語削除はCtrl+Backspace |
| Ctrl+N | 新規buffer | picker・補完中は標準の次候補のまま |
| Ctrl+F | ファイル検索 | 1ページ下移動はPageDown |
| Ctrl+G | 全文検索 | 編集モードの既定割当てなし |
| Ctrl+B | buffer一覧 | 1ページ上移動はPageUp |
| Ctrl+D（normal/select） | Git変更ファイル一覧 | 半ページ下移動はz→Space、またはz→Ctrl+D。NeovimのGit差分UIとは異なる |
| Ctrl+PageUp / Ctrl+PageDown | 前 / 次buffer | Neovimのtabpageではない |
| Ctrl+E→H/J/K/L、矢印 | view交換 | 標準の交換コマンドを利用 |
| Ctrl+Backspace（insert） | 直前の単語を削除 | 元のCtrl+W / Alt+Backspace |
| Ctrl+Delete（insert） | 次の単語を削除 | 元のAlt+D / Alt+Delete |
| Ctrl+Shift+Delete（insert） | カーソルから行末まで削除 | 元のCtrl+K |

明記したモード専用操作を除きnormal/select/insertに共通操作を割り当てる。Ctrl+Shift+Sは強制保存には使わない。強制保存は`:write!`。元のCtrl+Uは変更しない。

## Alt機能の退避メニュー

normal/selectで **Space→m** を押すと候補が表示される。続けて以下のキーを押す。selectでは親ノード先頭/末尾操作を選択拡張として保持する。

| Space→mの後 | 機能 | 元のキー |
|---|---|---|
| o / i | 構文選択の拡大 / 縮小 | Alt+O / Alt+I、Alt+上下 |
| p / n | 前 / 次の構文兄弟要素 | Alt+P / Alt+N、Alt+左右 |
| b / e | 親ノードの先頭 / 末尾 | Alt+B / Alt+E |
| a / I | 全兄弟 / 全子要素を選択 | Alt+A / Alt+Shift+I |
| ; | 選択の始点と終点を反転 | Alt+; |
| , | 主選択を除去 | Alt+, |
| d / c | コピーせず削除 / 変更 | Alt+D / Alt+C |
| C | 上の行にカーソル追加 | Alt+Shift+C |
| s | 選択を改行で分割 | Alt+S |
| - / _ | 選択を結合 / 連続する選択を結合 | Alt+- / Alt+_ |
| x | 選択を行内に収める | Alt+X |
| K | 正規表現に一致する選択を除去 | Alt+Shift+K |
| J | 行を結合し、結合箇所の空白を選択 | Alt+Shift+J |
| ( / ) | 選択内容を前 / 後へ入れ替え | Alt+( / Alt+) |
| : | 選択方向を前向きに揃える | Alt+: |
| . | 最後のf/F/t/T移動を繰返す | Alt+. |
| &#96; | 大文字化 | Alt+&#96; |
| * | 選択内容を検索 | Alt+* |
| u / U | 編集履歴を時間方向に前 / 後へ | Alt+U / Alt+Shift+U |
| \| / ! | shellへ選択を送る / shell出力を追記 | Alt+\| / Alt+! |
| / | 行コメント切替 | Space→Alt+C |

編集モードの元のAlt割当てはno_opにし、TUIOS専用という規則を明確にする。TUIOSやユーザー所有local.tomlは変更しない。insertの単語削除は上記Ctrl系へ退避し、それ以外の選択操作はEscでnormalに戻ってからメニューを使う。

## 固定UIと未対応操作

picker・prompt・popupは編集モードと別のキー処理で、config.tomlだけではキー変更できない。ユーザー判断により本体パッチを避け、次の3操作はTUIOS経由では未対応として扱う。

- 署名ヘルプの前/次候補（Alt+P/N）
- hoverの前/次ページ（Alt+P/N）
- pickerの選択項目を背後で開く（Alt+Enter）

promptのAlt+B/F（単語移動）は既存のCtrl+左右、Alt+D（次の単語削除）は既存のCtrl+Deleteで代替できる。

pickerのCtrl+Sは横分割で開く、Ctrl+Tはpreview切替、Ctrl+Nは次候補。promptのCtrl+Sは文書のカーソル位置の単語を入力、Ctrl+Wは直前の単語削除、Ctrl+Fは右へ1文字。編集モードの共通割当てではこれらを上書きしない。

Ctrl+Shift+方向の任意リサイズ、可逆ズーム、Neovimのtabpage関連操作は同等実装できないため未割当て。Ctrl+Y/Tの埋込Yazi/端末も追加せず、TUIOSのAlt+Y/Tを使う。

## 再検証

```sh
python -m venv /tmp/helix-key-tests
/tmp/helix-key-tests/bin/pip install pyte
/tmp/helix-key-tests/bin/python scripts/check-helix-keys.py --helix "$(command -v hx)"
/tmp/helix-key-tests/bin/python scripts/check-helix-keys.py --helix "$(command -v hx)" --tuios "$(command -v tuios)"
```

専用の一時HOME/XDGとPTYを使う。`--tuios`では私有daemon/sessionを作成し、終了後に私有daemonだけを停止する。保存、Undo境界、jumplist、選択反転、コピーせず削除、単語削除、分割移動、insertの行末削除、viewを閉じる操作を確認する。Shift文字はKittyのshifted Unicodeコードを使い、Ctrl+Sの単なる別名になっていないことも確認する。

実機のIME、全メニュー項目、popup、物理キー入力の受入試験は別途行う。

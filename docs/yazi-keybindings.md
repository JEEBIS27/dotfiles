# Yazi キーバインド

Helix と同じ `files/helix/key-layout.nix` の設定で論理キーを変換する。Ctrl/Alt/Super を含むキーは QWERTY のまま。入力する文字列は変換しない。

以下は現在の Graphite（hjkl → haoe）で押すキー。

| キー | 操作 |
| --- | --- |
| h/a/o/e | 親・下・上・入る |
| w/l | 次・前 |
| x/X | 選択を切り替えて下・上 |
| t | 現在の項目を選択 |
| v/V | 範囲選択 |
| Space | シェルコマンド入力 |
| d/Delete | ゴミ箱へ移動（確認あり） |
| D | カット・同じ対象のカット解除 |
| y/Y | 内部コピー・システムクリップボードにもコピー |
| Ctrl+X/C/V | カット・クリップボードへコピー・貼り付け |
| gh/ge | 親・入る |
| go/ga | ファイル一覧の先頭・末尾 |
| z/Z | 解凍・圧縮 |
| Ctrl+Enter | Helix で左右分割して開く |
| Ctrl+Shift+Enter | Helix で上下分割して開く |

貼り付けは内部のカットを優先する。外部のファイルコピーや文字列・画像は `ucp.yazi` が処理する。圧縮は `compress.yazi` の入力欄で出力名を指定する（既定は zip）。拡張子で形式を選べる。解凍は Yazi 標準の extract を使う。分割指定は Helix から開いた Yazi に限る。

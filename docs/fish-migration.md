# fishへの移行

Home Managerの共通シェルをfish 4へ移行。`modules/fish.nix`が`files/fish/`を配置する。
OmarchyではTUIOSの新しいペイン、Helixの新しい内蔵端末からfishを使用。
NixOS / Nix-on-Droidの既定シェル定義もfishへ変更。別端末の実機適用は別途必要。
古いZshソースは参照用に残すが、共通モジュールからは読み込まない。

## 残す機能

2行プロンプト（時刻、パス、Gitブランチ、変更マーク、状態別の顔文字）。
顔文字・背景の切り替えコマンドは廃止し、背景なしのパスとブランチを使用。
一覧表示・移動・Git短縮、移動時eza、extract/x、zoxide、fzf検索・Tab補完とAtuin履歴を維持。
`/`と`~`はfish標準の暗黙cd、`-`と`-1`〜`-9`はabbrによるcd/prevd。
後者はfishのディレクトリ履歴を使うため、Zshのディレクトリスタック番号とは異なる。

Ctrl+F/G/D/Yはファイル検索・文字列検索・移動先検索・Yazi。対応するd/f/g/yコマンドは提供しない。
Ctrl+RはAtuin履歴、Ctrl+Wは入力中断とTTY割り込み、Ctrl+Shift+Wは終了。
Ctrl+Escは画面消去と一覧表示。Ctrl+Lはfish側の処理を無効化。
Esc 2回で入力削除。単語移動・単語削除とHome/Endも維持。
自動入力候補・構文強調・上矢印の履歴操作はfish標準。存在するコマンドの入力色は緑（実行結果とは別）。
Atuinはローカルで履歴を記録し、既存のfish履歴は`atuin import fish`で取り込める。Zshプラグインやキーpacket変換は使わない。

## 実行後の出力取得

TUIOS内で`copy-last-output`を実行すると直前の完了コマンドの表示出力をクリップボードへコピー。
`save-last-output result.txt`は同じ出力を新しいファイルへ保存し、既存ファイルを上書きしない。
OSC 133マーカーをfishのプロンプトと実行イベントから出力し、
`tuios capture-pane --last-command --unwrap`で取得する。コマンドは再実行しない。
取得対象はTUIOSのスクロールバックに保持された表示テキストで、stdout/stderrは区別しない。
TUIや履歴上限を超えた出力の完全な原文保存には使わない。TUIOS外では明示的なエラー。
コピー/保存コマンド自体も「完了コマンド」になるため、連続呼び出しで同じ出力の保持は保証しない。

## 移行しない機能

プロンプト切り替え、pc/mc/rcと操作連結関数群、d/f/g/y、その他短縮、
行頭|によるコピー、Google検索、Ctrl+L。
NVMとenvmanは現在実体がないため旧読み込みを削除。uvの既存fish設定はそのまま利用。

## 確認の範囲

Omarchy/NixOSのHome Managerビルド、Android構成評価、fish構文・PTYでの起動とキー処理、独立TUIOSセッションでの出力コピー/保存と上書き防止、既存check-terminal.pyが通過。
実際のRio/TUIOS上でのフォント幅、描画崩れの長期再発、物理キー入力は別途確認が必要。

Omarchyのログインシェルを切り替えるには、Home Manager適用後に`bash scripts/set-login-shell.sh`を実行する。sudo認証が必要。

fishランチャーは起動前にTTYの割り込みキーをCtrl+Wへ設定し、ログインシェルを表すargv[0]も維持する。ログイン時は/etc/profileの環境をBash経由で取り込む。TUIOSとHelixはNixの絶対パスでfishを指定し、古いデーモンのPATHに依存しない。

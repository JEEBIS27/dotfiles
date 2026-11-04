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

## 入力中のパスの種別色

`packages/fish/eza-path-colors.patch`と`eza-style.rs`でfish本体の背景ハイライト処理を拡張。
`fish_color_path_by_type=1`のとき、存在する引数・リダイレクト先をeza自身で判定し、
そのファイル名の色を入力中のパス全体へ適用する。分類表を別途複製しないため、
ezaのディレクトリ・実行ファイル・リンク・特殊ファイル・拡張子や名前による分類に追従する。
`EZA_COLORS`、`LS_COLORS`、ezaの`theme.yml`/`theme.yaml`も同じものを参照する。
権限やGit状態など、ezaの一覧の別カラムを入力行へ付け足す機能ではない。

コマンド・変数・演算子・引用符の区切り・エラー・選択表示はfishの構文色を優先し、
パスとして途中まで入力した候補は従来の強調表示を保つ。
引用符で囲まれたパスは、引用符の内側の通常文字だけ種別色にする。
コマンド置換は実行せず、展開で一意に確定するパスのみを扱う。
制御文字を含む名前や、ezaの判定に失敗・時間切れになった場合は標準表示に戻る。

外部判定は背景スレッドで行い、パス・メタデータ・配色環境ごとに最大256件/2秒キャッシュ。
eza呼び出しの待ち時間は80msまでとし、出力はSGRの色・装飾だけを解釈する。
一時的に無効にするには`set -g fish_color_path_by_type 0`。
本体パッチなので、既存のfishには設定の再読み込みだけでなく新しい実行ファイルでの起動が必要。

`scripts/check-fish-path-colors.py --fish /path/to/fish --eza /path/to/eza`は、
一時HOMEとPTYで入力行を描画し、代表的な種別・色指定・無効化・置換の非実行を確認する。
実行にはPythonの`pyte`と`pexpect`が必要。

## プロンプトの開発環境表示

有効な環境を、パス・Git情報の後ろへ`[ nix:名前]`（青）、`[ venv:名前]`（黄）、`[ conda:名前]`（緑）で表示する。
アイコンはNerd FontsのNixOS・Python・Anacondaマークを使う。
Nixとvenvなどを併用している場合は併記し、実行済みの行にもその時点の環境名を残す。
環境が無効なときは表示しない。プロジェクトに設定ファイルがあるだけでは表示しない。

Nixは`IN_NIX_SHELL`と`name`、Pythonは`VIRTUAL_ENV`と`VIRTUAL_ENV_PROMPT`、
Condaは`CONDA_PREFIX`・`CONDA_DEFAULT_ENV`・`CONDA_SHLVL`から判定する。
Nixの名前がない場合は`[ nix]`、Python環境名が`.venv`などの汎用名の場合は親ディレクトリ名を使う。
`IN_NIX_SHELL`を設定しない`nix shell`などは自動検出の対象外。
言語処理系や環境管理コマンドはプロンプト表示時に起動しない。
`VIRTUAL_ENV_DISABLE_PROMPT`と`CONDA_DISABLE_FISH_PROMPT`で管理ツール側の二重表示を抑止する。

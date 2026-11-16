# tmux の一覧・ステータスバー・プラグイン

Alt+S は従来どおり標準のウィンドウ一覧を開く。矢印で項目を選び、`r` でそのウィンドウ名、`Shift+R` でその項目が属するセッション名を変更する。Enter で確定、Esc で取り消す。Delete で選択中の項目を終了する中央の丸枠ダイアログを開く。Cancel が初期選択で、n / Esc / そのままEnterは取消、yは終了。ダイアログ中に一覧の構成が変わった場合は実行せず、選び直す。ウィンドウならその中のペイン、セッションならその中のウィンドウも終了する。一覧を閉じずに続けて操作できる。名前には現在名が入力済みで、Ctrl+U で全消去できる。選択項目のアクティブペインを一時的にマークして安定したIDを取得し、マークを解除してから名前変更する。一覧以外では r/R をアプリへそのまま渡す。

一覧の SESSION 行は親のセッション、WINDOW 行はその配下のウィンドウ、展開した PANE 行はその中のペインを表す。同じ番号・名前が見えても、この親子階層は重複ではない。SESSION/WINDOW/PANE のラベルを付けて区別する。プレビューはターミナル背景に青い細枠で表示し、中央のラベル箱は表示しない。

バーは上部の2段構成で、Yaziと同じ `` / `` の丸い区切りを使う。

- 1段目: セッション名、ウィンドウ番号と名前、選択中のウィンドウ、1Passwordの呼び出しキー。
- 2段目: 現在のディレクトリ、アクティブペインで動くツール、Gitのブランチ・ahead/behind・ステージ済み/変更/未追跡など、TREE/COPY/NOR・PFX・Z・SYNC、ホスト名、時刻。

幅が狭い場合は各区切りの丸い端を保って作業情報を短縮し、ホスト名を省く。1P Alt+U は「Alt+U」の案内で、ロック解除状態を表さない。Git表示は [gitmux](https://github.com/arl/gitmux) を利用し、5秒間隔・実行上限500ms。Gitのない場所では非表示。出力記録用の script(1) が間にある場合も、Linuxの /proc から前景プロセスと実際の作業ディレクトリを確認する。SSH先のプロセス名ではなく、ローカルの ssh が表示される。

[tmux-1password](https://github.com/yardnsm/tmux-1password) は `Alt+U`（プレフィックス不要）で開く。Enter でパスワード、Ctrl+U でワンタイムパスワードをクリップボードへコピーする。Waylandの sensitive ヒントを付け、最初の貼り付け要求でクリップボードの提供を終了する。端末へ自動入力しない。1PasswordアプリのCLI連携が有効である必要がある。既定のアカウント指定は上流と同じ `my`。別のアカウントでは `set -g @1password-account 'アカウントの略称'` を設定する。

上流のコミットをNixで固定し、Wayland対応と現行CLIのデスクトップ連携を追加している。セッショントークンをファイルに保存せず、op の認証はユーザーがプラグインを開いたときだけ実行する。ステータス更新では実行しない。TPMの手動インストールは不要。

設定本体は files/tmux/tmux.conf、表示の補助処理は files/tmux/status.py、プラグイン定義は packages/tmux-1password.nix。Home Managerで生成・適用する。

次に追加する候補（未導入）:

| プラグイン | 役割・使いどころ |
| --- | --- |
| [extrakto](https://github.com/laktak/extrakto) | 端末出力中のパスやURLを検索してコピー・挿入。マウス操作を減らしたい場合の第一候補。 |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) + [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | レイアウトやディレクトリの保存・復元と定期保存。実行中プロセスのメモリ状態を保存するものではなく、プログラムは対応範囲で再起動する。 |
| [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) | セッションをあいまい検索・プレビュー。プロジェクトごとに多数のセッションを使う場合に便利。 |

COPY/PREFIXなどはtmux標準のformatで表示できるので、そのためだけのプラグインは不要。CPU・メモリ・バッテリーを常時追加するより、まず作業情報を優先する。追加情報としてはSSHの接続先や長時間コマンドの完了通知が役に立つ。

検証:

```sh
python3 scripts/check-tmux-workflow.py --config ~/.config/tmux/tmux.conf
python3 scripts/check-native-keybindings.py --tmux-config ~/.config/tmux/tmux.conf --ghostty-config ~/.config/ghostty/config
```

前者は私有tmuxサーバーとPTYで、選択中ウィンドウ/セッションの名前変更、引用符を含む名前、一覧の維持、popupの開閉、通常入力の転送を確認する。1Passwordの実アカウントから秘密を取得するテストは行わない。

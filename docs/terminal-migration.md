# Rio + TUIOS

Rioを描画・入力、TUIOSを唯一のマルチプレクサとして使う。移行元のWezTerm・tmux・Herdr設定は削除し、Git履歴からのみ復元できる。

## 構成

| 層 | 移行前 | 移行後 |
|---|---|---|
| 描画・フォント・IME・端末プロトコル | WezTerm | Rio 0.5.28 |
| 分割・ウィンドウ・ワークスペース・セッション | WezTerm / tmux / Herdr | TUIOS 0.10.1 |
| コピー・検索・scratch・agent状態 | 各アプリに分散 | TUIOS |
| ターミナル起動 | WezTerm固有CLI | `jeebis-terminal` → Rio → TUIOS |
| Codex | 専用Herdr serverとSHELL差替え | 専用Rio app-id、新規TUIOS sessionのcommand pane |
| 色 | WezTerm用生成物 | 共通palette → `rio.toml` → Rio `Desktop`テーマ |

フォントはHackGen35 Console NF、14、通常文字もBold（700）、余白14を維持。RioのナビゲーションをPlain、splitを無効化し、スクロールバックはTUIOSに50,000行集約する。透明度・blurはRioに設定せずHyprlandで管理する。

`files/rio/config.toml`、`files/tuios/config.toml`、XDG端末選択・desktop entryをHome Managerで管理する。通常の`rio`単独起動も`shell.args = ["new"]`により新規TUIOS sessionを作る。

## パッケージとOS

既存の`nixpkgs-apps`固定コミットに両パッケージがあるため、flake入力・lockは更新していない。TUIOSは共通のHome Managerパッケージ、RioはNixOSではHome Managerのnixpkgsパッケージ。NixOS systemPackagesへの重複登録はしない。

OmarchyではGPUドライバと整合するArchのRioを使用し、Home ManagerからRioを導入しない。適用の承認後に、既存方針どおり `omarchy pkg add rio` を実行する。TUIOSはNixから導入し、pacman/AURから重複導入しない。既に導入済みなら所有元・バージョンを先に確認する。ArchのRioが0.5.28未満なら、この設定を適用する前にパッケージを更新して再検証する。Nix製RioをArch上で直接実行するGPUライブラリwrapperは不要。

NixOSのGPU設定は既存ホストのhardware構成を引き継ぐ。実機のドライバ、IME、認証情報をこの移行で変更しない。Codex CLI本体・認証も従来の導入元を維持する。

## 起動・復帰

```sh
jeebis-terminal                            # 必ず新規session
jeebis-terminal --cwd ~/src                # 新規sessionの初期cwd
jeebis-terminal -- nvim README.md          # 新規sessionにコマンドを1つ起動
jeebis-codex-tuios                         # Codex用app-id

tuios ls
jeebis-terminal --attach SESSION           # 明示的な復帰
```

引数なしの`tuios`は最終利用sessionへ接続するので、ランチャーでは使わない。通常起動は`tuios new`の自動採番、コマンド起動はUUID名で他sessionとの衝突を防ぐ。コマンド用session作成後、最初のshellのIDを保存し、コマンドpane作成に成功してからそのshellだけを閉じる。他のsessionを検索して再利用・破棄しない。失敗時のsessionは復旧用に残す。

同じ名前を指定した`--attach`だけが意図的な共有になる。複数clientで共有した場合のviewport調整はTUIOS標準の方針に従う。デタッチ・Rioを閉じる操作ではdaemonがプロセスを保持する。daemon再起動後は保存されたレイアウト・cwdに新しいshellを作るので、プロセス自体が再起動を越えて生存するわけではない。agentの会話復帰はTUIOSの`resume-agent`とharnessの対応に依存する。

HyprlandのSuper+N、Super+Alt+Enter、Super+Enterの右分割・既存上下分割、Super+Alt+DのCodex起動を新ランチャーへ変更した。旧Super+Ctrl+Enterと旧multiplexerヘルプキーは解除した。Codexの最大化判定はタイトル推測から専用app-idへ変更した。

## アプリ連携

- Neovim：OSC 1337のファイル名通知とtmux passthroughを削除。既存True Color・wl-clipboard優先/OSC 52 fallback・入力設定を維持する。
- Zsh：ZLE中だけKitty Keyboard Protocolをpush/popする。`$TMUX`分岐、Herdr scratch専用フラグとキー終了処理を削除。scratchの表示切替はTUIOSが担当する。
- Yazi：既存`y`関数をTUIOSカスタムpaneで起動し、cwdを継承する。両実装にKitty Graphics/Unicode placeholder対応があり、TUIOSはRioを検出するため、独自passthrough・TERM偽装・tmux shimを追加しない。描画と終了後の消去は実機確認待ち。
- Codex：paneの実プロセスを起動してTUIOS標準検出・rail・Inbox・OSC 9通知を使う。より正確なhook報告は、適用承認後に `tuios integration install codex` と `tuios integration status` / `tuios doctor agents` で設定する。これはユーザーのCodex設定・skill等を更新する操作なので今回実行していない。hook未導入時は画面・process等による推定にとどまる。通知とapprovalの完全一致は未確認。
- worktree：Alt+Shift+Gでブランチ名を入力し、公式`worktree new --detach`で作成する。新sessionへの自動focusはせずrailで選択する。削除やmergeを自動実行しない。

Rioは設定ディレクトリだけを監視する。生成テーマのリンク先が入れ替わったとき、Omarchyの`refresh-rio.hook`とNixOSのtheme adapterがRio設定ディレクトリのmtimeを更新して再読込を促す。稼働中のRio/TUIOSの色更新は実機確認待ち。

## 互換範囲と制限

[キーの全移行表](terminal-keybindings.md)に旧キーと差異を記載した。TUIOS windowはPTYペインで、旧タブコンテナと同じではない。タブを束ねる操作、タブ順序交換、旧WezTermコピー選択の一部、端末固有透過切替などは完全再現していない。ダミー設定は置かない。

TUIOS 0.10.1のHerdr互換は77/102 socket methods。`layout.*`、`workspace.move`、`agent.view.*`、pane scroll/clear/selection、integrationや実Herdr server管理の一部は非対応。Herdr設定ファイルの互換読込ではない。TUIOS自身が互換環境変数/socketを公開するが、この構成はそれに依存しない。

tmux shimは`tuios tmux-shim -- COMMAND`で起動した子だけに適用する任意機能であり、通常起動では使わない。全tmux設定の互換ではなく、layout/styleは一部no-op、split flagsの位置指定は反映されず、swap-pane非対応、control modeのoutputに実データは流れない。旧設定を読み込ませる用途には使わない。

## 削除対象とローカルの扱い

PRで削除するのは次のGit管理設定と参照。

- `files/wezterm/`全体、`files/herdr/config.toml`、`files/tmux.conf`
- `files/nvim/lua/config/wezterm.lua`とrequire・Home Managerリンク
- `files/desktop/helpers/jeebis-codex-herdr`、旧テーマtemplate
- tmux/WezTermパッケージ、旧設定リンク、旧CLI引数、キー変換・SHELL差替え
- 同梱desktop-runtimeの旧起動キー・旧メニュー項目、バーの旧端末タイトル解析

調査した現行の`~/.config/wezterm/*`、`~/.config/herdr/config.toml`、`~/.config/tmux/tmux.conf`、Neovim設定と旧helperはHome Managerのstoreリンク。承認後のHome Manager switchで、前世代が管理した削除対象リンクが整理される。Herdrのログ・socket・session snapshotなどGit管理外データは今回削除しない。手動ファイルやStow等のリンクが混在する場合は所有元を確認し、Home Managerの衝突エラーを解決してから適用する。無条件の`rm ~/.config/...`はしない。

旧アプリ本体がpacman等で別途導入されていても、今回のPR作成では削除しない。実機検証・承認後に依存する他アプリがないか確認し、各管理元で整理する。

## 検証

2026-10-24、隔離チェックアウトで実施。本番へのswitch、Hyprland reload、シェル再起動、旧実ファイル削除は行っていない。

| 検査 | 結果 |
|---|---|
| 変更Nix/Lua/Bash/Zsh/Python構文 | 成功 |
| 新helper・テーマhookのShellCheck | 成功 |
| Rio・TUIOS TOML parse、Rio 0.5.28実装の項目・CLI照合 | 成功。Rioに専用checkコマンドはなく、ネイティブ設定読込とGPU起動は未実施 |
| TUIOS 0.10.1 `keybinds doctor --json` | 自作キーのcollision・invalid key・command errorなし |
| `python scripts/check-terminal.py` | 成功。私有HOME/XDGとPTYでsession分離・cwd・split・Alt+Enter・Alt+Shift+N・Alt+N・Alt+D後の明示的再接続・command launcher・worktree popup・全paletteのテーマ生成を検証 |
| Home Manager Omarchy / NixOS activationPackage build | 成功（適用なし） |
| `nix flake check` | 成功 |
| NixOS desktop-vm toplevel評価・ビルド | 成功（VM起動なし） |
| バーのWindowOrder JavaScript既存テスト | 成功。Quickshell実機表示は未確認 |
| 全リポジトリ旧名称検索・`git diff --check` | 成功。旧名称は移行説明文と隔離テストの継承環境除外だけ |

再検証例（buildは適用しない）：

```sh
python scripts/check-terminal.py
nix --extra-experimental-features 'nix-command flakes' flake check --no-build
nix --extra-experimental-features 'nix-command flakes' build '.#homeConfigurations.jeebis@omarchy.activationPackage' --no-link
nix --extra-experimental-features 'nix-command flakes' build '.#homeConfigurations.jeebis@nixos.activationPackage' --no-link
nix --extra-experimental-features 'nix-command flakes' build '.#nixosConfigurations.desktop-vm.config.system.build.toplevel' --no-link
```

既存の`dockerfile-language-server-nodejs`改名警告はこの移行の範囲外。ホスト固有のNixOS構成・GPU実機はdesktop-vm buildでは検証できない。

## 実機受入チェック（すべて未確認）

承認後、旧ターミナルを1つ残して試す。各OSで記録し、全項目を確認するまでmergeしない。

- [ ] Rio 0.5.28以上 / TUIOS 0.10.1、GPU描画、HackGenの太さ・サイズ・余白・テーマ
- [ ] Fcitx5 / Mozkeyで日本語入力、変換・確定・キャンセル、分割paneとscratchでIME候補位置
- [ ] NeovimのTrue Color、Ctrl系・Shift+Enter等の入力、コピー/貼付け
- [ ] YaziでPNG/JPEGプレビュー、分割・resize・スクロール・scratch重なり、終了後の画像消去/カーソル/入力正常化
- [ ] OSC 52書込みを `printf '\033]52;c;dGVzdA==\a'` で確認（clipboardをtestに変更する）
- [ ] キー移行表、コピー検索、日本語のコピー、mouse event転送、Ctrl+Shift+C/V
- [ ] Rioを2つ起動して別sessionになること、Alt+D後に指定名で復帰し同じプロセスが続くこと
- [ ] daemon再起動後の保存レイアウト・cwd・必要なagent会話復帰（生プロセス復元とは区別）
- [ ] Codex起動、hook導入後の状態・承認待ち・終了通知、Alt+O対象、rail/Inbox
- [ ] Alt+Shift+Gのworktree popup、railから新session選択
- [ ] Hyprland起動ショートカット、Codex最大化、OS分割、XDG経由のTUI起動
- [ ] 起動中Rio/TUIOSのテーマ切替と日本語入力・画像を合わせて確認

## ロールバック

適用前ならPRをmergeせず、旧チェックアウトと稼働環境をそのまま使用できる。適用済みなら、事前に記録したHome Manager世代の`activate`（またはNixOSの旧system世代）へ戻す。Gitは移行前コミットから別チェックアウトを作って再ビルドする。未コミット変更を伴うcheckoutへ`reset --hard`しない。旧sessionの状態は新しいTUIOSへ自動変換しないので、旧アプリとユーザーデータの削除は受入完了後まで待つ。

## 公式参照

- [Rio設定](https://rioterm.com/docs/config)、[キー](https://rioterm.com/docs/key-bindings)、[0.5.28実装](https://github.com/raphamorim/rio/tree/v0.5.28)
- [TUIOS設定](https://tuios.dev/docs/configuration)、[キー](https://tuios.dev/docs/keybindings)、[session](https://tuios.dev/docs/sessions)、[agents](https://tuios.dev/docs/agents)
- [TUIOS 0.10.1実装](https://github.com/Gaurav-Gosain/tuios/tree/v0.10.1)、[Herdr互換](https://github.com/Gaurav-Gosain/tuios/blob/v0.10.1/skills/tuios/herdr.md)、[tmux shim](https://github.com/Gaurav-Gosain/tuios/blob/v0.10.1/skills/tuios/tmux.md)

The native gear menu and writable settings are documented in [tuios-settings-menu.md](tuios-settings-menu.md).

# Git経由でNixOSに導入する

対象はインストール済みNixOS、x86_64-linux、ユーザーjeebis。
Gitにはアプリ・設定・サービスの宣言を保存する。Google Driveの実ファイル、アプリ履歴・認証情報は含めない。rcloneの認証は別途行う。

## 初回

移行先でGitがなければ `nix-shell -p git` で利用できる。

```bash
git clone https://github.com/JEEBIS27/dotfiles.git ~/dotfiles
cd ~/dotfiles
nix --extra-experimental-features 'nix-command flakes' run "path:$PWD#just" -- switch
```

初回の `just switch` は既存の/etc/nixosを日時付きでバックアップし、OS設定と共通デスクトップ・Home Managerを接続するflakeを生成・ビルドして適用する。
先にビルドで確認する場合は初回コマンドの末尾を `-- build` にする。この場合も統合flakeを生成するが、稼働環境は切り替えない。確認後に同じNixコマンドの末尾を `-- switch` にして適用する。
設定生成とビルドだけを明示的に行う `just setup` も残している。別デスクトップ・IME等が既存設定で有効なら、必要に応じて/etc/nixos/configuration.nixを整理する。
既存flakeがある場合は生成をスキップし、上書きしない。dotfilesが未統合なら自動追加はしないため、dotfiles入力とdotfiles.nixosModules.personalを既存flakeに統合する。

configuration.nixから読み込むハードウェア・ディスク・ブート設定、ユーザーとパスワード、system.stateVersionは移行先の既存値を維持する。VM用の仮ディスク定義は使わない。Home Managerの管理先に既存の実ファイルがある場合は、エラーに出た対象だけを退避して再実行する。強制上書きはしない。

適用後は再起動し、SDDMのログイン画面からHyprland（UWSM）へログインする。共通モジュールはSDDMと既定セッションを追加するため、インストーラーではデスクトップなしを選べる。Plasma本体は導入しない。自動ログインは設定しない。既存設定で別のログインマネージャーを有効にしている場合は、SDDMとの重複を解消してから適用する。ログイン画面はSDDM + Astronaut（astronautデザイン）。テーマとQt依存は固定済みNixpkgsから導入する。jeebis-desktopのプリセット配色とロック壁紙をログイン画面にも適用する。

## 更新

```bash
cd ~/dotfiles
just sync
```

Gitをfast-forwardで更新し、/etc/nixos側が参照するローカルリポジトリのスナップショットを更新してswitchする。リポジトリ内flake.lockのパッケージ固定は更新しない。未コミット変更によるpull失敗時は停止する。同期処理はGitにある宣言が対象で、Google Driveのファイル同期とは独立している。

ローカル編集だけを適用する場合は `just switch`、適用せず確認する場合は `just build` を指定する。justは構成の一部として導入される。既存の `bash scripts/nixos.sh {setup|build|switch|sync}` も利用できる。NixOS側はこの方式に統一し、別途home-manager switchは実行しない。

## 復旧

```bash
sudo nixos-rebuild switch --rollback
```

起動できなければブートメニューから旧世代を選ぶ。OSの世代切替はGoogle Driveの実データや書き込み可能な設定ファイルの変更を巻き戻さない。初回導入時の/etc/nixosバックアップは別途残る。

## 対応範囲

実機のGPU・スリープ・音声等はハードウェアごとに確認する。外部プラグイン取得・クラウド認証・一部GUIアプリ本体の導入は別途必要。[パッケージ一覧](managed-items.md)、[入力・マウント](input-and-mounts.md)を参照。

## 移行先で別途用意するもの

- GPUドライバー、ディスク・ブート・暗号化、ユーザーとパスワード、ホスト名は移行先のOS設定で管理する。
- タイムゾーン・ロケール・コンソール配列はAsia/Tokyo・ja_JP.UTF-8・jp106を既定値とし、移行先の明示設定を優先する。Hyprlandの共通配列はjp/jp106。
- Wi-Fi認証、rclone、Git/SSH、アプリのログイン・ライセンス等の秘密情報は同期しない。
- モニター配置・倍率は機種ごとに確認する。書き込み可能なmonitors.luaの変更はGitへ自動反映しない。
- 指紋認証、プリンター、VPN、独自ハードウェア等は必要なPCだけOS側に追加する。
- 音声・Bluetooth・NetworkManager・電源管理・Hyprland・IME・デスクトップシェルは共通構成の対象。実機での動作確認は別途必要。

GNOME KeyringとSDDMログイン時の解除連携を含む。SDDM以外のgreeterとブートスプラッシュは追加していない。詳しい管理対象と対象外は[同期範囲の監査](sync-audit.md)を参照。

既定ブラウザーはHelium。公式Linux AppImageを`packages/helium.nix`でバージョン・ハッシュ固定して導入する。ブラウザープロファイル・認証情報は管理しない。更新時はバージョンと公式アセットのハッシュを同時に更新する。

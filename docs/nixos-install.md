# Git経由でNixOSに導入する

対象はインストール済みNixOS、x86_64-linux、ユーザーjeebis。
Gitにはアプリ・設定・サービスの宣言を保存する。Google Driveの実ファイル、アプリ履歴・認証情報は含めない。rcloneの認証は別途行う。

## 初回

移行先でGitがなければ `nix-shell -p git` で利用できる。

```bash
git clone https://github.com/JEEBIS27/dotfiles.git ~/Git/home-manager
cd ~/Git/home-manager
bash scripts/nixos.sh setup
bash scripts/nixos.sh switch
```

setupは既存の/etc/nixosを日時付きでバックアップし、OS設定と共通デスクトップ・Home Managerを接続するflakeを生成してビルドする。稼働環境はまだ切り替えない。ビルド結果と既存OS設定の重複を確認してからswitchする。別デスクトップ・IME等が既存設定で有効なら、必要に応じて/etc/nixos/configuration.nixを整理する。
既存flakeがある場合は上書きせず停止する。その場合はdotfiles入力とdotfiles.nixosModules.personalを既存flakeに統合する。

configuration.nixから読み込むハードウェア・ディスク・ブート設定、ユーザーとパスワード、system.stateVersionは移行先の既存値を維持する。VM用の仮ディスク定義は使わない。Home Managerの管理先に既存の実ファイルがある場合は、エラーに出た対象だけを退避して再実行する。強制上書きはしない。

適用後はログアウトし、Hyprlandセッションへログインする。ログイン画面の設定は移行先のものを使う。現在の共通モジュールは独自のログイン画面を導入しない。

## 更新

```bash
bash ~/Git/home-manager/scripts/nixos.sh sync
```

Gitをfast-forwardで更新し、/etc/nixos側が参照するローカルリポジトリのスナップショットを更新してswitchする。リポジトリ内flake.lockのパッケージ固定は更新しない。未コミット変更によるpull失敗時は停止する。同期処理はGitにある宣言が対象で、Google Driveのファイル同期とは独立している。

ローカル編集だけを適用する場合はswitch、適用せず確認する場合はbuildを指定する。NixOS側はこの方式に統一し、別途home-manager switchは実行しない。

## 復旧

```bash
sudo nixos-rebuild switch --rollback
```

起動できなければブートメニューから旧世代を選ぶ。OSの世代切替はGoogle Driveの実データや書き込み可能な設定ファイルの変更を巻き戻さない。初回導入時の/etc/nixosバックアップは別途残る。

## 対応範囲

実機のGPU・スリープ・音声等はハードウェアごとに確認する。外部プラグイン取得・クラウド認証・一部GUIアプリ本体の導入は別途必要。[パッケージ一覧](managed-items.md)、[入力・マウント](input-and-mounts.md)を参照。

# 新規 minimal NixOS から環境を構築する

対象は x86_64 の NixOS とユーザー `jeebis`。インストーラーでは minimal 構成を選び、デスクトップ環境は追加しない。デスクトップ、Niri、SDDM、Fcitx5、基本アプリは dotfiles から導入する。

## 1. NixOS をインストールする

インストーラーでディスクとブート方式を設定し、NixOS を起動できる状態にする。インストール時に作成する `/etc/nixos/configuration.nix` と `hardware-configuration.nix` は、この PC 固有の設定として残す。

初回起動に必要な点を確認する。

- ユーザー名を `jeebis`、ホームを `/home/jeebis` にする。
- `jeebis` を `wheel` グループに加え、sudo を使えるようにする。
- ネットワーク接続を用意する。
- GPU など固有のハードウェア設定を確認する。特に NVIDIA は適切な NixOS ドライバー設定が必要。

dotfiles は `jeebis` として実行する。別の管理ユーザーでインストールした場合は、先に `jeebis` のログインと sudo を設定する。

## 2. dotfiles を取得して適用する

端末にログインし、次を実行する。

```bash
nix-shell -p git
git clone https://github.com/JEEBIS27/dotfiles.git ~/dotfiles
cd ~/dotfiles
nix --extra-experimental-features 'nix-command flakes' run "path:$PWD#just" -- switch
```

初回の `just switch` は、既存の `/etc/nixos` を日時付きでバックアップし、そこに統合用 `flake.nix` を生成してビルド・適用する。途中でパスワードを求められたら `jeebis` の sudo パスワードを入力する。ビルドや適用が失敗した場合は、最初のエラーを確認してから続ける。

適用後、PC を再起動する。SDDM のログイン画面で **Niri** セッションを選んでログインする。初回は desktop、IME、テーマなどの初期設定が行われる。

## 3. 更新と個別操作

```bash
cd ~/dotfiles
just sync
```

`just sync` は Git の fast-forward pull 後に設定を適用する。ローカルのコミットを使って適用するときは `just switch`、適用せずビルド確認だけ行うときは `just build` を使う。

初回に clone した公開リポジトリの取得には GitHub 認証は不要。push 用の HTTPS 認証が必要になったら、1Password を設定して `just git-auth` を実行する。初回の取得に認証が必要なら `just git-auth-web` を使う。[認証手順](authentication.md)を参照。

## 注意点

- `/etc/nixos` に既存の `flake.nix` がある場合、自動生成は行わない。既存 flake に dotfiles input と `dotfiles.nixosModules.personal` を手動で統合する。
- ハードウェア、ディスク、ブート、ホスト固有の GPU 設定、ユーザーとパスワード、`system.stateVersion` はこの PC の NixOS 設定で管理する。VM 用の仮ディスク設定を使わない。
- TPM measured boot は初回構築に必要ない。別途有効化する場合だけ [TPM 設定手順](nixos-tpm-unlock.md)を参照する。
- GitHub、rclone、アプリのログイン、ライセンスなどの認証情報は同期しない。rclone の設定やクラウドの実ファイルも別途用意する。
- Home Manager が既存ファイルとの衝突で停止した場合、エラーに表示されたファイルを確認する。ファイルの内容が必要なら先にバックアップし、対象を確認してから再実行する。

切り替え後に起動できない場合は、ブートメニューから以前の NixOS 世代を選ぶ。起動後に戻す場合は次を使う。

```bash
sudo nixos-rebuild switch --rollback
```

# 個別ログインと認証

Nix はアプリと CLI、just は各ユーザーのログイン操作を管理する。認証は `sudo just ...` ではなく通常ユーザーで実行する。秘密情報は Git や Nix 式に書かない。

## 最初の導入

既に `just git-auth` で GitHub にログイン済みなら、その認証を使って `just switch` を実行できる。まだ 1Password がない初回導入では `just git-auth-web` → `just switch` の順に進める。MejiroIME は非公開なので、読み取り権限のある GitHub アカウントが必要。

NixOS は NixOS モジュールで 1Password アプリと CLI、Polkit の許可、CLI の setgid ラッパーを導入する。Omarchy は Home Manager でアプリ・CLI を導入するが、Linux のアプリ連携に必要なホスト側の権限設定は別途必要。Android はこの PC 用の 1Password 構成の対象外。

```bash
just op-auth
```

1Password アプリにログインし、Settings > Security でシステム認証による解除、Settings > Developer で CLI 連携を有効にする。`op-auth` はアプリを開いて `op whoami` で接続を確認する。初回のアカウント追加や CLI 連携スイッチはアプリ内で操作する。

## GitHub

GitHub の personal access token (PAT) を 1Password に保存する。対象の非公開リポジトリの Contents 読み取り権限が必要。push にも使う場合は書き込み権限も付ける。GitHub アカウントのパスワードは使用しない。

1Password の対象フィールドから secret reference をコピーして実行する。

```bash
just git-auth 'op://Vault/GitHub/token'
# 引数を省略すると参照を対話入力する
just git-auth
just gh auth status
just gh repo list
```

`git-auth` は PAT が有効か確認し、参照文字列だけをローカルの Git 設定へ保存する。Git の HTTPS helper は必要時に `op read` で PAT を取得し、Git の credential protocol にのみ返す。GitHub CLI は `just gh ...` で同じ参照を使う。トークン本体を設定ファイルへ書き出さない。以前の `gh` の認証は自動削除しない。

1Password を使わない場合は `just git-auth-web` でブラウザー認証に戻せる。

`just switch` / `just build` は `/etc/nixos` の一時コピーを作り、入力取得とビルドを通常ユーザーとして実行する。NixOS の適用と統合ロックの保存にだけ sudo を使用する。一時コピーは終了時に削除する。root に 1Password のトークンは渡さない。

## Google Drive / OneDrive

```bash
just rclone-auth gdrive
just rclone-auth onedrive
# 両方を順に設定する場合
just rclone-auth
just rclone-start
```

未作成なら対話設定を開く。名前を `gdrive` / `onedrive`、種類を `drive` / `onedrive` として作成し、ブラウザーで OAuth を承認する。既存なら `rclone config reconnect` で再認証し、既存設定を保持する。設定は `~/.config/rclone/rclone.conf`（XDG_CONFIG_HOME を指定した場合はその配下）に保存し、権限を 600 にする。実行中のマウントは自動再起動しない。

## コマンドの使い分け

| コマンド | 用途 |
|---|---|
| `just switch` | 現在の設定を適用 |
| `just build` | 適用せずビルド |
| `just sync` | GitHub の設定を pull して適用 |
| `just update-apps` | アプリ用 unstable ロックを更新して適用 |
| `just setup` | NixOS 統合設定の初回作成とビルド |
| `just auth-status` | 1Password / GitHub の設定状態と rclone の remote 名を確認 |
| `just check` | セットアップ・認証処理のモックテストと構文検査 |

ChatGPT・Slack・Spotify・ブラウザーなど GUI アプリのログインは各アプリ内で行う。rclone の OAuth は 1Password のパスワードでは代替できない。

参考: [1Password CLI のアプリ連携](https://developer.1password.com/docs/cli/get-started/)、[GitHub の PAT と 1Password](https://developer.1password.com/docs/cli/shell-plugins/github/)、[rclone reconnect](https://rclone.org/commands/rclone_config_reconnect/)。

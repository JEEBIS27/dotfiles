# 日本語入力・クラウドマウント

## Fcitx / Mozkey

Fcitxの設定・プロファイルとMozkeyの`config1.db`を管理する。入力方式はMozkey、切替キーはControl+Space。学習履歴・ユーザー辞書・認証情報は含めない。

```bash
nix build .#mozkey-fcitx5
./result/bin/mozkey-fcitx5 --check-runtime
./result/bin/mozkey-fcitx5 --check-model
```

WaylandのGTK / Qt入力を想定する。X11 / XWayland用Qtプラグインには未解決の入力問題あり。

## NixOS / MejiroIME

新しい Fcitx 入力コンテキストは IME オフで始まり、すでに開いている別コンテキストのオン・オフを引き継ぎません。フォーカスを戻したときは、そのコンテキストの状態を維持します。明示的なオン・オフのキーや他の Fcitx 設定はそのままです。同じ Fcitx コンテキストを複数の入力欄に使用するアプリでは、そのコンテキスト内で状態が共有されます。

## rclone

| リモート名 | マウント先 | user unit |
|---|---|---|
| `gdrive` | `~/GoogleDrive` | `rclone-gdrive` |
| `onedrive` | `~/OneDrive` | `rclone-onedrive` |

認証は`~/.config/rclone/rclone.conf`に保存する。

```bash
just rclone-auth
just rclone-start
systemctl --user status rclone-gdrive rclone-onedrive
```

未作成なら上表の名前で対話設定し、既存なら再認証する。[認証とセットアップ](authentication.md)を参照。

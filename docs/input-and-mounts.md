# 日本語入力・クラウドマウント

## Fcitx / Mozkey

Fcitxの設定・プロファイルとMozkeyの`config1.db`を管理する。入力方式はMozkey、切替キーはControl+Space。学習履歴・ユーザー辞書・認証情報は含めない。

```bash
nix build .#mozkey-fcitx5
./result/bin/mozkey-fcitx5 --check-runtime
./result/bin/mozkey-fcitx5 --check-model
```

WaylandのGTK / Qt入力を想定する。X11 / XWayland用Qtプラグインには未解決の入力問題あり。

## rclone

| リモート名 | マウント先 | user unit |
|---|---|---|
| `gdrive` | `~/GoogleDrive` | `rclone-gdrive` |
| `onedrive` | `~/OneDrive` | `rclone-onedrive` |

認証は`~/.config/rclone/rclone.conf`に保存する。

```bash
rclone config
systemctl --user start rclone-gdrive rclone-onedrive
systemctl --user status rclone-gdrive rclone-onedrive
```

`rclone config`で上表の名前のリモートを作る。

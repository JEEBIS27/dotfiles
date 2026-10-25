# dotfiles

Omarchy / NixOS向けのHome Manager構成。Hyprland、Quickshell（Ruixen）、ターミナル・エディター設定とアプリを管理する。

現構成は `x86_64-linux`・ユーザー `jeebis`・配置先 `~/Git/home-manager` を前提とする。他の環境ではユーザー名・パス・ハードウェア設定の変更が必要。

## 構成

```text
.
├── flake.nix / flake.lock   # 入力の固定・Home Manager・NixOSモジュール
├── home.nix                # Home Managerの共通設定
├── hosts/                  # Omarchy / NixOSの切替
├── modules/                # アプリ・設定ファイル・サービス
├── nixos/                  # NixOSのデスクトップ設定
├── files/                  # アプリ設定・Hyprland・シェル設定・テーマ・壁紙
├── packages/               # Mozkey・Quickshell・デスクトップ用パッケージ
├── vendor/desktop-runtime/ # 同梱シェル基盤
├── scripts/nixos.sh        # NixOSの初期設定・ビルド・適用・更新
└── docs/                   # 導入・構成・ツールの説明
```

## 導入内容

| 分類 | 主な内容 |
|---|---|
| シェル・CLI | Zsh、TUIOS、Sheldon、Yazi、Git、fzf、ripgrep、eza、bat、zoxide |
| エディター | Helix（既定）、共通LSP・フォーマッター、Neovim（代替） |
| デスクトップ | Hyprland、Quickshell + Ruixen、Rio + TUIOS、固定テーマと壁紙 |
| NixOS用アプリ・サービス | Chromium、Nautilus、Fcitx5 / Mozkey、音声・Bluetooth・電源管理 |
| クラウドマウント | rclone（Google Drive / OneDrive、認証は別途） |

Omarchyでは既存のデスクトップ・IME本体を使用する。Rio本体はOmarchyのパッケージ管理、TUIOSはHome Managerで導入する。[パッケージ一覧](docs/managed-items.md)を参照。

## NixOSへの導入

インストール済みNixOSで実行する。`setup`は既存OS設定をバックアップしてビルドし、`switch`で適用する。

```bash
git clone https://github.com/JEEBIS27/dotfiles.git ~/Git/home-manager
cd ~/Git/home-manager
bash scripts/nixos.sh setup
bash scripts/nixos.sh switch
```

以後の更新:

```bash
bash ~/Git/home-manager/scripts/nixos.sh sync
```

既存flakeがある場合や復旧方法は[導入手順](docs/nixos-install.md)を参照。

## Omarchyへの適用

NixとHome Managerが導入済みの環境で実行する。Rio本体は `omarchy pkg add rio` で導入する。移行時は先に[検証・制限事項](docs/terminal-migration.md)を確認する。

```bash
home-manager build --flake "path:$HOME/Git/home-manager#jeebis@omarchy"
home-manager switch --flake "path:$HOME/Git/home-manager#jeebis@omarchy"
```

## ドキュメント

- [Rio + TUIOS：移行・検証・ロールバック](docs/terminal-migration.md)
- [ターミナルキーの移行表](docs/terminal-keybindings.md)

- [構成とOS別バックエンド](docs/desktop-architecture.md)
- [導入するパッケージ・設定](docs/managed-items.md)
- [jeebis-shell（Ruixenベース）](docs/ruixen-shell.md)
- [テーマツール：配色・壁紙の設定と切替](docs/theme-tooling.md)
- [日本語入力・クラウドマウント](docs/input-and-mounts.md)

認証情報・履歴・キャッシュ・実データは管理対象外。外部プラグインの取得やクラウド認証は別途必要。第三者コード・テーマ・壁紙は各配布元のライセンスに従う。

## キーバインド一覧

| キー | 動作 |
|---|---|
| Super+F | Ruixen App Launcher（バー左端と同じアプリ起動） |
| Super+Shift+Esc | Ruixen設定 |

Hyprlandが処理する。旧Ruixen用のSuper+Alt+Space・Super+Shift+Alt+Space・Super+R・Super+Shift+Rは解除する。既存のSuper+Escはシステムメニューとして維持する。

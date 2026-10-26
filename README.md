# dotfiles

Omarchy / NixOS / Android（Nix-on-Droid）向けのHome Manager構成。Hyprland、Quickshell（jeebis-shell）、ターミナル・エディター設定とアプリを管理する。

PC構成は `x86_64-linux`・ユーザー `jeebis`・配置先 `~/Git/home-manager` を前提とする。Androidは `aarch64-linux`、Nix-on-Droid既定のユーザーとホームを使用する。他の環境ではユーザー名・パス・ハードウェア設定の変更が必要。

## 構成

```text
.
├── flake.nix / flake.lock   # 入力の固定・Home Manager・NixOSモジュール
├── justfile                # 共通入口: switch / build / sync / host
├── home.nix                # PC用Home Manager構成
├── hosts/                  # Omarchy / NixOS / Androidの入口
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
| デスクトップ | Hyprland、Quickshell + jeebis-shell、Rio + TUIOS、固定テーマと壁紙 |
| NixOS用アプリ・サービス | Chromium、Nautilus、Fcitx5 / Mozkey、音声・Bluetooth・電源管理 |
| クラウドマウント | rclone（Google Drive / OneDrive、認証は別途） |

Omarchyでは既存のデスクトップ・IME本体を使用する。Rio本体はOmarchyのパッケージ管理、TUIOSはHome Managerで導入する。[パッケージ一覧](docs/managed-items.md)を参照。

## 導入（共通コマンド）

Nix導入後（AndroidはNix-on-Droidの初回セットアップ後）、各OSで同じコマンドを使う。
Gitがなければ先に `nix-shell -p git` を起動する。

```bash
git clone https://github.com/JEEBIS27/dotfiles.git ~/Git/home-manager
cd ~/Git/home-manager
nix --extra-experimental-features 'nix-command flakes' run "path:$PWD#just" -- switch
```

初回はNixからjustを一時起動する。適用時にjustも導入されるので、セッションを開き直した後は次の短いコマンドを使える。

```bash
cd ~/Git/home-manager
just host     # OS判定だけを確認
just build    # ビルドのみ
just switch   # ローカルの構成を適用
just sync     # Gitをfast-forwardで更新して適用
```

| 環境 | `just switch` の処理 |
|---|---|
| Omarchy | 固定したHome Manager CLIをNixで起動し、`jeebis@omarchy`を適用 |
| NixOS | 初回は既存OS設定をバックアップして統合flakeを生成・ビルドし、OS全体を適用 |
| Android | Nix-on-Droidの`galaxy-tab-s11`構成を適用 |

NixOSの初回 `just build` も `/etc/nixos` のバックアップと統合flake生成を行うが、稼働環境は切り替えない。
既存のNixOS flakeは上書きしない。既存flakeへの統合・復旧は[NixOS導入手順](docs/nixos-install.md)を参照。

OmarchyのRio本体は `omarchy pkg add rio` で別途導入する。移行時は[検証・制限事項](docs/terminal-migration.md)も確認する。
AndroidはZsh・CLIを共有し、PC用のHyprland・Quickshell・Rio・IME・クラウドマウントを読み込まない。[Android導入手順](docs/android-install.md)を参照。

未対応OSはエラーで停止する。PC構成のユーザー名・配置先は現構成の前提を維持する。
Nixのインストール自体やAndroidアプリの導入は、このコマンドの対象外。

## ドキュメント

- [Rio + TUIOS：移行・検証・ロールバック](docs/terminal-migration.md)
- [ターミナルキーの移行表](docs/terminal-keybindings.md)

- [構成とOS別バックエンド](docs/desktop-architecture.md)
- [導入するパッケージ・設定](docs/managed-items.md)
- [jeebis-shell（Ruixen由来の互換プラグインを使用）](docs/jeebis-shell.md)
- [テーマツール：配色・壁紙の設定と切替](docs/theme-tooling.md)
- [日本語入力・クラウドマウント](docs/input-and-mounts.md)

認証情報・履歴・キャッシュ・実データは管理対象外。外部プラグインの取得やクラウド認証は別途必要。第三者コード・テーマ・壁紙は各配布元のライセンスに従う。

## キーバインド一覧

| キー | 動作 |
|---|---|
| Super+F | Ruixen App Launcher（バー左端と同じアプリ起動） |
| Super+Shift+Esc | Ruixen設定 |

Hyprlandが処理する。旧Ruixen用のSuper+Alt+Space・Super+Shift+Alt+Space・Super+R・Super+Shift+Rは解除する。既存のSuper+Escはシステムメニューとして維持する。

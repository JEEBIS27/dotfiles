# dotfiles

Omarchy / NixOS / Android（Nix-on-Droid）向けのHome Manager構成。Hyprland、Quickshell（Tide Island）、ターミナル・エディター設定とアプリを管理する。

PC構成は `x86_64-linux`・ユーザー `jeebis`・リポジトリを `~/dotfiles` に配置する。Androidは `aarch64-linux`、Nix-on-Droid既定のユーザーとホームを使用する。他の環境ではユーザー名・パス・ハードウェア設定の変更が必要。

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
| デスクトップ | Hyprland、Quickshell + Tide Island、Rio + TUIOS、固定テーマと壁紙 |
| NixOS用アプリ・サービス | Helium、Nautilus、Fcitx5 / Mozkey、音声・Bluetooth・電源管理 |
| クラウドマウント | rclone（Google Drive / OneDrive、認証は別途） |

Omarchyでは既存のデスクトップ・IME本体を使用する。Rio本体はOmarchyのパッケージ管理、TUIOSはHome Managerで導入する。[パッケージ一覧](docs/managed-items.md)を参照。

## 初回の導入

PCではNixをインストールしてから、AndroidではNix-on-Droidアプリの初回セットアップを完了してから実行する。
Androidでは、以下のコマンドをNix-on-Droidアプリ内で実行する。

次のコマンドを上から順番に実行する。Omarchy・NixOS・Androidで共通。

```bash
nix-shell -p git

git clone https://github.com/JEEBIS27/dotfiles.git ~/dotfiles

cd ~/dotfiles

nix --extra-experimental-features 'nix-command flakes' run "path:$PWD#just" -- switch
```

完了したら、ターミナルのセッションを開き直す。必要なアプリ・設定とjustが導入される。
リポジトリを既に取得している場合は、cloneせず、そのディレクトリで `git pull --ff-only` を実行してから最後のコマンドを実行する。

## 最新の設定へ更新する

導入後は、次の2行を実行するだけでGitHubの最新設定を取得して適用できる。

```bash
cd ~/dotfiles
just sync
```

CLI・開発ツール・一般アプリは `nixpkgs-apps` の `nixpkgs-unstable` を追跡する。新しいパッケージを取得して適用するには、次を実行する。

```bash
just update-apps
```

`just sync` はリポジトリに記録済みのロックを適用する。`just update-apps` はアプリ用のロックを更新して適用する。OS・Home Managerは別管理のまま維持する。ChatGPT・Helium・Spotifyなど `packages/` 内で独自にバージョン・ハッシュを指定しているアプリは、別途パッケージ定義の更新が必要。

通常の導入・更新では `just build` や `just host` を使う必要はない。

NixOSでは初回に既存のOS設定をバックアップして統合用の設定を生成し、OS全体に適用する。
既存のNixOS flakeは上書きしない。既存flakeへの統合・復旧は[NixOS導入手順](docs/nixos-install.md)を参照。

OmarchyのRio本体は `omarchy pkg add rio` で別途導入する。移行時は[検証・制限事項](docs/terminal-migration.md)も確認する。
Androidはfish・CLIを共有し、PC用のHyprland・Quickshell・Rio・IME・クラウドマウントを読み込まない。[Android導入手順](docs/android-install.md)を参照。

未対応OSはエラーで停止する。PC構成のユーザー名・配置先は現構成の前提を維持する。
Nixのインストール自体やAndroidアプリの導入は、このコマンドの対象外。

## 個別ログイン

1Password アプリと CLI を Nix で導入する。`just op-auth`、`just git-auth`、`just rclone-auth` で個別セットアップを行う。初回導入・PAT の保存・OAuth・既存コマンドの使い分けは[認証とセットアップ](docs/authentication.md)を参照。

## ドキュメント

- [Rio + TUIOS：移行・検証・ロールバック](docs/terminal-migration.md)
- [ターミナルキーの移行表](docs/terminal-keybindings.md)

- [構成とOS別バックエンド](docs/desktop-architecture.md)
- [導入するパッケージ・設定](docs/managed-items.md)
- [Tide Island：起動・設定・テーマ連携](docs/tide-island.md)
- [テーマツール：配色・壁紙の設定と切替](docs/theme-tooling.md)
- [日本語入力・クラウドマウント](docs/input-and-mounts.md)

認証情報・履歴・キャッシュ・実データは管理対象外。外部プラグインの取得やクラウド認証は別途必要。第三者コード・テーマ・壁紙は各配布元のライセンスに従う。

## キーバインド一覧

| キー | 動作 |
|---|---|
| Super+F | Tide Island App Launcher |
| Super+Shift+Esc | Tide Island設定 |

Hyprlandが処理する。旧Ruixen用のSuper+Alt+Space・Super+Shift+Alt+Space・Super+R・Super+Shift+Rは解除する。既存のSuper+Escはシステムメニューとして維持する。

# パッケージ・設定一覧

このページのデスクトップ設定・サービスはPC向け。Androidは`modules/cli.nix`のCLIと共有Zsh設定、公式Helixを使用する。バージョンと機能差は[Android導入手順](android-install.md)を参照。

正確なパッケージとバージョンは各Nix定義と`flake.lock`を参照。

## 共通パッケージ

| 分類 | パッケージ |
|---|---|
| シェル・ファイル操作 | zsh、tuios、sheldon、yazi、eza、bat、delta、dust、fzf、zoxide、ripgrep、fd |
| 開発・通信 | git、curl、wget、just、neovim、gcc、gnumake、pkg-config |
| アーカイブ・データ | unzip、7zz、stow、jq |
| メディア | ffmpeg、poppler-utils、imagemagick、mediainfo、exiftool |
| 起動・マウント | fuzzel、rclone |

## NixOS追加分

- デスクトップ：Hyprland / UWSM、Quickshell + Ruixen、Rio + TUIOS、Chromium、Nautilus、HackGenフォント。
- ツール：hyprland-preview-share-picker、hyprsunset、wl-clipboard、grim、slurp、libnotify、brightnessctl。
- 入力・サービス：Fcitx5 / Mozkey、NetworkManager、Bluetooth、PipeWire、polkit、電源管理、FUSE。
- 開発環境：Node.js、Cargo、Rust。
- LSP：LuaLS、gopls、Biome、Prisma、Tailwind CSS、vtsls、Vue、vscode-langservers-extracted、Jsonnet、YAML、Bash、Buf、Dockerfile、GraphQL、nixd、Pyright。
- 整形：Stylua、shfmt、Biome、prettierd、nixfmt。

定義元：`modules/apps.nix`、`modules/desktop.nix`、`modules/mounts.nix`、`modules/input-method-files.nix`、`nixos/desktop.nix`。

## 設定

Zsh、Sheldon、TUIOS、Helix、Neovim（代替）、Yazi、bat、Rio、Hyprland、Ruixenのシェル設定、Fcitx / Mozkey、テーマ・壁紙を`files/`に配置する。ChatGPT / Codex GUI等の本体はこの構成では導入しない。

Neovim・Sheldon等のプラグインは各マネージャーが取得する。NixOSではMasonのPATHをappendにしてNix製の実行ファイルを優先する。`gh_actions_ls`は設定には含まれるがパッケージ未導入。

jeebis-shellは`vendor/jeebis-shell/`のローカルソースを`packages/jeebis-shell.nix`で構築する。補助ツールとしてCava・Fastfetchも導入する。

既定エディターは`modules/editor.nix`の`programs.helix.defaultEditor`で定義する。`EDITOR` / `VISUAL`、Zsh、Hyprland、Omarchyの既定起動先はこの値に揃える。Helixの対応範囲と検証は[editor-migration.md](editor-migration.md)を参照。

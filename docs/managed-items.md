# 管理項目一覧

2026-10-21適用済み。基本28アプリにrcloneとFuzzelを追加。203設定ファイル＋HM基盤4ファイル＋サービス起動リンク2件（合計209、プラグインディレクトリ内を展開して集計）。アプリの定義はmodules/apps.nix・mounts.nix・desktop.nix、配置定義はhome.nixとmodules以下。

## アプリ本体

| パッケージ | 固定版 |
|---|---|
| git | 2.56.0 |
| curl | 8.22.0 |
| wget | 1.25.0 |
| zsh | 5.9.2 |
| tmux | 3.8 |
| sheldon | 0.8.5 |
| neovim | 0.12.6 |
| yazi | 26.9.1 |
| eza | 0.23.5 |
| bat | 0.26.1 |
| delta | 0.20.1 |
| du-dust | 1.2.6 |
| fzf | 0.74.5 |
| zoxide | 0.10.0 |
| ripgrep | 15.2.0 |
| fd | 10.5.0 |
| unzip | 6.0 |
| 7zz | 26.04 |
| stow | 2.4.1 |
| jq | 1.8.2 |
| ffmpeg | 9.0.2 |
| poppler-utils | 26.10.0 |
| imagemagick | 7.1.2-34 |
| mediainfo | 26.05 |
| Image-ExifTool | 13.59 |
| gcc-wrapper | 16.2.0 |
| gnumake | 4.4.1 |
| pkg-config-wrapper | 0.29.2 |
| rclone | 1.75.2 |
| fuzzel | 1.15.0 |

## 構成

```text
home-manager/
├── flake.nix          # HM用・アプリ用の入力とホスト定義
├── flake.lock         # 入力revisionとハッシュ
├── home.nix           # import・ユーザー・tmux配置
├── modules/
│   ├── apps.nix       # アプリ本体28個
│   ├── zsh-files.nix  # Zsh／Sheldon配置
│   ├── app-files.nix  # アプリ設定・共通テーマ参照
│   └── desktop.nix    # Hyprland・シェル・WezTermとOS別処理
├── files/
│   ├── tmux.conf
│   ├── zshrc
│   ├── zsh/
│   ├── sheldon/
│   ├── nvim/
│   ├── yazi/
│   ├── bat/
│   ├── herdr/
│   ├── omarchy/
│   ├── hypr/
│   ├── wezterm/
│   └── desktop/
└── docs/
    └── managed-items.md
```

## 設定ファイル

| 配置先（ホームからの相対パス） | 管理元または参照先 |
|---|---|
| `.config/tmux/tmux.conf` | `files/tmux.conf` |
| `.zshrc` | `files/zshrc` |
| `.config/zsh/config.sh` | `files/zsh/config.sh` |
| `.config/zsh/fzf.zsh` | `files/zsh/fzf.zsh` |
| `.config/zsh/my_alias.zsh` | `files/zsh/my_alias.zsh` |
| `.config/zsh/unified_keys.zsh` | `files/zsh/unified_keys.zsh` |
| `.config/sheldon/plugins.toml` | `files/sheldon/plugins.toml` |
| `.config/bat/themes/Omarchy.tmTheme` | `.local/state/omarchy/current/theme/preview.tmTheme（Omarchy生成物を参照）` |
| `.config/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_dragon.tmTheme` | `files/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_dragon.tmTheme` |
| `.config/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_lotus.tmTheme` | `files/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_lotus.tmTheme` |
| `.config/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_wave.tmTheme` | `files/bat/themes/kanagawa.nvim/extras/sublime/kanagawa_wave.tmTheme` |
| `.config/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_day.tmTheme` | `files/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_day.tmTheme` |
| `.config/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_moon.tmTheme` | `files/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_moon.tmTheme` |
| `.config/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_night.tmTheme` | `files/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_night.tmTheme` |
| `.config/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_storm.tmTheme` | `files/bat/themes/tokyonight.nvim/extras/sublime/tokyonight_storm.tmTheme` |
| `.config/herdr/config.toml` | `files/herdr/config.toml` |
| `.config/nvim/after/lsp/lua_ls.lua` | `files/nvim/after/lsp/lua_ls.lua` |
| `.config/nvim/init.lua` | `files/nvim/init.lua` |
| `.config/nvim/lazy-lock.json` | `files/nvim/lazy-lock.json（書込可能リンク）` |
| `.config/nvim/lua/config/keymaps.lua` | `files/nvim/lua/config/keymaps.lua` |
| `.config/nvim/lua/config/lazy.lua` | `files/nvim/lua/config/lazy.lua` |
| `.config/nvim/lua/config/options.lua` | `files/nvim/lua/config/options.lua` |
| `.config/nvim/lua/config/theme.lua` | `files/nvim/lua/config/theme.lua` |
| `.config/nvim/lua/config/unified_keys.lua` | `files/nvim/lua/config/unified_keys.lua` |
| `.config/nvim/lua/config/wezterm.lua` | `files/nvim/lua/config/wezterm.lua` |
| `.config/nvim/lua/plugins/edit/init.lua` | `files/nvim/lua/plugins/edit/init.lua` |
| `.config/nvim/lua/plugins/editor/init.lua` | `files/nvim/lua/plugins/editor/init.lua` |
| `.config/nvim/lua/plugins/editor/snacks.lua` | `files/nvim/lua/plugins/editor/snacks.lua` |
| `.config/nvim/lua/plugins/editor/statuscol.lua` | `files/nvim/lua/plugins/editor/statuscol.lua` |
| `.config/nvim/lua/plugins/editor/theme.lua` | `files/nvim/lua/plugins/editor/theme.lua` |
| `.config/nvim/lua/plugins/editor/which-key.lua` | `files/nvim/lua/plugins/editor/which-key.lua` |
| `.config/nvim/lua/plugins/editor/yazi.lua` | `files/nvim/lua/plugins/editor/yazi.lua` |
| `.config/nvim/lua/plugins/lang/init.lua` | `files/nvim/lua/plugins/lang/init.lua` |
| `.config/nvim/lua/plugins/lsp/config/lsp_actions_on_save.lua` | `files/nvim/lua/plugins/lsp/config/lsp_actions_on_save.lua` |
| `.config/nvim/lua/plugins/lsp/config/lsp_keymaps.lua` | `files/nvim/lua/plugins/lsp/config/lsp_keymaps.lua` |
| `.config/nvim/lua/plugins/lsp/config/utils.lua` | `files/nvim/lua/plugins/lsp/config/utils.lua` |
| `.config/nvim/lua/plugins/lsp/init.lua` | `files/nvim/lua/plugins/lsp/init.lua` |
| `.config/nvim/lua/plugins/treesitter.lua` | `files/nvim/lua/plugins/treesitter.lua` |
| `.config/nvim/lua/plugins/ui/incline/get_display_filename_and_dirname.lua` | `files/nvim/lua/plugins/ui/incline/get_display_filename_and_dirname.lua` |
| `.config/nvim/lua/plugins/ui/incline.lua` | `files/nvim/lua/plugins/ui/incline.lua` |
| `.config/nvim/lua/plugins/ui/init.lua` | `files/nvim/lua/plugins/ui/init.lua` |
| `.config/nvim/lua/plugins/ui/noice.lua` | `files/nvim/lua/plugins/ui/noice.lua` |
| `.config/nvim/lua/utils/colors.lua` | `files/nvim/lua/utils/colors.lua` |
| `.config/nvim/lua/utils/copilot.lua` | `files/nvim/lua/utils/copilot.lua` |
| `.config/nvim/lua/utils/highlight.lua` | `files/nvim/lua/utils/highlight.lua` |
| `.config/nvim/lua/utils/keymap.lua` | `files/nvim/lua/utils/keymap.lua` |
| `.config/nvim/lua/utils/mode_colors.lua` | `files/nvim/lua/utils/mode_colors.lua` |
| `.config/yazi/flavors/kanagawa.yazi/LICENSE` | `files/yazi/flavors/kanagawa.yazi/LICENSE` |
| `.config/yazi/flavors/kanagawa.yazi/LICENSE-tmtheme` | `files/yazi/flavors/kanagawa.yazi/LICENSE-tmtheme` |
| `.config/yazi/flavors/kanagawa.yazi/README.md` | `files/yazi/flavors/kanagawa.yazi/README.md` |
| `.config/yazi/flavors/kanagawa.yazi/flavor.toml` | `files/yazi/flavors/kanagawa.yazi/flavor.toml` |
| `.config/yazi/flavors/kanagawa.yazi/preview.png` | `files/yazi/flavors/kanagawa.yazi/preview.png` |
| `.config/yazi/flavors/kanagawa.yazi/tmtheme.xml` | `files/yazi/flavors/kanagawa.yazi/tmtheme.xml` |
| `.config/yazi/flavors/tokyonight-night.yazi/LICENSE` | `files/yazi/flavors/tokyonight-night.yazi/LICENSE` |
| `.config/yazi/flavors/tokyonight-night.yazi/LICENSE-tmtheme` | `files/yazi/flavors/tokyonight-night.yazi/LICENSE-tmtheme` |
| `.config/yazi/flavors/tokyonight-night.yazi/README.md` | `files/yazi/flavors/tokyonight-night.yazi/README.md` |
| `.config/yazi/flavors/tokyonight-night.yazi/flavor.toml` | `files/yazi/flavors/tokyonight-night.yazi/flavor.toml` |
| `.config/yazi/flavors/tokyonight-night.yazi/preview.png` | `files/yazi/flavors/tokyonight-night.yazi/preview.png` |
| `.config/yazi/flavors/tokyonight-night.yazi/tmtheme.xml` | `files/yazi/flavors/tokyonight-night.yazi/tmtheme.xml` |
| `.config/yazi/keymap.toml` | `files/yazi/keymap.toml` |
| `.config/yazi/package.toml` | `files/yazi/package.toml（書込可能リンク）` |
| `.config/yazi/plugins/unified-layout.yazi/main.lua` | `files/yazi/plugins/unified-layout.yazi/main.lua` |
| `.config/yazi/plugins/unified-motions.yazi/main.lua` | `files/yazi/plugins/unified-motions.yazi/main.lua` |
| `.config/yazi/plugins/unified-tabs.yazi/main.lua` | `files/yazi/plugins/unified-tabs.yazi/main.lua` |
| `.config/yazi/theme.toml` | `.local/state/omarchy/current/theme/yazi.toml（Omarchy生成物を参照）` |
| `.config/yazi/yazi.toml` | `files/yazi/yazi.toml` |
| `.config/omarchy/themed/palette.lua.tpl` | `files/desktop/templates/palette.lua.tpl` |
| `.config/omarchy/themed/preview.tmTheme.tpl` | `files/desktop/templates/preview.tmTheme.tpl` |
| `.config/omarchy/themed/yazi.toml.tpl` | `files/desktop/templates/yazi.toml.tpl` |
| `.config/omarchy/hooks/theme-set.d/refresh-bat.hook` | `files/omarchy/hooks/theme-set.d/refresh-bat.hook` |

## Home Manager基盤

.cache/.keep、.local/state/.keep、.config/systemd/user/tray.target、.config/environment.d/10-home-manager.confはHMが生成する。

## デスクトップ設定（移管済み）

Hyprland10ファイル、Quickshell個人プラグイン101ファイル、shell.json、WezTerm5ファイル、個人ヘルパー4件、Luaアダプター、追加のWezTermテンプレートを同期する。追加分は123ファイル。[全配置先](desktop-managed-paths.md)と[構成ツリー・仕組み](desktop-architecture.md)を参照。

OmarchyホストではHyprland／Quickshell／WezTerm本体は従来のOSパッケージを使う。NixOSホストはnixos/desktop.nixとmodules/desktop.nixで本体とサービスを宣言する。NixOSのシェルは同梱ランタイムで動作し、OSへのOmarchy導入を要求しない。

Neovim、Yazi、bat、WezTermのテーマ参照先はjeebis.desktop.themeDirectoryで切り替える。上表のOmarchy state参照はOmarchyホストの値であり、NixOSではjeebis-desktop/current/themeを使う。

## 残る移管・検証

Herdr本体、Omarchy側のGUI本体、TeX、個別アプリと外部サービスの移植が残る。Fcitx/Mozkey設定5件と共通palette3件、rclone unit2件は追加済み。MozkeyはNixOSの実変換試験が残る。rcloneの稼働中プロセスは維持し、新定義は次回起動時に使う。NixOSの起動・GPU・認証・スリープ・画面共有も実機検証が必要。プラグイン取得・実データ・認証情報は設定同期に含めない。[現在の準備状況](nixos-readiness.md)を参照。

## 入力・マウントの追加分

[input-and-mounts.md](input-and-mounts.md)に設定元、書き込み可能ファイル、認証情報の扱いと検証結果を記載。テーマと壁紙の固定セットは[theme-tooling.md](theme-tooling.md)を参照。

| 追加配置先 | 管理元 |
|---|---|
| .config/fcitx5/config | files/fcitx5/config（書き込み可能） |
| .config/fcitx5/profile | files/fcitx5/profile（書き込み可能） |
| .config/fcitx5/conf/keyboard.conf | files/fcitx5/conf/keyboard.conf（書き込み可能） |
| .config/fcitx5/conf/mozkey-ibg.conf | files/fcitx5/conf/mozkey-ibg.conf（書き込み可能） |
| .config/mozkey-ibg/config1.db | files/mozkey-ibg/config1.db（書き込み可能） |
| .config/omarchy/themes/{tokyonight,kanagawa,catppuccin}/colors.toml | files/desktop/presets.jsonとthemes/（Omarchy側の3件） |
| .config/systemd/user/rclone-gdrive.service | modules/mounts.nix |
| .config/systemd/user/rclone-onedrive.service | modules/mounts.nix |

NixOSでは追加でfcitx5.serviceとMozkeyパッケージを配置する。上記209という数値は現在のOmarchy側。認証ファイルrclone.confや学習履歴・暗号鍵は管理対象に含めない。

# Dotfiles

Linux (Arch Linux系) 環境のセットアップをchezmoiを軸に完全自動化するためのドットファイルです。

## インストールするツール・アプリ

### OS基本ツール
- git
- curl
- wget
- base-devel

### アプリケーション
- helium-browser-bin
- ghostty
- neovim
- 1password cli

### Homebrewパッケージ
- bat
- eza
- git-delta
- dust
- fzf
- zoxide
- ripgrep
- fd
- zsh
- sheldon
- stow
- chezmoi
- yazi
- ffmpeg
- sevenzip
- jq
- poppler
- imagemagick
- rustup-init

### IME関連
- fcitx5-im
- fcitx5-configtool
- mozkey-ibg-bin

## 新しい環境でのセットアップ手順

新しい環境では以下のコマンドを実行して設定を適用します。
```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply JEEBIS27
```

## アップデート方法
以下のコマンドで最新の設定を取り込めます。
```
chezmoi update
brew bundle --global
chezmoi apply --force
```


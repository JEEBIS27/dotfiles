# Dotfiles

このリポジトリは、Linux（Arch Linux系）環境のセットアップを `chezmoi` を軸に完全自動化するためのドットファイル管理構成です。

## 含まれる主なツール・アプリ

### 1. OS 基本ツール
* **`git`, `curl`, `wget`**: 通信・バージョン管理
* **`base-devel`**: 開発・コンパイル用基本パッケージ

### 2. Homebrew パッケージ（Brewfile）
* **ターミナル便利ツール**: `bat`, `eza`, `git-delta`, `dust`, `fzf`, `zoxide`, `ripgrep`, `fd`
* **シェル・管理**: `zsh`, `sheldon`, `stow`, `chezmoi`
* **ファイルマネージャー**: `yazi` (および依存する `ffmpeg`, `sevenzip`, `jq`, `poppler`, `imagemagick`)
* **言語処理系**: `rustup-init` (`rustc`, `cargo`)

### 3. 個別バイナリインストール
* **Neovim (`nvim`)**: GitHub Releases から最新版バイナリを自動配置
* **1Password CLI (`op`)**: 公式アーカイブから自動インストール

---

## 新しい環境でのセットアップ手順

新しい（またはクリーンな）Linux 環境で以下の 1 コマンドを実行するだけで、すべてのツール導入・設定の適用・デフォルトシェルの変更までが全自動で行われます。

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply JEEBIS27
```

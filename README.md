# jeebis Home Manager

本人のアプリ・設定の同期と環境再現のための構成。機能選択プロフィールや導入時の質問は設けない。Omarchy／NixOSで共通設定を使用し、OS別処理はホスト定義で切り替える。

## 管理範囲

2026-10-21時点で基本アプリ28個にrcloneとFuzzelを追加し、設定203ファイル＋Home Manager基盤4ファイルを管理する（プラグインディレクトリ内のファイルを展開して数える）。正確な一覧と配置先は[管理項目一覧](docs/managed-items.md)を参照。Home Manager基盤として.keep×2、user systemdのtray.target、environment.dのlocale設定も配置する。

新しいZshでは.nix-profile/binをHomebrewより優先する。既存Homebrew／Archパッケージ、ログインシェルの登録、稼働中セッションは維持する。manとMIMEツールはOS側の実行先を維持する。Herdrは設定のみ管理し、本体は既存のものを使う。WezTerm設定、Hyprland設定、Quickshell個人プラグインは移管済み。Omarchy側のGUI本体とFcitx/Mozkeyの稼働プロセスは従来のものを利用する。Fcitx/Mozkeyの個人設定とrcloneのサービス定義はHome Managerへ移管済み。

## 更新と別ホストへの再現

このリポジトリのfiles以下を編集して反映する。配布先は原則読み取り専用リンク。認証情報・履歴・キャッシュ・socket・ログ・セッション・Omarchy生成物を混ぜない。

```sh
home-manager build --flake "path:$HOME/Git/home-manager#jeebis@omarchy"
home-manager switch --flake "path:$HOME/Git/home-manager#jeebis@omarchy"
```

Nixpkgs／Home Managerはflake.lockで固定。Home Manager用は26.05系列、アプリ用は別のnixpkgs-apps入力を固定している。アプリ用はURLのcommit自体も固定しているため、更新時はflake.nixのrevisionを意図して変更し、lockを更新して検証する。通常のswitchでは入力を更新しない。home.stateVersionは互換性の基準なので通常更新では変えない。

Git経由のNixOS導入は[短い導入・更新手順](docs/nixos-install.md)を参照。初回はclone → setup（ビルド）→ switch、以後は `bash ~/Git/home-manager/scripts/nixos.sh sync` で更新する。Gitリモートはまだ未設定。現構成はjeebis／x86_64-linux向け。Google Driveの実ファイル・アプリ履歴・認証情報はリポジトリに含めない。

## Zshとプラグイン

files/zshrc、files/zsh/、files/sheldon/plugins.tomlを編集する。既存シェルの再sourceは自動実行しない。

Sheldonの追加・削除はplugins.tomlのテーブルを編集してswitchする。旧zsh-plugin-add/removeと配布先へのsheldon add/remove/editは使用しない。zsh-plugin-list/update/reloadは維持する。fzf本体はNixで導入し、Sheldonはそのシェル連携を読み込む。plugins.lockと取得済みプラグインは生成物であり同期しない。Sheldonのプラグイン版の完全固定は未実施。

Neovimのlazy-lock.jsonとYaziのpackage.tomlは管理元への書込可能なリンクにしている。アプリによる依存管理ファイルの更新はリポジトリの差分になる。shell.jsonも書き込み可能な管理元へのリンクである。これらは世代切替えだけでは巻き戻らない。Yaziのflavor等を更新する場合も管理元files/yaziを更新し、switchで配布する。配布先のNixリンクを直接上書きしない。Neovim／Sheldonの取得済みプラグインやMasonの外部バイナリは従来のマネージャーが取得する。

## Omarchyとの連携

palette.lua、Yazi、preview.tmTheme、WezTermのテンプレートとbat更新フックを管理する。Omarchyでは従来の生成器を利用し、NixOSでは共通paletteから独立した生成器で出力する。参照先はホスト定義で切り替える。テーマ選択は一箇所に集約する。

## 復旧

移管前の現物、正式構成、chezmoi ignore、旧HM世代をバックアップした。問題の段階の旧世代へ戻し、その段階で移管したリンクだけを確認して退避ファイルを復元する。書込可能ファイル、生成cache、外部取得物は別に扱う。ホーム全体を上書きしない。旧chezmoiソースと既存パッケージは残す。

## NixOS移行の準備状況

[Omarchy依存・デスクトップ同期調査](docs/nixos-readiness.md)に現状と移植順序を記録した。共通設定とOS別バックエンドを実装し、Omarchyへ適用済み。NixOS版はビルド・隔離プレビューまで検証済み。NixOS実機の認証・GPU・スリープ復帰と、Mozkeyの実変換試験が残っている。固定テーマセットにはAetherもMatugenも不要。

## 共通デスクトップ

Hyprland・Quickshell個人プラグイン・WezTermは`modules/desktop.nix`で同期します。ホストは`jeebis@omarchy`と`jeebis@nixos`です。仕組み・切替・未完了事項は[desktop-architecture.md](docs/desktop-architecture.md)を参照してください。

テーマの配色と壁紙の組は[theme-tooling.md](docs/theme-tooling.md)、日本語入力とクラウドマウントは[input-and-mounts.md](docs/input-and-mounts.md)を参照。

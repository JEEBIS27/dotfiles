# Android / Nix-on-Droid（Galaxy Tab S11）

## 構成の分離

`flake.nix` の `nixOnDroidConfigurations.galaxy-tab-s11` は `aarch64-linux` 用。
Nix-on-DroidをAndroidアプリとして導入した環境が対象。通常のTermux単体やNixOSでは使わない。

```text
PC:      hosts/{omarchy,nixos}.nix → home.nix → modules/common.nix + PC用モジュール
Android: hosts/nix-on-droid.nix → hosts/android.nix → modules/common.nix
共通:    modules/common.nix → modules/cli.nix + modules/zsh-files.nix
```

Androidのimport経路には `modules/desktop.nix`、`modules/apps.nix`、
`modules/editor.nix`、`modules/app-files.nix`、`modules/input-method-files.nix`、
`modules/mounts.nix` と `nixos/` を含めない。無効化フラグによる切替ではなく、
PC用モジュールを読み込まない。Hyprland、Quickshell、Rio、Fcitx5/Mozkey、
rcloneのsystemd/FUSEマウント、PCのテーマ生成とパスはAndroidには配置しない。

共有するものはZshのプロンプト・エイリアス・キー設定・Sheldon設定、CLIパッケージ定義。
AndroidでもHelixを既定エディターにするが、公式パッケージと組み込みのKanagawaテーマを使う。
Steel拡張・PCのHelixキー設定とLSP一式、Neovim/Yaziの独自設定、TUIOSはPC側のみ。
AndroidのNeovim/Yaziは各パッケージの既定設定で動く。GUI起動・クリップボード連携は
共有エイリアス中にあるが、Android側の専用連携はまだ追加していない。

## バージョンとパス

[Nix-on-Droid公式advancedテンプレート](https://github.com/nix-community/nix-on-droid/blob/release-24.05/templates/advanced/flake.nix)
に合わせ、Android用のNix-on-Droid / nixpkgs / Home Managerは24.05系列で独立させる。
PCの26.05系列・アプリ用pinは変更しない。CLI・HelixはPCと同じ `nixpkgs-apps` pinのARM版を使う。
共有Zshで使う新しいfzfオプションも、このアプリ用pinで揃える。
Home ManagerやNix-on-Droidの基盤ツールは24.05系列。
`system.stateVersion` / `home.stateVersion` は初期状態の互換性設定なので、
パッケージ更新時にも機械的に変更しない。

ユーザー名とホームはNix-on-DroidのHome Manager統合から受け取る。
既定では `nix-on-droid` / `/data/data/com.termux.nix/files/home`。
AndroidのUID/GIDをGitに書き込まない。リポジトリの配置先は任意。

## 導入・適用

1. Nix-on-Droidを導入し、初回セットアップを完了する。
2. Nix-on-Droid内で取得する。Gitがなければ先に `nix-shell -p git` を起動する。

   ```bash
   git clone https://github.com/JEEBIS27/dotfiles.git ~/Git/home-manager
   cd ~/Git/home-manager
   ```

3. 必要なら先にビルドだけを行う。ログインシェルや現在の設定は切り替えない。

   ```bash
   nix --extra-experimental-features 'nix-command flakes' build      "path:$PWD#nixOnDroidConfigurations.galaxy-tab-s11.activationPackage" --no-link
   ```

4. 適用する。

   ```bash
   nix-on-droid switch --flake "path:$PWD#galaxy-tab-s11"
   ```

5. Nix-on-Droidのセッションを開き直す。`echo "$HOME"`、`echo "$EDITOR"`、
   `zsh --version`、`hx --version`、`yazi --version` を確認する。
   初回のZsh起動ではSheldonが外部プラグインを取得するためネット接続が必要。

既存ファイルと衝突したら、表示された対象だけをバックアップして再実行する。
自動上書きや全ホームの移行は行わない。PC用の `scripts/nixos.sh` は実行しない。

## 更新・検証

通常の設定更新はリポジトリを更新して同じswitchを実行する。
Androidだけの依存更新は `nix flake lock --update-input nixpkgs-droid --update-input home-manager-droid --update-input nix-on-droid`。
アプリの更新はPCと共有する `nixpkgs-apps` のpinを更新する。
PC用の入力まで意図せず更新しないよう `flake.lock` の差分を確認する。

`python3 scripts/check-android.py` はAndroid構成の評価結果から、
CPUアーキテクチャ、ホーム、シェル、CLI、PC用設定・サービスの混入を確認する。
PC上での評価・derivation生成は実機のビルド・起動確認とは別。
Android用の完全ビルドはaarch64 Linuxビルダーか端末上で実施する。
Galaxy Tab S11実機のproot動作、ストレージ権限、日本語入力、ソフト/外付けキーボード、
端末の修飾キー送信は実機確認が必要。

# 構成とOS別バックエンド

`home.nix`から共通モジュールを読み込み、`hosts/omarchy.nix` / `hosts/nixos.nix`でデスクトップの実装を切り替える。

| 定義 | 役割 |
|---|---|
| `modules/apps.nix` | 共通CLI、NixOS用開発ツール |
| `modules/zsh-files.nix` / `app-files.nix` | シェル・アプリ設定の配置 |
| `modules/desktop.nix` | Hyprland、Quickshellプラグイン、Rio + TUIOS、テーマ |
| `modules/input-method-files.nix` | Fcitx / Mozkey設定・NixOS用IMEサービス |
| `modules/mounts.nix` | rcloneとuser systemd unit |
| `nixos/desktop.nix` | Hyprland / UWSM、IME、PAM、通信・音声・電源管理 |
| `nixosModules.personal` | NixOSとHome Managerの統合 |

## 同梱ランタイム

`vendor/desktop-runtime`はOmarchy 4.0.4由来のMITライセンスのデスクトップ部品。`shell/`はQuickshellの基盤、`default/`はHyprland等の共通設定、`bin/`は音量・明るさ・ネットワーク・クリップボード等の補助コマンド。インストーラーやディストリビューション更新処理は含めない。出典は`vendor/desktop-runtime/PROVENANCE.md`を参照。

`omarchy-*`の名前はQMLやスクリプトの呼出し互換のため保持する。NixOSでは`packages/desktop/runtime.nix`でパス等を調整した専用ランタイムをNix storeへ構築する。ホストの`/usr/share/omarchy`は不要。Omarchy側は既存OSの実装を利用する。直接の呼出しだけでなくスクリプト間の呼出しもあるため、名前だけを根拠に`bin/`の部品を削除しない。

## Ruixen

バー・notch・ランチャーは[Ruixen](ruixen-shell.md)を使用する。プラグイン本体は`vendor/jeebis-shell/`の編集可能なソースからNixで構築し、設定は`files/desktop/jeebis-shell.json`に置く。OmarchyではOSのシェル、NixOSでは同梱ランタイムに読み込む。RuixenはOmarchyシェルを必要とし、独立したシェルではない。

画面スケールと曲率はRuixenが書き換えるローカル設定として初期化し、固定のHome Managerリンクにはしない。テーマプリセットは共通の宣言から管理する。

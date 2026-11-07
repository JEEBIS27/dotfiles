# 構成とOS別バックエンド

PCでは`home.nix`から共通モジュールを読み込み、`hosts/omarchy.nix` / `hosts/nixos.nix`でデスクトップの実装を切り替える。

| 定義 | 役割 |
|---|---|
| `modules/common.nix` / `modules/cli.nix` | PC・Android共通のfish設定とCLIパッケージ |
| `modules/apps.nix` | PC用TUIOS、NixOS用開発ツール |
| `hosts/nix-on-droid.nix` / `hosts/android.nix` | Android用入口。PCモジュールは読み込まない |
| `modules/fish.nix` / `app-files.nix` | シェル・アプリ設定の配置 |
| `modules/desktop.nix` | Hyprland、Tide Island、Rio + TUIOS、テーマ |
| `modules/input-method-files.nix` | Fcitx / Mozkey設定・NixOS用IMEサービス |
| `modules/mounts.nix` | rcloneとuser systemd unit |
| `nixos/desktop.nix` | Hyprland / UWSM、IME、PAM、通信・音声・電源管理 |
| `nixosModules.personal` | NixOSとHome Managerの統合 |

Androidの読み込み経路・機能差は[Android導入手順](android-install.md)を参照。以下はPC用デスクトップの説明。

## 同梱ランタイム

`vendor/desktop-runtime`はOmarchy 4.0.4由来のMITライセンスのデスクトップ部品。Quickshellシェルは含めず、`default/`はHyprland等の共通設定、`bin/`は音量・明るさ・ネットワーク・クリップボード等の補助コマンド。インストーラーやディストリビューション更新処理は含めない。出典は`vendor/desktop-runtime/PROVENANCE.md`を参照。

`omarchy-*`の名前はQMLやスクリプトの呼出し互換のため保持する。NixOSでは`packages/desktop/runtime.nix`でパス等を調整した専用ランタイムをNix storeへ構築する。ホストの`/usr/share/omarchy`は不要。Omarchy側は既存OSの実装を利用する。直接の呼出しだけでなくスクリプト間の呼出しもあるため、名前だけを根拠に`bin/`の部品を削除しない。

## Tide Island

バー・island・ランチャー・通知・ロックは[Tide Island](tide-island.md)のQuickshell版を使用する。ソースは版とハッシュを固定し、Nixで構築する。`/usr`へ配置する上流インストーラーは実行しない。

設定は`modules/desktop.nix`、個人用の角丸・動作設定は`files/desktop/{curvature,motion}.lua`、画面回転の設定は`files/desktop/display-rotation.json`に置く。壁紙は独立したmpvpaperサービスが表示する。旧jeebis-shellとOmarchyのQuickshellシェルは同期対象に含めない。

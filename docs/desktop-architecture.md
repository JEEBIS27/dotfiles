# 共通デスクトップとOS別バックエンド

## 方針

Hyprlandの個人設定、Quickshellの個人プラグイン、WezTermとテーマテンプレートを同じリポジトリから管理する。OSによる切替はflakeのホスト選択だけで行い、導入時の質問や同期項目のプロファイルは設けない。

```text
flake.nix
├── hosts/omarchy.nix → home.nix → modules/desktop.nix
├── hosts/nixos.nix   → home.nix → modules/desktop.nix
├── files/hypr/                 共通のウィンドウ・キー・モニター設定
├── files/desktop/plugins/      共通の個人QMLプラグイン
├── files/desktop/shell.json    バー配置（UIから書き込み可能）
├── files/desktop/templates/    アプリ共通のテーマ生成元
├── files/desktop/themes/       3テーマの色定義
├── files/wezterm/              ターミナル設定
├── packages/desktop/           操作窓口・テーマ生成・OS別処理
├── vendor/desktop-runtime/     NixOS用に固定したMITライセンスのシェル基盤
└── nixos/desktop.nix           Hyprland/UWSM、PAM、通信・音声・電源サービス
```

## Home Managerの役割

Nixはflake.lockで入力リビジョンを固定し、設定とプログラムを/nix/storeに構築する。Home Managerは世代を作り、ホーム内の設定をその世代へリンクする。再適用は同じ宣言を再現する。shell.json、Neovimのlazy-lock.json、Yaziのpackage.tomlはアプリから更新するため、リポジトリ内の書き込み可能なファイルへリンクする。この変更はGitで確認して同期する。履歴・キャッシュ・ログイン情報・認証情報は宣言に含めない。

## 実行経路

個人設定 → jeebis-desktop → ホスト実装。Omarchyでは既存コマンドと既存シェルを利用し、現在のテーマと挙動を維持する。NixOSではNixのプログラムと同梱ランタイムを使用する。omarchy.*というプラグインIDや互換コマンド名は残るが、NixOSにOmarchyパッケージをインストールする必要はない。同梱ランタイムには更新・インストール・パッケージ操作の仕組みを持ち込まない。

NixOSではQtのColorとの衝突を避けるため、ビルド時に個人・同梱プラグインの色シングルトンをDesktopColorへ変換する。ソースの個人設定は両OSで共有する。

テーマ選択は一箇所。両OSでfiles/desktop/presets.jsonの配色と壁紙の組をjeebis-desktop theme set/cycleで選択し、アプリごとのテーマセレクターは設けない。NixOSで生成されるテーマは~/.local/state/jeebis-desktop/current/themeに置く。

## 再適用

```sh
cd ~/Git/home-manager
nix build .#homeConfigurations.\"jeebis@omarchy\".activationPackage
./result/activate
# NixOSでHome Managerを単独利用する場合
nix build .#homeConfigurations.\"jeebis@nixos\".activationPackage
./result/activate
```

flake内のdesktop-vmは評価・VM試験用であり、実機のインストール定義ではない。NixOS実機ではnixos/desktop.nixとHome Managerのhosts/nixos.nixを実際のhardware-configuration.nixを持つホストに読み込む。OSモジュールにはappPkgs（flakeのnixpkgs-apps.legacyPackages.x86_64-linux）をspecialArgsで渡す。

## 未完了の実機移行条件

NixOSの起動・GPU・サスペンド復帰・PAM認証は実際のNixOSで確認が必要。現在のOmarchy上で別シェルを並走させても、その認証試験にはならない。隔離プレビューでは認証・通知・idleを一時HOME内で無効化し、本番設定は変更しない。

Mozkeyは隔離Nixパッケージを実装したが、NixOS上の実際の変換試験が残る。Aetherは不要になり、ChatGPT/Codexのデスクトップアプリ本体の個別パッケージ化が残る。キー・バー側の呼び出し設定の同期と、本体のインストール完了は別である。NixOS用互換窓口が対応していないディストリビューション管理機能は明示的にエラーにする。Omarchyの全システム管理UIの移植完了を意味しない。

この段階ではNixOSを実機にインストールしない。Omarchy版の移管とNixOS版のビルド・隔離プレビューの結果を検証記録に保存する。


## 固定テーマセットと入力・マウント

GUIテーマ編集は不要。固定配色と好きな壁紙の組は[theme-tooling.md](theme-tooling.md)、Mozkeyとrcloneの宣言・検証範囲は[input-and-mounts.md](input-and-mounts.md)を参照。

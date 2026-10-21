# NixOS移行の準備状況

2026-10-21更新。デスクトップ共通化とOmarchyへの適用を実施した。NixOS実機への移行完了ではない。

| 対象 | 現在の管理・実装 | 検証 |
|---|---|---|
| Hyprland個人設定10件 | Home Manager、共通Lua＋OS別bootstrap | Omarchyでreload成功、エラーなし、245キーバインド維持 |
| Quickshell個人プラグイン101件 | Home Manager、両OSで同じソース | 現行バー表示確認、Nix版シェル隔離起動・IPC応答 |
| shell.json | 書き込み可能なリポジトリファイルへのリンク | UIの保存先を維持 |
| WezTerm設定5件 | Home Manager、テーマ参照先をOS別生成 | CLI設定評価と一時ウィンドウの起動成功 |
| テーマ | 共通palette・テンプレート、Omarchy／独立生成器を切替 | Tokyonight・Kanagawa・Catppuccinの出力生成成功 |
| シェル基盤 | Omarchyは既存OS基盤、NixOSは同梱MITランタイム | NixOS版HMビルドと隔離プレビュー成功 |
| OSサービス | nixos/desktop.nix、HM user unit | 新規KVM VMで起動・ポータル・IPC・入力・設定GUIを確認。失敗サービス0件 |
| スリープ前ロック | NixOS側に監視とdelay inhibitorを宣言 | 監視サービス起動、VMで通常認証・再ロック成功。実機のスリープ・復帰は未検証 |

共有する設定とOS別処理は[構成ツリー・仕組み](desktop-architecture.md)、配置先は[デスクトップ管理一覧](desktop-managed-paths.md)に記載した。旧調査は[2026-10-20時点の記録](nixos-readiness-2026-10-20.md)として保存する。その記録の「未管理」「未実装」は調査当時の状態。

## 残っている移行条件

1. Mozkey 0.10.4はNixOS VMの専用Wayland環境でGTK/Qtの日本語変換・確定に成功。scorerと認証付き推論APIも成功。個人HyprlandでもGTK/Qtの日本語確定とCtrl+Space切替に成功。設定GUIも表示成功。IME経由のZenz補正全体、X11/XWayland用Qtプラグインの問題は残る。[検証記録](mozkey-verification.md)参照。
2. GUIテーマ編集は不要になりAether依存は解消。ChatGPT／CodexのGUI本体、Herdrの版差を整理する。同期済みのランチャーがあっても本体の導入完了ではない。
3. rclone unitとFUSEのホスト別パスは宣言済み。現在のOmarchyでは両マウントがactive。NixOS VMでローカルFUSEのmount/read/unmountを確認した。移行先でのクラウド認証とマウント確認、yazi-shellの固定パス解消が残る。認証情報はGitに含めない。
4. Neovimの外部LSP・フォーマッターをNixOS用home.packagesに宣言し、NixOSではMasonのPATHをappendに変更した。Omarchyの優先順位は維持。LuaLS・Stylua・shfmtに加え、設定済みの言語サーバー、Node・Rustビルド環境を用意する。gh_actions_lsは固定パッケージ集合に対応名がなく未導入。プラグイン本体・Treesitter文法の取得、実ファイルでの各LSP起動は引き続き確認が必要。
5. VMでは通常のgreetd画面からの再ログイン、PAM認証、2回のロック・解除・再ロックを確認済み。実機NixOSでサスペンド復帰、GPU、画面共有、音声・Bluetooth、WiFi、物理キーボード、mount、再起動を確認する。実ディスクへのインストールは別途承認を得る。

初期の隔離プレビューは既存Omarchyのセッション上で行った。ロック・polkit・通知・idleの競合を避けるため、試験用HOMEだけでそれらを無効化した。本番の機能無効化ではない。従って、この試験をNixOSの認証・通知サービスの動作証明には扱わない。

ディストリビューションの更新・インストール等は同梱しない。一部の旧管理メニューは互換窓口の対象外として明示的に失敗する。NixOSの管理はNixOSの宣言・ビルドで行う。全Omarchy管理機能の互換を主張しない。

## 2026-10-21の最終VM確認

前回のタイムアウトの一部は検証環境に由来した。Type=oneshotの検証がgraphical-session.targetを待たせてポータルと待ち合っていた点、サンドボックスで共有ストアのroot所有者と/dev/kvmが正しく見えなかった点、正常なFcitx state=0を未完了と判定した点を修正。KVM環境で新規VMの基本経路を再確認した。

実際の構成上の問題として、Quickshell 0.3.2の解除後通知欠落による再ロック不能を発見。[上流18c95faeの修正](https://github.com/quickshell-mirror/quickshell/commit/18c95fae4aec2f9da465c5f42d7ae13fe65f2aba)だけをpackages/quickshell.nixでバックポートし、NixOS用デスクトップから使用する。認証条件は変更せず、通常のキー入力で2回連続の解除・再ロックに成功した。現在のOmarchyへは適用していない。

このPCの計画フォルダnixos-readiness-check/result.md、validation.json、patched-runtime/xchgに証跡を保存した。VMの基本動作を確認した段階であり、すべてのアプリ・実機の移行完了ではない。

## 追加準備と移行当日の順序

追加準備では両OSのHome Manager activationPackage.drvPathとhome.packagesを評価し、成功した。追加ツールがNixOS側だけに入ることを確認した。全パッケージの取得・VM再試験は省略した。宣言の追加は導入先での実動作保証ではない。現在のOmarchyへのswitchは実行していない。

1. NixOS導入前にホームの実データと認証情報を別媒体へバックアップする。Git内の設定だけではクラウド認証やアプリデータは戻らない。
2. インストール先ディスクと既存OSの保持方針を確定し、承認後に実機用hardware-configurationを作る。現在のdesktop-vm定義は実機インストール用ではない。
3. 共通desktopモジュールとhosts/nixos.nixを実機定義へ接続する。まずログイン・画面・入力・ネットワーク・音声を確認する。
4. rcloneの認証を安全に移し、両クラウドのマウントを確認する。Mozkeyはまず既定のWayland入力を確認する。
5. Neovimの普段使う言語からLSP・整形を確認し、ChatGPT/Codex GUI・Herdr・TeX等の必要な本体を追加する。ロック・スリープ復帰・画面共有を実機で確認してから旧OSの廃止を判断する。

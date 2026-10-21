# NixOS移行に向けたOmarchy依存・デスクトップ同期調査

調査日: 2026-10-20 JST。現行のHome Manager構成と適用済み世代、実ファイル、chezmoiソース、パッケージ、実行中IPCを照合した。調査対象のデスクトップ関連ファイルは188件。

## 結論

現在のHome Manager構成だけで同じNixOSデスクトップを再現できる状態にはなっていない。Hyprland／QuickshellはNixOSとHome Managerで管理可能だが、現行構成には未登録。Omarchy独自の起動処理・Lua補助関数・QuickshellホストAPI・テーマ生成器の移植／置換が必要。

HyprlandのLua自体は公式機能であり、Omarchy専用ではない。固定済みアプリ用Nixpkgsは現行と同じHyprland 0.56.2を提供する。一方、Omarchy shellの個人プラグインをコピーしてQuickshell本体を導入するだけでは、現在のバーやOverviewは完成しない。

## 現在、何が同期されているか

| 対象 | 現物 | Home Manager | 現在のchezmoi |
|---|---:|---|---|
| Hyprlandユーザー設定 | 10ファイル（.bak除外） | 未管理・本体未導入 | 10件が有効。9件一致、looknfeel.luaに差分 |
| Quickshell個人プラグイン | 11ディレクトリ・101ファイル | 未管理・本体未導入 | 101件が有効で現物と一致 |
| Omarchy shellレイアウト | shell.json 1件 | 未管理 | 有効、現物と一致 |
| Omarchy shellホスト／標準プラグイン | /usr/share/omarchy/shell | 未管理 | OSパッケージ所有。個人dotfilesには含まれない |
| テーマ用テンプレート／hook | 4件 | 管理済み | 移管済みのため除外 |
| テーマ生成器・選択・生成済みstate | Omarchyパッケージとstate | 未管理 | OS／実行時処理に依存 |
| WezTerm設定 | 5件 | 未管理・本体未導入 | 有効、現物と一致 |

HMの評価結果はhyprlandEnabled=false、quickshellEnabled=false、quickshellConfigs=[]。調査対象188件のうちHM管理は上記テンプレート／hookの4件だけ。これは全体の70設定を否定する数字ではなく、今回調べたデスクトップ範囲に限る。

shell.jsonが指定する個人プラグイン10種類はIPC上でも有効と確認した。jeebis.islandsも保存されているが、現在選ばれているbarはjeebis.bar。標準のmonitor／network／bluetooth／audio／agentsや、背景・idle・lock・nightlight・通知・polkitの標準サービスも利用している。

## パッケージとモジュールの確認

| 項目 | 現行Arch／Omarchy | 固定済みHM用Nixpkgs | 固定済みアプリ用Nixpkgs |
|---|---|---|---|
| Hyprland | 0.56.2 | 0.55.4 | 0.56.2 |
| Quickshell | 0.3.1 | 0.3.0 | 0.3.2 |
| Herdr | 0.8.2 | 今回の対象外 | 0.9.5あり。版差の検証が必要 |
| 画面共有picker | 0.2.1 | 今回の対象外 | hyprland-preview-share-picker 0.2.1 |
| フォント | HackGen35 Console NFをfontconfigで確認 | 今回の対象外 | hackgen-nf-font 2.10.0 |
| Omarchy | 4.0.4 | 今回の対象外 | omarchy属性なし |
| Mozkey | mozkey-ibg-bin 0.10.4 | 今回の対象外 | mozkey／mozkey-ibg属性なし |

Home Managerの固定済みrelease-26.05実装にもHyprlandのconfigType="lua"とQuickshellのconfigs／systemdオプションがある。将来のNixOSでHyprlandとportal、QuickshellとQt依存を同じパッケージ系列で揃える必要がある。バージョンの存在と、画面・GPU・APIの互換性検証は別。今回はNixOS上での起動試験は行っていない。

前段の「HerdrをNixpkgsで用意できない」という整理は、今回確認したアプリ用入力には当てはまらない。0.9.5が存在するため、カスタムパッケージ作成より先に0.8.2設定との互換性を試す。

## NixOS移行を妨げる具体的な依存

### 1. HyprlandはOmarchyの起動ツリー全体を読み込む

[hyprland.lua](/home/jeebis/.config/hypr/hyprland.lua:4)は/usr/share/omarchy/default/hypr/bootstrap.luaをdofileする。その後default.hypr.omarchyとdefault.hypr.togglesをrequireする。bootstrapはユーザーconfig・Omarchy既定値・生成themeのLua検索パスを追加する。

`hl.*`はHyprland公式API。対して`o.bind`、`o.launch`、`o.window`等は[Omarchy helpers.lua](/usr/share/omarchy/default/hypr/helpers.lua:1)の補助層。mainの参照先だけ消すと補助関数や既定bindings・環境変数が消える。現在のfloating.luaのネイティブhl.*処理は再利用候補だが、同じ版での実動作検証が必要。

[既定autostart](/usr/share/omarchy/default/hypr/autostart.lua:1)はshell起動、初回provision、powerprofiles初期化、monitor監視、udiskie、hookを呼ぶ。NixOSへ既定autostartをそのまま持ち込まず、必要なユーザーサービスへ分解する。

### 2. QuickshellプラグインはOmarchy shellの上で動く

実際のエントリーポイントは[OS所有のshell.qml](/usr/share/omarchy/shell/shell.qml:1)。ユーザーのプラグインmanifestだけではShellRootが足りない。qs.Commons／qs.UiはOmarchy側のQMLモジュールであり、Quickshell本体を入れれば同時に用意されるものではない。

[jeebis.bar](/home/jeebis/.config/omarchy/plugins/jeebis.bar/Bar.qml:1)はPluginRegistry、bar API、Style／Color等を利用する。プラグイン間の相対importもあるため、各ディレクトリを単独で移動できない。[PluginShellApi](/usr/share/omarchy/shell/services/PluginShellApi.qml:1)とホストから注入される状態・サービスの互換面が必要。

Omarchy本体全体をNixOSへ持ち込むと更新・package・provision等のArch依存まで入る。既存バーの見た目と操作を維持するなら、必要なshellホスト／Commons／Ui／サービスを固定して切り出すか、同じAPIを提供する個人用Quickshell rootへ段階移植する。

### 3. shell.jsonはアプリが書き換える

[現在のshell.json](/home/jeebis/.config/omarchy/shell.json:1)はレイアウトと個人プラグインを選ぶ。ホストの[shell.qml](/usr/share/omarchy/shell/shell.qml:110)はuserConfigFile.setTextで保存する。バーの設定UI・並べ替え等を維持するなら、単純な読み取り専用storeリンクにしない。書込可能な管理元へのリンク、またはバックアップ付きコピーと明示的な取り込みを使う。shell.jsonの内容だけでなく、将来の書込先も移管設計に含める。

### 4. すでにHMへ移したアプリもテーマ生成に依存する

- Neovim: [theme.lua](/home/jeebis/Git/home-manager/files/nvim/lua/config/theme.lua:2)が.local/state/omarchy/current/theme/palette.luaを読む。ファイルがなければreturnするため、直ちに起動失敗と断定はできないが、統一テーマは再現されない。
- Yazi: theme.tomlがOmarchy stateのyazi.tomlを指す。生成器なしではリンク先を用意できない。
- bat: Omarchy.tmThemeがpreview.tmThemeを指し、変更後にはcache更新が必要。Zsh側にansiフォールバックはあるが、現在の配色そのものの再現にはならない。
- WezTerm: 現物のtheme.luaとwezterm.toml.tplも同じ生成stateに依存する。WezTerm設定とテンプレートはまだHM対象外。

「tplを同期したからテーマも再現できる」ではない。共通paletteからLua／Yazi／tmTheme／WezTermの各出力を作る生成処理と、切替・通知・cache更新が必要。テーマ選択を一箇所に集約する方針は維持する。

### 5. 起動コマンド・固定パス・サービス

- bindingsとバーはomarchy-menu、omarchy-shell、omarchy-launch-tui、omarchy-launch-or-focus、omarchy-capture-screenshot、omarchy-cmd-terminal-cwd、テーマ・統計・電源・更新等を呼ぶ。静的な参照一覧はdependency-references.jsonとomarchy-commands.jsonに保存した。後者にはコメントや識別子由来の候補も含み、全件が実行コマンドだとは扱わない。
- [jeebis-bar-action](/home/jeebis/.local/bin/jeebis-bar-action:1)には/usr/lib/libwebkit2gtk-4.1.so.0の存在確認がある。NixOSのパッケージ配置に合わせたAether導入と起動処理が必要。
- [yazi-shell](/home/jeebis/.local/bin/yazi-shell:14)は/usr/bin/zsh固定。NixOS向けにはNixパッケージの絶対パスか適切なPATHを使うラッパーへ置換する。
- rclone user unitは/usr/bin/rcloneと/usr/bin/fusermount固定。Nixパッケージの実パス、FUSE権限、mount・linger設計へ移す。認証情報は設定リポジトリと分ける。
- 端末フォント、fontconfigのmonospace選択、Wayland環境変数、UWSM、portalとpicker、polkit、PipeWire／WirePlumber、NetworkManager、BlueZ、ロック・idle等はNixOS側の宣言が必要。polkit agentや通知daemon等を二重起動しない。
- Mozkeyの現行PKGBUILDはArch Linux向け配布物を取得する。設定ファイルの同期だけでFcitx addon本体の再現とはならず、Nix向けのビルド／依存解決を検証する。
- Lazy／Sheldon／Mason等の実行時downloadも残っている。特に外部LSP等のLinuxバイナリはNixOSで別途互換性確認が必要。

## 現物を失わないための確認結果

有効なchezmoiソースと現物に差があるのは次の5件。移管時は古いソースで上書きせず、現物を基準としてレビューする。

- [/home/jeebis/.config/hypr/looknfeel.lua](/home/jeebis/.config/hypr/looknfeel.lua)
- [/home/jeebis/.config/omarchy/themes/aether/colors.toml](/home/jeebis/.config/omarchy/themes/aether/colors.toml)
- [/home/jeebis/.config/omarchy/themes/aether/icons.theme](/home/jeebis/.config/omarchy/themes/aether/icons.theme)
- [/home/jeebis/.config/systemd/user/rclone-gdrive.service](/home/jeebis/.config/systemd/user/rclone-gdrive.service)
- [/home/jeebis/.config/systemd/user/rclone-onedrive.service](/home/jeebis/.config/systemd/user/rclone-onedrive.service)

looknfeel.luaではdim_strength、opacity、animation、single-window比率が異なる。rclone unitではfusermountの版と--allow-non-emptyが異なる。aetherのpalette／iconsにも差がある。HMへ移管済みのbat hookが旧chezmoiソースと異なるのは、Nix PATH優先化による意図した差であり、二重管理へ戻さない。

選択中のテーマはtokyonight。調査したテーマ素材のうち21件は現状のchezmoi有効対象でもHM対象でもなく、対応ソースも今回見つからなかった。現在のtokyonight等のpalette・icons・背景・previewを含む。生成ツールの管理印も混ざるため、全てを無条件に設定扱いせず、再現に必要なpalette／素材と生成markerを分けて保全する。yazi-shellも両管理対象外。

## 今後の変更ファイルと順序（未実装）

1. **現物保存と責務分離**: 現行差分と必要なテーマ素材を保存。既存home.nix／modules/app-files.nixから共通部分とホスト依存部分を分け、`hosts/omarchy.nix`／`hosts/nixos.nix`を作る。移管済みCLIと既存Archの動作を維持する。
2. **デスクトップ設定の同期**: `modules/hyprland-files.nix`と`files/hypr/`へ現物10件、`modules/quickshell.nix`と個人plugin素材へ現物101件を取り込む。shell.jsonは書込可能な方式で管理する。この段階は設定保全であり、Omarchy依存解消の完了ではない。
3. **起動層とコマンドの移植**: `files/hypr/hyprland.lua`からOSパッケージのbootstrap／default読込を分離。必要なo.*補助層とキー操作を保持し、`packages/desktop-commands.nix`等のラッパーへ起動・capture・統計等を移す。キーを変える場合は同時に一覧を更新する。
4. **個人Quickshellホスト**: `files/quickshell/shell.qml`、Commons／Uiと必要サービス、既存plugin群を揃える。root設定と相対importを整合させる。Qt／Quickshellを同じ入力で固定して評価・起動し、バー、Overview、音量、ネットワーク、通知、polkit、idle等を確認する。
5. **テーマ生成の独立**: `modules/theme.nix`等でpaletteと素材から必要出力を生成し、各アプリの参照先を共通の設定値にする。ArchではOmarchy生成先を使い続け、NixOS側で独立生成器へ切替える。複数アプリのtheme selectorを増やさない。
6. **NixOS側のOS宣言**: `nixos/desktop.nix`へHyprland／portal／UWSM、音声・network・Bluetooth・polkit、フォント、Fcitx／Mozkey、mount等を定義。ハードウェア・ディスク構成は実機情報を使い別途作る。Home ManagerだけでOS設定まで完了と扱わない。
7. **VM／隔離セッションで検証**: Omarchyを置かないNixOSで起動し、通常操作・再ログイン・再起動・テーマ切替・IME・画面共有・mountを確認してから実機移行。ファイル同期成功やNix評価成功だけを完了条件にしない。

上記パスは正式リポジトリ /home/jeebis/Git/home-manager を基準にした作成候補。今回、これらの設定変更・適用は行っていない。

## 今回の実施範囲・限界

現在のHyprlandは0.56.2で応答し、configerrorsに非空のエラーなし。Lua7ファイルはluac -p成功。Omarchy shellはpingにok、個人plugin10件の有効状態を確認した。245個のキー登録を保存したが、Lua dispatcherのargはコールバックIDのため、binds JSONだけからOmarchyコマンド依存の有無は判定しない。

現在のPCでのIPC確認と静的照合を行った。NixOS VM、Nix版Quickshellと現行pluginの組合せ、GPU・portalの画面共有・Mozkey移植は未検証。アプリ終了・画面再起動の許可は得ているが、この調査では必要にならず、稼働環境を変更していない。

## 公式資料と根拠ファイル

- [Hyprland公式・Lua設定](https://wiki.hypr.land/configuring/core/): Luaは公式設定形式。native hl.*とOmarchy o.*を区別する。
- [Hyprland公式・Nix](https://wiki.hypr.land/nix/): OS側／Home Manager側の構成を組み合わせる出発点。
- [Quickshell公式・Nix導入](https://quickshell.org/docs/v0.3.0/guide/install-setup/): Nixpkgs系列の依存整合と追加QMLモジュールの扱い。
- [Home Manager公式・Quickshell](https://nix-community.github.io/home-manager/options/home-manager/programs/quickshell.html): configsとsystemdによる管理機能。
- 固定済みHome Managerのmodules/services/window-managers/hyprland.nixとmodules/programs/quickshell.nix、固定済みNixpkgsのNixOS Hyprland module／各パッケージ定義も現物を確認。
- [ローカル調査ディレクトリ](/home/jeebis/.codex/.chatgpt-projects/g-p-6ad2cfb48a4c8191aa95e46d0de40d3e/migration-plans/2026-10-19-chezmoi-home-manager/nixos-readiness)のdesktop-inventory.json、dependency-references.json、summary.json、nix-support.json、runtime-checks.json、runtime-plugins.jsonに照合結果を保存。


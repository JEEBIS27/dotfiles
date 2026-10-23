# jeebis-shell（Ruixenベース）

[Ruixen](https://github.com/gitcoder89431/ruixen-shell)はOmarchyシェル向けのプラグイン群。独立したQuickshellシェルではなく、Omarchyの基盤を必要とする。

## 構成

- `vendor/jeebis-shell/`：編集するソース。上流コミット`f776784308f9629633fa38817fdcf5986185e842`を基準に保存。
- `packages/jeebis-shell.nix`：ローカルソースのビルドと互換処理。
- `files/desktop/jeebis-shell.json`：標準バー、notch、ランチャー、壁紙、Shelf等の設定。
- `modules/desktop.nix`：プラグインと設定の配置、OS別の起動処理。

上流インストーラーは実行せず、プラグインと必要な共有ファイルをNixで配置する。設定は管理元への書き込み可能なリンク。UIで変更するとGit差分になる。履歴・キャッシュ・個人データは同期しない。

## 操作

| キー | 動作 |
|---|---|
| Super+F | Ruixen App Launcher（バー左端と同じアプリ起動） |
| Super+Shift+Esc | Ruixen設定 |
| Super+D | 既存のデスクトップ表示切替を維持 |

```bash
jeebis-desktop shell ruixen.notch toggleLauncher
jeebis-desktop shell shell toggle ruixen.launcher '{"extension":"settings"}'
```

Ruixen用キーは上記の2つだけとする。旧Super+Alt+Space・Super+Shift+Alt+Space・Super+R・Super+Shift+Rは解除する。Hyprlandが処理し、端末やアプリ内部のキー割当とは独立する。既存のSuper+D・Super+Tab・方向移動等は維持する。旧ワークスペース概要のSuper+Shift+Dは、対応プラグインの廃止に伴い解除する。

## 更新・対応範囲

見た目は`vendor/jeebis-shell/`内を編集し、再ビルド・Home Manager適用で反映する。上流更新はローカル変更と比較して手動で取り込む。上流のinstall/update/repairスクリプトによる管理対象への上書きは行わない。画面スケール・曲率はRuixenの設定画面から変更できる。`monitors.lua`は共通の初期値からコピーし、`looknfeel.lua`は導入前の個人設定を`files/hypr/looknfeel.lua`から管理する。Ruixenの曲率・アニメーション設定UIでは切り替えず、個人設定とShellConfig.jsを編集する。モニター設定のUI変更はGitへ自動反映しない。

Omarchyでは既存シェルに読み込む。NixOSでは同梱ランタイム用に設定・状態パスと色シングルトン参照を調整する。RuixenのOS管理・テーマブラウザー等にはOmarchyコマンド依存があり、NixOSで全機能の互換を保証しない。

動画・GIF壁紙にはQt Multimediaが必要。NixOS側は対応するQtパッケージを参照する。Omarchy側で未導入なら次を実行する。

```bash
omarchy pkg add qt6-multimedia-ffmpeg
omarchy restart shell
```

## 共通テーマ

Ruixenのテーマ・壁紙操作は[jeebis-desktopのテーマツール](theme-tooling.md)へ接続する。再起動操作も`jeebis-desktop shell restart`を使用する。Omarchyでは既存シェル、NixOSではuser systemdサービスを再起動する。

## 編集の入口

- バー全体：`vendor/jeebis-shell/bars/v2/ruixen.bar/Bar.qml`
- 背景・角丸：同じディレクトリの`GroupPill.qml`
- パネル：同じディレクトリの`BarPanel.qml`
- ワークスペース：`vendor/jeebis-shell/bars/widgets/ruixen.workspaces/Workspaces.qml`
- ノッチ：`vendor/jeebis-shell/bars/widgets/ruixen.notch/NotchWindow.qml`
- 配置・有効な機能：`files/desktop/jeebis-shell.json`

プロジェクト名はjeebis-shell。内部の`ruixen.*` IDは互換性のため維持する。
`vendor/jeebis-shell/LICENSE`と上流の著作権表示を保持する。
`files/desktop/ruixen-shell.json`は現在の適用済み世代用の互換リンク。新しい世代の適用までは削除しない。

ソースはNixでビルドするため、QMLの保存だけでは起動中のシェルに反映されない。
新規ファイルをGit管理に追加してから通常のflakeビルドを行う。未追加のまま検証する場合は`path:/home/jeebis/Git/home-manager`を指定する。
Home Manager適用やシェル再起動は別途承認を得て実施する。

## 個人の曲率・ウィンドウアニメーション

角丸の共通値は`vendor/jeebis-shell/ShellConfig.js`の`radius = 10`。導入前の`files/hypr/looknfeel.lua`の値に合わせる。ノッチのスカート・本体・影、Shelf、バー、ランチャーやカードに共通で使用する。円形アイコン、微小なインジケーター、接合部の直角は形状を維持する。QMLの半径は寸法の半分で制限される。

ビルド時に同じ値から`jeebis/curvature.lua`を生成し、Hyprlandのlooknfeel読込後に適用する。ウィンドウアニメーションは`files/hypr/window-animations.lua`で導入前のpopin 87%と速度・曲線に戻す。既存の不透明度・隙間・ブラー設定は変更しない。

## 変更の反映

QMLとShellConfig.jsはビルド済みコピーが動くため、保存だけでは反映されない。編集後は`bash /home/jeebis/Git/home-manager/scripts/jeebis-shell-apply.sh`でシェルのビルド・関連設定だけの切替・キャッシュ退避・再読み込みを行う。Home Manager全体は適用しない。

Hyprlandの基本値は導入前の個人設定（gaps_in/out=2、border_size=3、scrolling.column_width=0.50、active/inactive_opacity=1.0/0.95）。角丸はその後に共通ShellConfig.jsの編集値で上書きする。島の高さはShellConfig.jsの`islandHeight`。現在は28なのでradius=14で両端が半円になり、それ以上は同じ形。スケール追従には`radius: height / 2`を使う。

バーは表示切替やFrame Borderの設定変更時にもHyprlandのgaps_outを上書きしない。

## バーとノッチの寸法

ShellConfig.jsのislandTop=2とislandHeight=28を共有する。現在の島は高さ28、上端2、下端30。ノッチの閉じた下端・バーの予約領域も30に揃える。ウィンドウとの間はHyprlandのgaps_out=2。radiusの現在の編集値は変更しない。

## よく編集する設定の一覧

`vendor/jeebis-shell/ShellConfig.js`の先頭だけを編集する。islandHeight（高さ）、islandTop（上余白）、islandGap（島同士の間隔）、screenSideGap（左右余白）、islandPadding（内側余白）、radius（角丸）、barBottomGap（ウィンドウとの追加余白）、notchWidth（ノッチ幅）、notchBottomOffset（島との下端の差）、notchMoveDuration/notchResizeDuration（動作時間）。ノッチの下端を揃えるにはnotchBottomOffset=0。現在は島の高さ28なので、半円になるradiusは14。heightを変えても共通計算により下端と予約領域が追従する。

横方向の調整：`screenSideGap`は画面の左右端から島までの余白（左右共通）、`islandGap`は島と島の間、`islandPadding`は島内部の左右余白。画面端に近づける場合はscreenSideGapを小さくする。

## ノッチのステータス表示

閉じたノッチは左から接続中ネットワークの強度・バッテリー残量、中央が時刻、右が音量・通知ベル。独立した時計・天気の島は無効。時刻のクリックでダッシュボード、音量のクリックで音量メニューを開く、ホイールで音量変更。通信・電源・音量はQuickshellのネイティブAPIで取得する。

ShellConfig.jsの`notchIconSize`、`notchClockFontSize`、`notchTooltipFontSize`で文字サイズを調整する。図形アイコンは`notchBatteryWidth/Height`、`notchNetworkHeight`、`notchNetworkBarWidth/Gap`で調整する。`notchContentPadding`が左右の内側余白、`notchStatusGap`が左のアイコン間隔、`notchClockHeight`が時刻背景の高さ。

アイコン内に数値は常時表示しない。ネットワークの棒・バッテリー充填量・音量の波形段階で状態を表し、ホバーで数値を表示する。クリックはネットワーク・電源・音量・通知の各メニューを開く。4つともノッチ直下の中央に表示し、外側クリックまたはEscで閉じる。右の島の重複するバッテリー表示は無効。

メニュー寸法はShellConfig.jsの`notchMenuWidth`（幅）、`notchMenuHeight`（最大高さ）、`notchMenuGap`（ノッチ下端からの間隔）で調整する。ベルの大きさは`notchBellIconSize`。ネットワーク・音量は既存設定画面の操作を再利用し、電源と通知は専用メニューを使う。

アイコンの位置は`notchStatusSlotWidth`（各固定枠）、`notchStatusGap`（枠間）、`notchClockWidth`、`notchClockGap`で決める。描画サイズだけを変更しても各枠の中心とクリック範囲は変わらない。音量・ベルはPhosphor Icons v2.1.1のfill SVG（同梱MITライセンス）を使用。

共通設定は`vendor/jeebis-shell/ShellConfig.js`（旧Geometry.js）。`batteryLowThreshold`（30%）以下でテーマのyellow/color3、`batteryCriticalThreshold`（10%）以下でテーマの`Color.urgent`、充電中はテーマのgreen/color2を使用する。充電色を優先し、アイコンの内側の残量部分のみ色を変える。外枠と端子は通常色を維持する。`batteryShowChargingBolt = false`で充電中の中央稲妻を非表示にできる。

## バーの要素を非表示にする

`files/desktop/jeebis-shell.json`の`bar.layout.left`・`center`・`right`から対象の`{"id": "..."}`を削除する。plugins配列は常駐機能なのでバーの表示変更には触れない。leftのruixen.applauncherはアプリ一覧、ruixen.workspacesはワークスペース、ruixen.pinnedappsはピン留め・起動中アプリ。rightのruixen.trayはトレイ、ruixen.stayawakeはスリープ抑止、omarchy.agentsはAgent利用量、ruixen.pluginpinsは追加ウィジェット、omarchy.system-updateは更新、ruixen.quickactionsはクイック操作、ruixen.settingsbuttonは設定、ruixen.launcherbuttonは検索。JSONなのでコメント不可。保存後はjeebis-shell-apply.shで反映する。

ダッシュボードのAgentボタンは、ノッチを閉じて公開IPC `omarchy-shell omarchy.agents open`で既存の利用量・Limitパネルを開く。バーからomarchy.agentsを外すと既存パネルも未ロードになるため、このボタンを使う場合は残す。

## 個人バーの動作

全島共通の間隔はShellConfig.jsの`islandGap`。Agentsと日付の間も1回だけ加算する。Trayは以前のホバー引き出しと右クリックの表示管理を使用。Agents島はLimitアイコンのみ。ChatGPT/Codexの起動ボタンと専用の扱いは廃止し、App島で通常のアプリと同じ表示・合流・分離の規則を使う。

ワークスペースは現在の形・最小5個を維持し、プロセスツリーのCPU負荷が`workspaceCpuBusyThreshold`以上で続いた場合、またはウィンドウ起動直後にスピナーを表示する。`workspaceCpuResetThreshold`未満で解除する。旧収集スクリプトのPID読取位置も修正した。

`ruixen.load`は旧個人設定と同じくCPU35%以上、RAM85%以上、またはロード平均がCPU数以上の時だけ該当値を表示する。`cpuHighThreshold`と`memoryHighThreshold`で調整可能。バーの色・角丸は現在のテーマとShellConfig.jsの共通値を使用する。

Trayは`trayCollapseEnabled = false`で常時全表示、trueで矢印への収納を使う。アプリの合流・分離は旧jeebis.appsのAppGroup.qmlとBarWidget.qmlをruixen.appsとして移植した。ワークスペースへホバーするとアプリ島を再表示し、ウィンドウ起動・終了時は旧appArrival/appDepartureのフェーズを使用する。独立カプセルと本体の色・角丸・影は現行GroupPillと同じ。Agent島の隠れた設定ボタン由来の固定8px余白は除去し、左右ともislandPaddingで揃える。

日付のフォントは`dateFontFamily`、文字サイズは`dateFontSize`で独立調整する。初期値は旧個人バーと同じmonospace・10px・通常ウェイト。時刻の設定には影響しない。

## 配置順・Float島・伸縮

App島はタイリング用とFloat用を同時に持ち、Float島を右隣に配置する。各グループはウィンドウの左端座標、同じ場合は上端座標で並べる。同じアプリの複数ウィンドウは従来どおりまとめ、最も左のウィンドウを基準にする。並べ替えは既存のappDeparture.reorderingMsでアニメーションする。Float切替は出発側の分離が始まると同時に、隣接側から到着アイコンを動かす。App島からFloat島へは右、Float島からApp島へは左へ向かう。Float専用special workspaceに一時退避しているウィンドウも、タグに記録した元のワークスペースを使ってFloat島に残す。単なる表示切替では新規起動アニメーションを再生せず、途中で逆方向に切り替えた場合は最新の操作を優先する。

`workspaceResizeDuration`は丸の増減と選択幅の変化による伸縮時間、`appOrderPollMs`は実配置の更新間隔。処理の待機時間を含む合流・分離は既存のappArrival/appDepartureを使う。

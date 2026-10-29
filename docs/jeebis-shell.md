# jeebis-shell（Ruixenを基にした個人用構成）

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

このリポジトリでは個人用の構成・配布名をjeebis-shellに統一する。Omarchyが認識する上流由来の`ruixen.*`プラグインIDと上流コードの出典表示は互換性・ライセンス上維持する。
`vendor/jeebis-shell/LICENSE`と上流の著作権表示を保持する。
`files/desktop/jeebis-shell.json`を唯一の管理設定とする。

ソースはNixでビルドするため、QMLの保存だけでは起動中のシェルに反映されない。
新規ファイルをGit管理に追加してから通常のflakeビルドを行う。未追加のまま検証する場合は`path:/home/jeebis/Git/home-manager`を指定する。
Home Manager適用やシェル再起動は別途承認を得て実施する。

## 個人の曲率・ウィンドウアニメーション

角丸の共通値は`vendor/jeebis-shell/ShellConfig.js`の`radius = 10`。導入前の`files/hypr/looknfeel.lua`の値に合わせる。ノッチのスカート・本体・影、Shelf、バー、ランチャーやカードに共通で使用する。円形アイコン、微小なインジケーター、接合部の直角は形状を維持する。QMLの半径は寸法の半分で制限される。

ビルド時に同じ値から`jeebis/curvature.lua`を生成し、Hyprlandのlooknfeel読込後に適用する。ウィンドウアニメーションは`files/hypr/window-animations.lua`で導入前のpopin 87%と速度を保ち、曲線はShellConfig.jsの共通プリセットを使う。既存の不透明度・隙間・ブラー設定は変更しない。

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

## 共通アニメーションプリセット

`vendor/jeebis-shell/ShellConfig.js`の先頭で、Hyprland・ノッチ・バーを独立して選択する。値はQt Quickの`Easing`名（`Easing.`は不要）。

```js
var hyprlandAnimationPreset = "InOutSine";
var notchAnimationPreset = "OutBounce";     // ノッチ内部の通常動作・時計・ダッシュボード
var notchShowAnimationPreset = "OutBounce"; // ノッチ単独の表示
var notchHideAnimationPreset = "InQuart";   // ノッチ単独の非表示
var barAnimationPreset = "OutBounce";       // バー内部・App/Float島・その他のShell UI
var barShowAnimationPreset = "OutBounce";   // バー・左右の島の表示
var barHideAnimationPreset = "InQuart";     // バー・左右の島の非表示
var animationSpeed = 1.2; // 共通速度。2=2倍速、0.5=半速
var animationOvershoot = 1.70158; // OutBackだけの行き過ぎ量
```

| プリセット | 動き | Hyprland | ノッチ・バー |
|---|---|---|---|
| `Linear` | 一定速度 | 対応 | 対応 |
| `InOutSine` | 三角関数S字 | ベジェ近似（最大進捗誤差約0.022%） | 対応 |
| `OutBack` | 行き過ぎて戻る | ベジェ変換 | 対応 |
| `OutBounce` | 到着時に跳ね返る | 未対応 | 対応 |
| `InQuart` | ゆっくり出発し加速 | 未対応 | 対応 |

無効・未対応の値は`InOutSine`に戻る。一体の`bar`モードではノッチもバー用の表示・非表示設定に従い、`islands`モードではノッチ用の設定に従う。表示途中に反転した場合も、その時点の表示／非表示用曲線を使う。範囲に制約のある値は`OutBack`を`InOutSine`へ置き換える。`OutBounce`と`InQuart`は0〜1に収まるため、そのまま使う。基準時間と共通速度倍率は従来どおり。

Nixビルド時に`hyprland/jeebis-motion.lua`を生成し、Home Managerと`jeebis-shell-apply.sh`が`~/.config/jeebis/motion.lua`へ配置する。生成ファイルは直接編集しない。適用スクリプトはHyprlandの再読み込みも行うため、実行時はその変更も画面へ反映される。

共通速度は`animationSpeed`で調整する（0.1〜10倍）。各動作の元の時間を倍率で割るため、速度2なら時間は半分になる。jeebis-shell全体とHyprlandに共通で反映し、表示維持時間や操作待ちタイマーには適用しない。無効値・0・負数は1倍に戻す。

## 使用しない上流Hyprlandプリセット

Home Managerでは`files/hypr/`を読み込む。上流の`vendor/jeebis-shell/hyprland/looknfeel.*.lua`と`ruixen-lookfeel.sh`はNixパッケージへコピーせず、`~/.local/share/jeebis-shell/hyprland`への一括配置もしない。旧データ移行でもこのディレクトリを除外する。

上流ソース内のプリセットは上流install/update/uninstallスクリプトとそのテストから参照されるため保持する。現行Nix構成の編集対象ではない。`ShellConfig.js`から生成する`jeebis-curvature.lua`と`jeebis-motion.lua`だけは引き続き必要で、`~/.config/jeebis/`から読み込む。

## バー・ノッチの表示モード

| キー | 表示対象 | 切り替え | ウィンドウとの関係 |
|---|---|---|---|
| Super+B | ノッチを含むバー全体 | 自動表示 ↔ 常時表示 | 重ねる |
| Super+N | 独立した左・ノッチ・右の島 | 自動表示 ↔ 常時表示 | 重ねる |
| Super+Shift+B | バー全体 | 常時表示 ↔ 完全非表示 | 表示時に領域確保 |
| Super+Shift+N | 独立した左・ノッチ・右の島 | 常時表示 ↔ 完全非表示 | 表示時に領域確保 |

`bar`モードは左・ノッチ・右を一体で表示する。`islands`（島）モードは3つを独立して表示する。旧`notch`モードは`islands`へ移行する。島モードの自動表示では重なった島だけを表示する。常時表示ではノッチだけを常時表示し、左右はホバー・トリガーで自動表示する。完全非表示では3つとも表示しない。別の対象・方式のキーを押すとその方式へ切り替える。同じShift付きキーを常時表示中にもう一度押すと完全非表示になり、マウス・アプリ開閉・ワークスペース切替でも表示しない。

自動表示のマウス呼び出し判定は、画面最上端の1論理pxに限定する。非表示中のバー本体は入力を通し、ウィンドウのタイトルバー操作を妨げない。表示後はバーや島の上にいる間、表示を維持する。自動表示では上端へのマウス移動中と、アプリ開閉・ワークスペース切り替え後に表示する。`ShellConfig.js`の`barActivityShowDuration = 2000`（ms）は最後のイベントからの表示時間、`barSlideDuration = 260`は上端から出入りするスライド時間。前者は共通アニメーション速度に左右されず、後者は速度倍率と選択したQt Quickプリセットに追従する。

表示モードは`~/.local/state/jeebis-shell/bar-mode.json`に保存し、バーからノッチへの同期には`bar-visibility.json`を使う。描画ウィンドウと予約領域を別にするため、自動表示・重ねる常時表示でウィンドウの配置は動かない。Shift付きの常時表示はどちらのモードでも上部に予約領域を確保する。

## Quickshell全体の共通アニメーション

jeebis-shell内の数値・色・回転アニメーションは`motion/Jeebis*.qml`を経由し、`ShellConfig.js`の用途別プリセットと`animationSpeed`を参照する。バーの出入り、ワークスペース、トレイ、ノッチ展開、カード、ランチャー、設定画面、Shelf、壁紙効果も対象。追加するアニメーションはこの共通部品の`baseDuration`へ基準時間を渡す。

透明度・色などの範囲が限られる値は`bounded: true`を使い、OutBack選択時も範囲内のInOutSineで変化させる。バーのスライド位置はOutBackを使用できる。装飾的な波は`motionProgress()`と`motionSpeed()`を使用する。実際の再生位置、入力待ち、表示維持、更新周期、PauseAnimationによる待機時間は速度倍率で変更しない。Omarchy本体の共有UI内部にあるアニメーションはこのソースの対象外。

## 自動表示を起こすトリガー

`ShellConfig.js`の`barTriggerModes`で、各トリガーを有効にする**モード**を指定する。

```js
var barTriggerIslandOnly = true; // 島モードでトリガー元の島だけを一時表示
var barTriggerModes = {
  app_open: "both",
  app_close: "both",
  workspace: "islands",
  low_battery: "both",
  agent_limit: "both",
  volume_change: "islands",
  notification: "islands",
  network_disconnect: "both",
  network_reconnect: "islands"
};
```

- `bar`: バー全体の自動表示モード（Super+B）でだけ反応する。
- `islands`: 島の自動表示モード（Super+N）でだけ反応する。旧値`notch`も移行用に同じ意味として受け付ける。
- `both`: 両方の自動表示モードで反応する。
- `none`: このトリガーを無効にする。未指定・無効な値も同じ。

値は表示対象への切り替え指示ではない。例えば`low_battery: "bar"`はバー全体モードのときだけ低バッテリーで一時表示し、島モードでは反応しない。`both`なら両モードで反応する。モードは変更しない。バーモードの常時表示・完全非表示には影響しない。島モードの常時表示では左右の自動表示が有効なため、左右の島のトリガーに反応する。

`barTriggerIslandOnly = true`では、島モードでトリガー元の島だけを一時表示する。アプリ開閉はApp島のある側、ワークスペースはその表示のある側、AgentのLimit切れはAgent島のある側（現在は右）。バッテリー・音量・新規通知・ネットワークはノッチ。左右の配置はバーのレイアウトから判定する。`false`なら島モードでもトリガーで3つ全てを表示する。バーモードではこのスイッチにかかわらず常に全体が一体で表示される。

表示時間は共通の`barActivityShowDuration`（初期値2000ms）。同じトリガーや別の有効なトリガーが続くと、最後の発生から数え直す。カーソルが重なっている間は引き続き表示する。島モードでは各島が個別のタイマーを持ち、他の島のイベントで表示時間は延長されない。島間の空白はホバー対象にしない。

低バッテリーは`batteryLowThreshold`（黄色になる%）以下の非充電状態へ移ったときに反応する。充電中は反応せず、低残量で充電を外すと反応する。Agentは既存の`~/.local/state/omarchy/agents/usage/*.json`の利用枠（0〜1）が100%になったときに反応し、リセット済みの古い利用枠は無視する。取得処理は既存のAgent収集処理を使い、トークン数からLimitを推定しない。

音量変更は既定出力の音量・ミュート変更、新規通知は既存の通知履歴取込で新しく到着した通知、ネットワークはWi-Fi・有線の接続有無の変化を使う。Wi-Fiから有線へ接続が保たれたまま切り替わる場合や、通知の内容更新・既存履歴の再読込では反応しない。サービス起動時の最初の状態は基準として記録し、一時表示を起こさない。

## ノッチ時計の数字の入れ替え

ノッチ中央の時計は、変化した桁だけが上へ抜け、新しい数字が下から回り込む。コロンと変化しない桁は動かさず、初回表示や非表示中の更新は即時に反映する。横幅を固定して桁の入れ替えで位置が揺れないようにし、狭いノッチでは全体を縮小する。時刻の詳細ツールチップとクリック操作は従来どおり。

`ShellConfig.js`の`notchClockRollEnabled`でオン・オフ、`notchClockRollDuration`（初期値420ms）で基準時間を調整する。曲線は`notchAnimationPreset`、速度は`animationSpeed`に従う。

## ノッチ単独の出入り

`islands`モードのノッチは上端中央を固定して拡大・縮小する。`OutBack`でサイズが1を超えても、上端は画面から離れない。消えるときの負のオーバーシュートは0で止め、反転表示を防ぐ。`bar`モードでは左右の島と揃ったスライドを維持する。

自動表示の時間・曲線・速度は引き続き`barSlideDuration`・用途別のShow/Hideプリセット・`animationSpeed`を参照する。従来のノッチ独自のホバー表示も、島モードでは同じ上端固定の拡大・縮小を使う。

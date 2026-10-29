.pragma library

// 単位：寸法・文字サイズは論理px、時間はms、使用率は%。
// 編集後: bash /home/jeebis/Git/home-manager/scripts/jeebis-shell-apply.sh

// ===== アニメーション：プリセット（Qt Quick Easing名、Easing.は不要） =====
// Hyprlandで使える値:
//   Linear: 一定速度 / InOutSine: 三角関数S字（ベジェ近似）
//   OutBack: 行き過ぎて戻る（ベジェ変換）
// ノッチ・バーで使える値:
//   上記3つ + OutBounce: 到着時に跳ね返る / InQuart: ゆっくり出発して加速
// 無効な値はInOutSineに戻る。HyprlandはOutBounce・InQuart未対応。
// 通常: 展開・縮小・並べ替え等。Show/Hide: バーやノッチ全体の出現/退場。
// 一体のbarモードではノッチもbar用のShow/Hideに従う。
// Delay after a floating window stops moving before resolving excessive overlap (milliseconds).
// Applied to Hyprland by the desktop build.
var floatOverlapDelayMs = 100;
// Move when this percentage of the moving window's own area overlaps another float.
var floatOverlapThresholdPercent = 90;

var hyprlandAnimationPreset = "InOutSine";
var notchAnimationPreset = "OutBack";
var notchShowAnimationPreset = "OutBack";
var notchHideAnimationPreset = "InBounce";
var barAnimationPreset = "OutBack"; // その他のShell UI（ランチャー等）の既定も兼ねる
var barShowAnimationPreset = "OutBounce";
var barHideAnimationPreset = "InQuart";
// 編集後は再ビルド・シェル再起動。Hyprland設定変更は再読み込みも必要。
// 共通の速度倍率。1=従来、2=2倍速（半分の時間）、0.5=半速。範囲0.1〜10。
// アニメーションだけを変更。表示待機・ツールチップ・処理待ちは変更しない。
var animationSpeed = 1.2;

function motionSpeed() {
  var value = Number(animationSpeed);
  return isFinite(value) && value > 0 ? Math.max(0.1, Math.min(10, value)) : 1;
}
function motionDuration(milliseconds) {
  return Math.max(1, Math.round(milliseconds / motionSpeed()));
}

// Qt OutBackの強さ。OutBounceのバウンドには影響しない。
var animationOvershoot = 1.70158;

function motionPreset(bounded, group, direction) {
  var preset = group === "notch" ? notchAnimationPreset : barAnimationPreset;
  if (direction === "show")
    preset = group === "notch" ? notchShowAnimationPreset : barShowAnimationPreset;
  else if (direction === "hide")
    preset = group === "notch" ? notchHideAnimationPreset : barHideAnimationPreset;
  preset = String(preset);
  if (["Linear", "InOutSine", "OutBack", "OutBounce", "InQuart"].indexOf(preset) < 0)
    return "InOutSine";
  // Bounce stays within 0..1; only Back needs a bounded replacement.
  return bounded && preset === "OutBack" ? "InOutSine" : preset;
}

// Normalized easing for frame-driven decorative motion, matching the Qt types.
function motionProgress(progress, bounded, group) {
  var t = Math.max(0, Math.min(1, Number(progress) || 0));
  var preset = motionPreset(bounded, group);
  if (preset === "Linear") return t;
  if (preset === "InQuart") return t * t * t * t;
  if (preset === "InOutSine") return (1 - Math.cos(Math.PI * t)) / 2;
  if (preset === "OutBounce") {
    // Qt's default-amplitude, piecewise parabolic OutBounce curve.
    if (t < 1 / 2.75) return 7.5625 * t * t;
    if (t < 2 / 2.75) { t -= 1.5 / 2.75; return 7.5625 * t * t + 0.75; }
    if (t < 2.5 / 2.75) { t -= 2.25 / 2.75; return 7.5625 * t * t + 0.9375; }
    t -= 2.625 / 2.75;
    return 7.5625 * t * t + 0.984375;
  }
  var u = t - 1, strength = motionOvershoot();
  return 1 + (strength + 1) * u * u * u + strength * u * u;
}
function motionOvershoot() {
  var value = Number(animationOvershoot);
  return isFinite(value) ? Math.max(0, Math.min(3, value)) : 1.70158;
}

// ===== バーの自動表示 =====
// Super+B/Nの自動表示で、アプリ開閉・ワークスペース切替後の表示時間（ms）。
// アニメーション速度倍率の影響を受けない。
// ===== 自動表示のトリガー =====
// 有効にするモード: bar: 一体のバーモード、islands: 独立する島モード、both: 両方、none: 無効
// 自動表示中のみ有効。表示する形は現在のモードに従い、モード自体は変更しない。
// 島モード時: trueならトリガー元の島だけ、falseなら全ての島を一時表示
var barTriggerIslandOnly = true;
var barTriggerModes = {
  app_open: "both",
  app_close: "both",
  workspace: "islands",
  low_battery: "both",        // batteryLowThreshold（黄色になる%）以下へ移行
  agent_limit: "both",        // 取得済みの利用枠が100%へ到達
  volume_change: "islands",     // 出力音量・ミュートの変更
  notification: "islands",      // 新規通知（既存通知の更新・再読込は対象外）
  network_disconnect: "both",
  network_reconnect: "islands"
};
var barActivityShowDuration = 2000;
var barSlideDuration = 260; // 上端から出入りする時間（ms、共通速度倍率に追従）

// ===== 共通の見た目・バーの配置 =====
var radius = 15; // 全体の角丸。島の高さ30なら15で両端が半円
var islandHeight = 30;           // 島の高さ（内容より小さくしすぎない）
var islandTop = 4;               // 画面上端から島までの余白
var islandGap = 4;               // 全島共通の間隔（Agentと日付、CPU島も含む）
var screenSideGap = 4;          // 画面左右から一番外側の島までの余白
var islandPadding = 6;           // 島内部の左右余白（ランチャーボタン以外）
var launcherPadding = 4;         // ランチャーボタンの島内部の左右余白
var barBottomGap = 2;            // バーの下の追加余白（Hyprlandの隙間2に加算）

// ===== ワークスペース：表示数・選択幅・処理中判定 =====
var workspaceMinimumCount = 3; // 最低限並べるワークスペース数。使用中は追加表示
var workspaceActiveWidth = 11;    // 現在のワークスペースの横幅。11で他の丸と同幅
var workspaceSpinnerOffsetY = 2; // スピナーの上下補正（論理px）。正の値で下へ
var workspaceCpuBusyThreshold = 10; // このCPU使用率（%）が続くワークスペースにスピナーを表示
var workspaceCpuResetThreshold = 5; // このCPU使用率（%）未満でスピナーを解除

// ===== Tray・アプリ島：収納・配置更新 =====
var appOrderPollMs = 350; // ウィンドウの実配置を更新する間隔
var trayCollapseEnabled = false; // trueでTray・アプリ島を収納、falseで両方とも常時表示

// ===== 高負荷島：表示するしきい値 =====
var cpuHighThreshold = 35; // CPU使用率（%）がこの値以上なら表示
var memoryHighThreshold = 85; // メモリ使用率（%）がこの値以上なら表示

// ===== ノッチ：大きさ・位置 =====
var notchWidth = 175;            // 閉じたノッチ中央部分の幅（スカートは別）
var notchBottomOffset = 2;       // 島の下端との差。0で一致、正なら下に伸びる
var notchContentPadding = 4;     // ノッチ内側の左右余白

// ===== ノッチ：時刻・文字 =====
var notchFontFamily = "hackgen35 console bold"; // 数字のフォント
var notchClockFontSize = 15;     // 中央の時刻
var notchClockRollEnabled = true; // 変わる桁だけ縦に回して入れ替える
var notchClockRollDuration = 420; // 桁の入れ替え時間（ms、共通プリセット・速度倍率に追従）
var notchTooltipFontSize = 11;   // ホバー時の数値・状態
var notchClockWidth = 65;       // 時刻の固定幅（狭いノッチでは縮小）
var notchClockHeight = 24;       // 時刻を囲む背景の高さ
var notchClockGap = 5;          // 時刻と左右アイコン枠の間隔

// ===== ノッチ：アイコンの配置・描画サイズ =====
var notchStatusSlotWidth = 16;  // 各アイコンの固定枠幅。絵のサイズを変えても中心位置は不変
var notchStatusGap = 8;          // ネットワークとバッテリーの間隔
var notchIconSize = 14;          // 音量アイコンの大きさ
var notchBellIconSize = 14;      // 通知ベルの大きさ
var notchBatteryWidth = 20;      // バッテリーの全幅（端子を含む）
var notchBatteryHeight = 10;     // バッテリーの高さ
var notchNetworkHeight = 12;     // ネットワークバーの最大高さ
var notchNetworkBarWidth = 2;    // 各ネットワークバーの太さ
var notchNetworkBarGap = 1.5;    // バー同士の間隔

// ===== バッテリー：色と充電マーク =====
var batteryLowThreshold = 30;     // この残量（%）以下はテーマの黄色系
var batteryCriticalThreshold = 10; // この残量（%）以下はテーマのurgent色
var batteryShowChargingBolt = false; // 充電中の稲妻を表示（falseで非表示）

// ===== ノッチ直下のメニュー =====
var notchMenuWidth = 420;        // ノッチ直下のメニュー幅
var notchMenuHeight = 400;       // メニューの最大高さ
var notchMenuGap = 4;            // ノッチ下端とメニューの間隔

// ===== 日付島：フォント・内側余白・区切り線 =====
var dateFontFamily = "monospace"; // 日付専用のフォント（時刻とは独立）
var dateFontSize = 10; // 日付・曜日の文字サイズ
var dateIslandPadding = 12;      // 日付島の内側の左右余白（片側の幅）
var dateSeparatorGap = 4;        // 縦線の左右余白
var dateSeparatorHeight = 12;    // 縦線の高さ（幅は1px）

// ===== アニメーション：ノッチ =====
var notchMoveDuration = 260;     // ノッチが上端から出入りする時間
var notchResizeDuration = 230;   // ノッチが展開・縮小する時間

// ===== アニメーション：Tray・高負荷島・ワークスペース =====
var workspaceResizeDuration = 220; // 丸の増減・選択幅の変化による島の伸縮時間
var trayDrawer = Object.freeze({
  // トレイの引き出しを展開・収納する。
  changingMs: 600
});
var loadIsland = Object.freeze({
  // 高負荷の項目が発生して情報島が現れる。
  enteringMs: 240,
  // 高負荷が解消して情報島が隠れる。
  leavingMs: 240,
  // 表示する負荷項目数の変化に合わせて幅を変える。
  resizingMs: 180
});
var workspaceActivity = Object.freeze({
  // 処理中スピナーを次のコマへ進める間隔。
  cyclingMs: 90,
  // ウィンドウ起動後のスピナー表示を保つ。
  settlingMs: 1800
});

// ===== アニメーション：アプリ島の表示・合流・分離 =====
var appIsland = Object.freeze({
  // アプリ島がワークスペース島側から右へ流れ、幅と不透明度を増して現れる。
  enteringMs: 240,
  // アプリ島がワークスペース島側（左）へ戻りながら縮小して隠れる。
  leavingMs: 240,
  // 通常のアイコン数変更に合わせて島の幅を変える。
  resizingMs: 180,
  // 通常のワークスペース選択・ウィンドウ変更後に表示を保つ。
  presentMs: 2000,
  // カーソルがアプリ島とワークスペース島を離れてから隠し始める猶予。
  releasingMs: 150
});
// App島⇔Float島専用。起動・終了のフェードや待機時間から独立。
var appTransfer = Object.freeze({
  movingMs: 360,  // 同じアイコンを消さずに移動する時間
  settledMs: 1000 // 移動後に島を表示し続ける時間
});
var appArrival = Object.freeze({
  // 既存アプリがある場合、新規アプリを除いたアプリ島を先に表示する。空なら省略。
  preparingMs: 240,
  // 右側の独立島がフェード・移動しながら現れる。
  enteringMs: 240,
  // 完全に現れた独立島を表示し続ける。
  presentMs: 240,
  // 既存島へ合流する。受け皿が空の場合は独立島だけが通常位置へ移動する。
  joiningMs: 320,
  // 合流完了後にアプリ島を表示し続ける。
  settledMs: 1000
});
var appDeparture = Object.freeze({
  // 閉じるアイコンを右端へ並べ替える。連続終了時も移動完了後に順番に分離する。
  reorderingMs: 320,
  // 閉じたアプリのアイコンを含むアプリ島を、分離前に表示する。
  preparingMs: 400,
  // 閉じたアイコンがアプリ島から右へ分離する。島の幅変更も同期する。
  separatingMs: 320,
  // 分離した独立島が縮小・フェードアウトする。
  leavingMs: 240,
  // 分離・消滅後に残ったアプリ島を表示し続ける。
  settledMs: 1000
});
var centerCompanions = Object.freeze({
  // アプリ島の構成変更後、アイコン位置を整えてから通常表示へ戻す。
  movingMs: 240
});

// ===== 連動計算（通常は編集不要） =====
function barRowHeight(style) { return islandHeight + style.space(2); }
function barTopInset(style) { return islandTop - style.space(2) / 2; }
function islandBottom() { return islandTop + islandHeight; }
function collapsedBottom(style) { return islandBottom() + notchBottomOffset; }
function reservedHeight(style) { return Math.max(islandBottom(), collapsedBottom(style)) + barBottomGap; }

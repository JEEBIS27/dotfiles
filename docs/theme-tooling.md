# テーマツール

固定の配色・ホーム壁紙・ロック壁紙をセットで切り替える。Aether・Matugenは不要。

## 設定元

`files/desktop/presets.json`の配列順が切替順を決める。

```json
[
  { "name": "tokyonight", "palette": "tokyonight", "wallpaper": "tokyonight.jpg", "lockWallpaper": "tokyonight.jpg" },
  { "name": "kanagawa", "palette": "kanagawa", "wallpaper": "kanagawa.jpg", "lockWallpaper": "kanagawa.jpg" },
  { "name": "catppuccin", "palette": "catppuccin", "wallpaper": "catppuccin.png", "lockWallpaper": "catppuccin.png" }
]
```

paletteは`files/desktop/themes/<名前>.toml`、wallpaperは`files/desktop/backgrounds/<ファイル名>`。配色と画像は独立して選べる。壁紙を変更しても配色は変わらない。

## 操作

```sh
jeebis-desktop theme list
jeebis-desktop theme show kanagawa
jeebis-desktop theme set kanagawa
jeebis-desktop theme cycle
```

`show`は組合せの表示だけ、`set`は配色と壁紙の両方を適用する。`cycle`はTokyonight→Kanagawa→Catppuccinの順。バーのクリックは共通プリセット選択、ダブルクリックは次のセットに切替。GUIエディターは不要。

Omarchyでは共通paletteをユーザーテーマのcolors.tomlとして配置し、既存生成器で配色を適用した後、指定壁紙を設定する。NixOSでは同じpaletteと画像を独立生成器とシェルへ渡す。アプリごとに別のテーマ選択を追加しない。

設定を反映するHome Managerのswitch自体では現在の選択や壁紙を変更しない。次にset/cycleを実行した時から固定の組が使われる。

## 配色定義とbat用テーマ

`files/desktop/themes/*.toml`はアプリ共通の配色定義。テンプレートから`preview.tmTheme`等を生成し、batは`~/.config/bat/themes/Desktop.tmTheme`を介して現在の配色を使う。`Desktop`はbat側の共通テーマ識別名。

deltaも同じ`Desktop`テーマを使用する。Home Managerの適用時に`git config --global delta.syntax-theme Desktop`を設定する。Gitの名前・メール・認証情報は管理対象に含めない。独立したbat用テーマは同梱しない。配色の変更後はbatのテーマキャッシュを更新するため、deltaのシンタックスハイライトにも反映される。

## Tide Islandとの連携

配色とホーム・ロック壁紙のセットは共通プリセットで管理する。Tide Islandは生成された`tide-colors.json`の配色と静止画のロック壁紙を読み込む。

```bash
jeebis-desktop theme menu
jeebis-desktop theme set kanagawa
jeebis-desktop wallpaper set /path/to/image.png
```

Tideの壁紙ピッカーも共通のwallpaper窓口へ渡す。壁紙だけの変更では配色とロック壁紙を維持する。静止画・動画・GIFの描画はmpvpaperが担当する。別プリセットの選択時はそのホーム壁紙へ置き換える。追加メディアは`~/Pictures/Wallpapers`等に置く。実ファイルや再生履歴はGitへ含めない。詳細は[Tide Island](tide-island.md)を参照。

## ホーム・ロック・ログインのセット

各プリセットの`wallpaper`はホーム、`lockWallpaper`はロックの静止画。省略時はホームと同じ画像。相対パスは`files/desktop/backgrounds/`内、絶対パスと`~/`は外部同期するファイルを参照する。外部画像は適用時点で存在する必要がある。

```json
{
  "name": "kanagawa",
  "palette": "kanagawa",
  "wallpaper": "kanagawa.jpg",
  "lockWallpaper": "tokyonight.jpg"
}
```

`presets.json`を編集し、`just switch`で宣言を反映してから`jeebis-desktop theme set kanagawa`を実行する。ロックの認証処理は既存のPAMを維持する。専用クローン`jeebis.lock`はAstronautに合わせた壁紙・時計・入力欄を使う。shell.jsonは元JSONにクローン有効化を合成した生成ファイルとなり、設定の永続化先はGit側のJSON。

ホームの動画/GIFも指定可能。その場合は`lockWallpaper`に別途静止画を必ず指定する。切替時は静止画を基底に設定した後、ログイン済みシェルへ再生IPCを送る。ログイン前・初期化時のホームは静止画で、動画の実再生には起動済みシェルが必要。`theme refresh`は現在の配色で外観アセットだけを再生成し、ホーム壁紙は変更しない。

共通パレットからGTKの色定義を生成し、NixOSではQt5/Qt6のFusion/qtctパレットも生成する。GTK/libadwaitaやQtアプリ独自の描画は完全一致を保証しない。起動済みアプリは配色反映に再起動が必要な場合がある。OmarchyのQtは既存GTK連携を維持する。

SDDMとロック画面はAstronautの標準の壁紙・フォントを使用する。`lockWallpaper`で生成するアセットはAstronautの標準壁紙を上書きしない。NixOSではJeebis Login（Astronaut素材）とログイン前の自動回転を宣言的に設定する。ユーザーのホームをログイン前に読み込ませず、`/var/lib/jeebis-theme/`へ選択した静止画と色設定を公開する。その画像と設定は他ユーザーからも読めるため、公開したくない画像をロック壁紙に指定しない。自動ログインは設定しない。SDDMを再起動せず、次に表示されるログイン画面から反映する。既存Omarchyへのシステム設定は、ビルド済みJeebis Loginテーマと回転パッケージを引数に`sudo bash scripts/install-astronaut-login.sh <theme-store-path> <rotation-store-path>`で適用する。設定を退避し、SDDMは再起動しない。自動ログイン設定は保持する。

生成物は`~/.local/state/jeebis-theme/current/`。GTK/Qtはこの共通出力を参照する。ホーム壁紙だけの変更はロック・ログイン壁紙を変えず、次にプリセットを選ぶとセットに戻る。

検証: `python3 scripts/check-theme.py`。隔離HOMEとIPCモックを使い、両OSの生成・別壁紙・失敗時の副作用防止・動画/GIF呼出を確認する。画面表示と認証をこのテストで保証するものではない。

ロック用ビューは`files/desktop/lock/JeebisAstronautLockView.qml`。SDDMそのものをロック解除に使わず、既存のセッションロック・パスワード・指紋認証を維持する。壁紙・フォントは[Nixで固定したAstronautテーマ](https://github.com/Keyitdev/sddm-astronaut-theme)を参照し、元パッケージのライセンスとクレジットを保持する。

## ログイン画面の統一

SDDMは`nix build .#jeebis-login-theme`で構築するJeebis Loginテーマを使う。`files/desktop/login/Main.qml`の時計・日付・中央ぼかし・入力欄・ボタンの位置と寸法は`JeebisAstronautLockView.qml`に合わせる。壁紙とOpen Sansはロックと同じappPkgsのAstronautを参照する。上流のライセンスとクレジットはパッケージ内に保持する。

ログイン専用のユーザー選択・セッション選択・電源操作・画面キーボードは維持し、認証はSDDMの既存PAMへ委譲する。テーマ単体では指紋認証を有効にしない。ロック側の認証処理も変更しない。

既存Omarchyでは上記インストーラーへ`jeebis-login-theme`のビルド結果を渡す。SDDMの再起動や現在のセッション終了は行わず、次回ログインから反映される。

ログインUI検証: PySide6/Qt VirtualKeyboardのある環境で`python3 scripts/check-login-theme.py <theme-store-path>/share/sddm/themes/jeebis-login-theme`。ソフトウェア描画とモックSDDMで送信・失敗後の再入力と縦横描画を検証する。GPUのぼかしと実際の画面回転は別途実機確認が必要。実際のPAM認証は次回ログインで確認する。

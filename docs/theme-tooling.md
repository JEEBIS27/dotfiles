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

## Ruixenからの操作

Ruixenのテーマ一覧も共通プリセットを表示する。選択は`jeebis-desktop theme set`へ渡し、配色と対応する壁紙をまとめて適用する。上流の独立したテーマ一覧とは混在させない。

```bash
jeebis-desktop theme catalog       # Ruixen向け一覧（内部形式）
jeebis-desktop wallpaper set /path/to/image.png
```

壁紙だけの変更では配色を維持する。動画・GIFはRuixenが再生し、静止画ポスターの設定を共通のwallpaper窓口へ渡す。別プリセットの選択時は動画・GIFを停止する。追加メディアは`~/Pictures/ruixen-wallpapers`に置く。実ファイルや再生履歴はGitへ含めない。

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

`presets.json`を編集し、`just switch`で宣言を反映してから`jeebis-desktop theme set kanagawa`を実行する。ロックの認証処理は既存のPAMを維持し、専用クローン`jeebis.lock`で背景だけを独立させる。shell.jsonは元JSONにクローン有効化を合成した生成ファイルとなり、設定の永続化先はGit側のJSON。

ホームの動画/GIFも指定可能。その場合は`lockWallpaper`に別途静止画を必ず指定する。切替時は静止画を基底に設定した後、ログイン済みシェルへ再生IPCを送る。ログイン前・初期化時のホームは静止画で、動画の実再生には起動済みシェルが必要。`theme refresh`は現在の配色で外観アセットだけを再生成し、ホーム壁紙は変更しない。

共通パレットからGTKの色定義を生成し、NixOSではQt5/Qt6のFusion/qtctパレットも生成する。GTK/libadwaitaやQtアプリ独自の描画は完全一致を保証しない。起動済みアプリは配色反映に再起動が必要な場合がある。OmarchyのQtは既存GTK連携を維持する。

NixOSのSDDM Astronautは同じ配色とロック壁紙を使用する。ユーザーのホームをログイン前に読み込ませず、`/var/lib/jeebis-theme/`へ選択した静止画と色設定を公開する。その画像と設定は他ユーザーからも読めるため、公開したくない画像をロック壁紙に指定しない。自動ログインは設定しない。SDDMを再起動せず、次に表示されるログイン画面から反映する。OmarchyのシステムSDDMは変更しない。

生成物は`~/.local/state/jeebis-theme/current/`。GTK/Qtはこの共通出力を参照する。ホーム壁紙だけの変更はロック・ログイン壁紙を変えず、次にプリセットを選ぶとセットに戻る。

検証: `python3 scripts/check-theme.py`。隔離HOMEとIPCモックを使い、両OSの生成・別壁紙・失敗時の副作用防止・動画/GIF呼出を確認する。画面表示と認証をこのテストで保証するものではない。

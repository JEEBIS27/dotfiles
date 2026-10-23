# テーマツール

固定の配色と壁紙をセットで切り替える。Aether・Matugenは不要。

## 設定元

`files/desktop/presets.json`の配列順が切替順を決める。

```json
[
  { "name": "tokyonight", "palette": "tokyonight", "wallpaper": "tokyonight.jpg" },
  { "name": "kanagawa", "palette": "kanagawa", "wallpaper": "kanagawa.jpg" },
  { "name": "catppuccin", "palette": "catppuccin", "wallpaper": "catppuccin.png" }
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

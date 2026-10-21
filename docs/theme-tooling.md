# 固定の配色と壁紙をセットで管理する

2026-10-21更新。ユーザーの用途は「Kanagawaとkanagawa-cup.jpg」のような固定セットで十分であり、GUIテーマ編集は不要。

この用途にはMatugenもAetherも必須ではない。Matugenは画像から配色を新規生成したくなった場合の追加候補に留め、既存の配色を壁紙に合わせて自動変更しない。Aether本体の既存インストールは削除しないが、バーと設定の依存から外す。

## 設定元

`files/desktop/presets.json`の配列順が切替順を決める。

```json
[
  { "name": "tokyonight", "palette": "tokyonight", "wallpaper": "tokyonight.jpg" },
  { "name": "kanagawa", "palette": "kanagawa", "wallpaper": "kanagawa-cup.jpg" },
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

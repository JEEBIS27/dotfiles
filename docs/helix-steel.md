# Helix Steel extensions

Helixは`packages/helix-steel/sources.json`に固定したSteel対応forkを使用する。
独自のHelix本体パッチは追加しない。既定エディターの定義は引き続き
`modules/editor.nix`の`programs.helix.defaultEditor`だけ。

拡張はNixから読み込み、起動時のForgeインストールや自動更新はしない。
Steelの可変状態は`$XDG_DATA_HOME/jeebis-helix-steel`（未指定時は
`~/.local/share/jeebis-helix-steel`）に分離する。最近使ったファイルもここに記録し、
編集中のリポジトリに`.helix/recent-files.txt`を作らない。

## 導入内容

| 拡張 | 用途 | 操作 |
| --- | --- | --- |
| flash.hx | 画面内ラベルジャンプ | Space u f / Space u F（後方） |
| steel-pty | 埋め込み端末 | Ctrl+T / Space u t |
| helix-config/recentf | 最近使ったファイル | Space u r |
| microscope.hx | 拡張picker（ディレクトリ探索） | Space u p |
| matte.hx | 分割のズームと中央寄せ | Space u z / Space u m |
| notify.hx | 拡張が使う通知基盤 | `:notify メッセージ` / Space u n（通知へ） |
| moka.hx | ステータスライン | 有効。バッファラインはSpace u bで有効、Space u Bで無効 |
| Yazi公式方式の連携 | ファイル選択後に同じHelixで開く | Ctrl+Y / `:yazi` |

Helixから開いたYaziでは、Enterで現在のviewに開き、Ctrl+Enterで左右分割、
Ctrl+Shift+Enterで上下分割して開く。ディレクトリでは中へ移動する。
通常のYazi起動では分割操作を追加しない。

端末の追加・切替・非表示・終了はSpace u T / s / h / q。
端末からエディターへはShift+Tab。端末内のCtrl系は子プロセスのキーとして扱う。
Altは引き続きTUIOSに予約する。既存のSpace m退避メニューは保持。
Ctrl+Y/ Ctrl+TおよびSpace uは、固定したHelixの編集モードで未割当のキーを使う。
picker内などの固定UIには従来の操作が残る。

## 再現範囲

- Flash風ジャンプはNeovim側の全モード・オプションと同一ではない。
- Microscopeはpickerを作るためのAPIと付属のfile explorerを導入する。
  Snacksの全検索元を移植したものではない。
- notify.hxは通知基盤。Helix標準のメッセージをすべて置き換えるものではない。
- MokaはDesktopテーマを使い、透明な背景・平坦な表示を基本にする。
  Inclineやstatuscolumnの完全移植ではない。Nerd Font用glyphは依存として追加する。
- Matteはズーム解除時に分割を再構築する。選択とフォーカスは復元対象だが、
  各viewのジャンプリストとスクロール位置は保持されない。
- steel-ptyは仮想端末のライブラリを内部利用する。旧ターミナルアプリや設定は追加しない。
  Yaziの画像転送をこの埋め込み端末に依存させない。
- Yaziは専用の公開Steelプラグインが確認できなかったため、公式の
  `:insert-output`方式を小さな連携コードで包む。常設サイドバーではない。
  選択ファイルは引数として直接渡し、空白や引用符をシェルコードとして解釈しない。
  chooserの改行区切り仕様上、改行を含むファイル名は対象外。
  Terminaの入力スレッドとの競合を避けるため、Yazi表示中は呼び出し元Helixだけを
  SIGSTOPし、端末状態を戻してからSIGCONTする。この間HelixのLSP処理も一時停止する。
  通常終了・例外では復帰するが、helperをSIGKILLした場合は`kill -CONT <HelixのPID>`で復旧する。
- Copilot、永続undo、treesj、dial、独自保存時formatterは今回追加しない。

## 検証

ビルドとPTYの検証例（pyteを入れた専用venvを使用）:

```sh
nix build .#helix-steel .#helix-steel-plugins .#helix-steel-terminal
python scripts/check-helix-steel.py \
  --helix "$(nix path-info .#helix-steel)/bin/hx" \
  --plugins "$(nix path-info .#helix-steel-plugins)" \
  --native "$(nix path-info .#helix-steel-terminal)"
```

2026-10-26の検証: Helix本体・全grammar・native端末ライブラリ、Omarchy/NixOS両方の
Home Manager世代のビルド、`nix flake check --no-build`、Python/Lua/TOML/JSON構文が成功。
隔離PTYで7拡張の起動、端末コマンド、ズーム、Yaziのキャンセル・特殊文字パス・
未保存buffer保持・左右/上下分割後のフォーカスを確認した。既存の共通キーは
直接起動と専用TUIOS daemon経由で検証した。
実際のRio画面でのIME・画像・テーマ切替は未確認。手元では次を確認する。

1. `hx --version`、日本語入力、Ctrl+S、Ctrl+Shift+S、Space mの退避操作。
2. 7つの拡張の起動・Escで戻る操作。Ctrl+Tの端末でコマンド実行とShift+Tab。
3. Ctrl+Yで選択・複数選択・キャンセル。未保存bufferが変更されないこと。
4. 空白・引用符・日本語を含むファイル名が正しく開くこと。
5. Rio/TUIOS経由のYazi画像プレビュー、終了後の描画・マウス・ペースト。
6. テーマ変更後のカーソルとステータスライン。
7. 分割中のズームと復帰。復帰時のスクロール位置の制限を確認する。

## 更新・復旧

更新はソースのrev/hashと、端末拡張のSteel依存・Cargo.lockを同時に変更して検証する。
端末拡張のSteelはHelixのCargo.lockと同じリビジョン・feature集合に固定する。
Nixpkgs/flake.lock全体を更新する必要はない。

戻す場合は変更前のHome Manager世代に戻すか、この変更のGitコミットをrevertして
ビルド・適用する。既存のHelixプロセスは終了させず、bufferを保存してから必要に応じて
開き直す。Neovimは従来どおり`nvim`/`nv`で使用できる。

参考: [Steelの導入](https://github.com/mattwparas/helix/blob/steel-event-system/STEEL.md)、
[Yazi公式連携](https://yazi-rs.github.io/docs/tips/#file-tree-picker-in-helix)。

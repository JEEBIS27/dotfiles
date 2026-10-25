# Helixを既定エディターにする

`modules/editor.nix`の`programs.helix.defaultEditor = true`を唯一の既定定義にする。Home Managerが`EDITOR=hx` / `VISUAL=hx`を設定し、Zshの生成設定・Hyprlandの起動環境・Omarchyの標準`defaults/editor`・desktopコマンドも同じ値を参照する。YaziとTUIOSの設定エディターは標準環境変数を利用する。既存プロセスの環境変数は変わらないため、新しいRioから確認する。

公式Helix 25.07.1を使用する。Neovimの設定・パッケージ・`nv`別名は代替として残す。独自Helix forkや未実装のプラグインAPIは使用しない。

## Helix標準を優先する構成

文字キーの編集モデルと見た目はHelix標準を優先する。相対行番号、scrolloff、カーソル形状、補完タイミング、ヒント表示、全言語への2スペース強制、末尾空白の一律削除、clipboardレジスターの上書きを外し、Helixの既定値とプロジェクト設定を使う。DesktopテーマとTrue Colorは共通デスクトップとの連携として残す。

AltはTUIOS、Ctrlはアプリという統一ルールを維持する。標準コマンドへ共通キーを割り当て、代替キーのない固有機能は退避する。Ctrl+S保存の元機能はCtrl+Shift+S、Altの編集・選択機能はnormal/selectのSpace→mメニューへ。Backspace/Enter/PageUp/PageDownなどで代替できる操作はそちらを使う。

[共通キー、退避先一覧、固定UIの制限、再検証手順](editor-keybindings.md)を参照。署名・hoverの候補切替とpickerの背後オープンは、本体パッチを避けるユーザー判断により未対応として記録する。

言語ごとのサーバー定義・インデント・整形はHelix 25.07.1の組み込み`languages.toml`を継承する。JS/TS/JSX/TSXは`typescript-language-server`、Goは`gopls`、Luaは`lua-language-server`、Pythonは`ty`と`ruff`、Nixは`nil`をNixで導入する。組み込み一覧の代替サーバーをすべて導入する必要はなく、`hx --health`で未導入の候補に×が出る場合がある。

Biome・ESLint・Tailwindの一律同時起動、Pyright固定、Lua hintの細かな上書き、goimports・Stylua・shfmtの独自引数・GraphQL用prettierdなどの外部formatter強制を削除する。整形は利用可能なLSPの機能とHelixの既定auto-formatに従う。以前の保存時整形と同じ出力・タイミングを保証しない。必要になった場合はそのプロジェクトの`.helix/languages.toml`で追加する。

例外はVueの検証済み連携と、nilが整形を提供するための`nixfmt`コマンド指定だけ。Neovim設定・本体は残すが、Helixの依存関係をNeovimのために増やさない。代替Neovimの全LSPまで同等動作することは保証しない。

Desktopテーマは共有パレットから生成し、テーマ切替時はSIGUSR1で再読込して編集bufferを保持する。

## Vueの代替LSP

`vtsls`に`@vue/typescript-plugin`を読み込ませ、`.vue`を標準LSPで扱う。プラグインの場所はロック済みnixpkgsの`vue-language-server`パッケージからNix storeの絶対パスを生成する。`/etc`への手動コピー、npmのグローバル導入、旧サーバーへのダウングレードは不要。workspaceのTypeScriptも許可する。

公式Helixリポジトリの[設定例](https://github.com/helix-editor/helix/discussions/15714)と[vtslsの設定schema](https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json)を確認した。

ロック済みvtsls 0.3.0 / Vue plugin 3.3.12、テスト用Vue 3.5.22 / TypeScript 5.9.3で、SFCの`script setup lang="ts"`内の型不一致（診断2322）と`message.`の文字列補完（`toUpperCase`含む）を実際のJSON-RPC応答で確認した。これはVueのHTML/CSS補完、template内の全機能、Neovimとの完全同等性を保証しない。実際のプロジェクトで追加確認する。

再検証用の専用一時ディレクトリを用意する（スクリプトは中のApp.vueとtsconfig.jsonを書き換える）。

```sh
mkdir -p /tmp/helix-vue-check
npm install --prefix /tmp/helix-vue-check --ignore-scripts --no-audit --no-fund vue@3.5.22 typescript@5.9.3
python scripts/check-helix-vue.py /tmp/helix-vue-check --languages ~/.config/helix/languages.toml
hx --health vue
```

## 引き継がないもの・制限

Copilotのインライン提案は追加せず、AI操作にはTUIOSのCodexを使う。NeovimのFlash・Snacks・Toggleterm・Yazi埋込・Noice・statuscolumn等のプラグインUIは移植しない。YaziはAlt+Y、スクラッチ端末はAlt+Tを利用する。Helix内の端末やtabpage、Neovim固有の任意リサイズ・可逆ズームをダミー実装しない。分割交換は標準コマンドで対応する。

Neovimの保存時独自RPC（ESLint全修正など）、複数formatterの失敗時fallback、永続undo等は同等移植しない。コードアクションはSpace+aで手動選択する。GitHub Actions専用LSPは従来もパッケージ未導入で、今回も導入していない。フォーマッターやLSPは全言語の実プロジェクトで動作確認済みではない。

## 検証と実機確認

確認済み: Omarchy/NixOS両方のHome Managerビルド、flake check --no-build、Zsh/Bash/Lua/Python構文、Helixの実PTY起動・入力・Ctrl+S保存、標準typescript-language-serverの診断2322/文字列補完、Vue診断/補完、端末移行の既存check-terminal.py。共通キーと退避機能はcheck-helix-keys.pyの専用PTYでも確認する。実機操作は別途確認する。

- 新しいRioで`printf '%s / %s\n' "$EDITOR" "$VISUAL"`が`hx / hx`になる。
- Omarchyのエディター起動、Yaziの編集、TUIOS歯車の設定編集がHelixになる。
- 日本語入力・保存・クリップボード、Ctrl+Enter / Ctrl+H/J/K/L / Ctrl+Shift+S / Space→mの操作、TUIOS Alt系キーの衝突を確認する。
- Vueプロジェクトで型エラー表示、補完、定義ジャンプ、整形を確認する。
- テーマ変更でHelixの色も変わり、bufferが保持されることを確認する。
- アプリ一覧にはRioだけが表示される。既定端末はパッケージの`rio.desktop`を使い、独自のRio + TUIOSエントリーは作らない。

ロールバックは適用前のHome Manager世代の`activate`を使う。Neovimは`nvim` / `nv`で直ちに使用可能。リポジトリの変更はGit履歴から戻す。既存Rio/TUIOSセッションを終了したり、Git管理外の編集データを削除したりする必要はない。

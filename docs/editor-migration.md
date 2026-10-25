# Helixを既定エディターにする

`modules/editor.nix`の`programs.helix.defaultEditor = true`を唯一の既定定義にする。Home Managerが`EDITOR=hx` / `VISUAL=hx`を設定し、Zshの生成設定・Hyprlandの起動環境・Omarchyの標準`defaults/editor`・desktopコマンドも同じ値を参照する。YaziとTUIOSの設定エディターは標準環境変数を利用する。既存プロセスの環境変数は変わらないため、新しいRioから確認する。

公式Helix 25.07.1を使用する。Neovimの設定・パッケージ・`nv`別名は代替として残す。独自Helix forkや未実装のプラグインAPIは使用しない。

## 引き継ぐもの

- 相対行番号、scrolloff 8、smart case、True Color、折り返しなし、カーソル行、保存時の末尾空白削除、LSP整形、ヒント表示。
- システムクリップボード（Waylandのwl-clipboardを使用）。端末・リモート接続でのOSC 52往復は実機未確認。
- 共通キー: Ctrl+S保存、Ctrl+Shift+S強制保存、Ctrl+N新規buffer（normal）、Ctrl+H/J/K/L・矢印で分割移動、Ctrl+Enter縦分割、Ctrl+Shift+Enter横分割、Ctrl+PageUp/Downでbuffer移動（normal）。
- その他の文字キー・選択操作・Ctrl+Wメニュー・Space+fファイル検索・Space+/全文検索・Space+aコードアクションはHelix標準。
- Go、Lua、シェル、Nix、Python、JSON/JSONC、YAML、Jsonnet、Prisma、Protocol Buffers、Dockerfile、GraphQL、JS/TS/JSX/TSX用の標準LSP。言語ツールを両OSでNix管理し、Neovim/Masonの私有PATHに依存しない。
- Goのgoimports、LuaのStylua、shfmt -i 2、nixfmt、JS/TS/JSONのBiome、Vue/GraphQLのprettierdによる保存時整形。プロジェクトの設定・依存関係も必要。
- Desktopテーマを共有パレットから生成する。テーマ切替時はSIGUSR1で再読込し、編集bufferを保持する。

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

Copilotのインライン提案は追加せず、AI操作にはTUIOSのCodexを使う。NeovimのFlash・Snacks・Toggleterm・Yazi埋込・Noice・statuscolumn等のプラグインUIは移植しない。YaziはAlt+Y、スクラッチ端末はAlt+Tを利用する。Helix内の端末やtabpage、Neovim固有の分割リサイズ・入替キーをダミー実装しない。

Neovimの保存時独自RPC（ESLint全修正など）、複数formatterの失敗時fallback、永続undo等は同等移植しない。コードアクションはSpace+aで手動選択する。GitHub Actions専用LSPは従来もパッケージ未導入で、今回も導入していない。フォーマッターやLSPは全言語の実プロジェクトで動作確認済みではない。

## 検証と実機確認

確認済み: Omarchy/NixOS両方のHome Managerビルド、flake check --no-build、Zsh/Bash/Lua/Python構文、Helixの実PTY起動・入力・Ctrl+S保存、Vue診断/補完、端末移行の既存check-terminal.py。分割キー入力はPTYに送信したが、実際の画面・フォーカス操作は実機で確認する。

- 新しいRioで`printf '%s / %s\n' "$EDITOR" "$VISUAL"`が`hx / hx`になる。
- Omarchyのエディター起動、Yaziの編集、TUIOS歯車の設定編集がHelixになる。
- 日本語入力・保存・クリップボード、Ctrl+Enter / Ctrl+Shift+Enter、Ctrl+H/J/K/L、TUIOS Alt系キーの衝突を確認する。
- Vueプロジェクトで型エラー表示、補完、定義ジャンプ、整形を確認する。
- テーマ変更でHelixの色も変わり、bufferが保持されることを確認する。
- アプリ一覧にはRioだけが表示される。`jeebis-terminal.desktop`は端末起動用IDとして残し、NoDisplayで隠す。

ロールバックは適用前のHome Manager世代の`activate`を使う。Neovimは`nvim` / `nv`で直ちに使用可能。リポジトリの変更はGit履歴から戻す。既存Rio/TUIOSセッションを終了したり、Git管理外の編集データを削除したりする必要はない。

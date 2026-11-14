# 入力メソッドの接続経路

GTK3/GTK4アプリはGTK_IM_MODULE=fcitx、QtアプリはQT_IM_MODULE=fcitx
（Qt6の優先リストQT_IM_MODULESもfcitx）を使う。X11アプリ用にはXMODIFIERS=@im=fcitxを設定する。
Niriの起動環境にも同じ値を指定する。画面出力はWaylandのまま維持する。

ChatGPT・Helium・Slack・Obsidian・Spotifyは起動ラッパーで--gtk-version=4と
--ozone-platform=waylandを指定する。Nixpkgsの内部ラッパーが直接入力のフラグを
再追加しないよう、これらのアプリに限りNIXOS_OZONE_WLを解除する。
GTK4実行ライブラリも用意する。通常のランチャーとNiriのアプリカタログは同じパッケージを使う。
追加の起動引数やアプリ内設定で入力経路を上書きした場合は別途確認が必要。

NixOSではMejiroIMEのGTK配色拡張を有効化し、固定版を2047fb9へ更新した（表示だけを待機するライブ変換Delayと設定GUIのコマ送りプレビューを含む）。
Fcitxを独自パッケージで強制指定しているため、そちらにも拡張GTKを明示的に組み込む。
GTK4モジュールの探索先はGIO_EXTRA_MODULESで指定する。
配色はMejiroIMEの設定で「プレビュー連動」または「個別設定」を選択する。
既定の「アプリ標準」では独自色を反映しない。

GTK経由への切替と、アプリが任意の配色属性を描画することは別である。
Chromium/Electron/CEFの各アプリで任意色が描画されることは未確認。
Qt・Flutter等のアプリや独自の入力実装をGTKへ強制変換する設定ではない。
TUIは実行している端末の入力経路を使う。

設定の反映にはNixOSの再ビルドが必要。Home Managerだけの切替ではシステム側の
Fcitx・MejiroIMEを更新しない。適用後はログインし直し、各アプリを完全終了して再起動する。

参考: https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en

## 検証

ChatGPT・Helium・Slack・Obsidian・Spotify、拡張GTK、拡張を組み込んだFcitxのビルドが成功。
Home ManagerのactivationPackage全体もビルド成功。NixOS desktop-vm構成の失敗assertionは0件。
生成したNiri設定をniri validateで検証した。
既存の共通テンプレートと機種別設定にあったinputの重複は、機種別設定側へ統合し、
キーボード、タップ、自然スクロール、マウス加速の設定を保持した。
常用環境への適用、各アプリの実入力・候補位置・配色描画の試験はまだ行っていない。

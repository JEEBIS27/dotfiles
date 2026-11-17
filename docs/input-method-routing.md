# 入力メソッドの接続経路

WaylandネイティブのGTK3/GTK4アプリは、組み込みWayland IMから
text-input-v3を使う。そのためGTK_IM_MODULEはセッション環境で指定しない。
GTK3/GTK4の設定ファイルには、XWayland利用時の互換用としてfcitxを設定する。
QtアプリはQT_IM_MODULE=fcitx（Qt6の優先リストQT_IM_MODULESもfcitx）、
X11アプリはXMODIFIERS=@im=fcitxを使う。

ChatGPT・Helium・Slack・Obsidian・Spotifyは起動ラッパーで
--ozone-platform=wayland、--enable-wayland-ime、--wayland-text-input-version=3を指定し、
GTK4 IMモジュールを経由せずNiriのtext-input-v3に接続する。
Nixpkgs内部ラッパーとの重複を避けるため、これらのアプリに限り
NIXOS_OZONE_WLを解除する。通常のランチャーとNiriのアプリカタログは同じパッケージを使う。
追加の起動引数やアプリ内設定で入力経路を上書きした場合は別途確認が必要。

NixOSではMejiroIMEのGTK配色拡張を有効化し、固定版を2047fb9へ更新した（表示だけを待機するライブ変換Delayと設定GUIのコマ送りプレビューを含む）。
Fcitxを独自パッケージで強制指定しているため、そちらにも拡張GTKを明示的に組み込む。
GTKモジュールはFcitxパッケージに含め、GTK_PATHによるGTKのバージョン別探索を使う。
システムとアプリは同じnixpkgsの固定リビジョンを参照し、GTK入力モジュールとGTK3キャッシュ生成時のGLibを揃える。
GTK4専用モジュールをGIO_EXTRA_MODULESに全体設定すると、GTK3のMejiroIME設定にも
GTK4が読み込まれて起動できなくなるため、ここには追加しない。
配色はMejiroIMEの設定で「プレビュー連動」または「個別設定」を選択する。
既定の「アプリ標準」では独自色を反映しない。

Wayland text-input経由と、アプリがMejiroIMEの任意の配色属性を描画することは別である。
Chromium/Electron/CEFの各アプリで任意色が描画されることは未確認。
TUIは実行している端末の入力経路を使う。

設定の反映にはNixOSの再ビルドが必要。Home Managerだけの切替ではシステム側の
Fcitx・MejiroIMEを更新しない。適用後はログインし直し、各アプリを完全終了して再起動する。

参考: https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en

## 検証

ChatGPT・Helium・Spotifyの個別ビルド、Slack・Obsidianを含むHome Managerの
activationPackage全体、NixOS desktop-vm構成のビルドが成功。生成ラッパーから
--gtk-version=4が消え、--enable-wayland-imeと--wayland-text-input-version=3が入ったことを確認した。
Home Manager構成は常用環境へ適用済み。NixOS構成はビルド済みだが、非対話実行で
sudo認証できないためシステムプロファイルの切り替えは未実施。
各アプリの実入力・候補位置・配色描画は、ログインし直しと完全再起動後に確認する。

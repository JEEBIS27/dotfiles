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

NixOSでは標準のFcitx5と公開版Mejiro IMEのアドオンを使う。
旧版のGTKインライン配色拡張は使わない。候補ウィンドウのテーマと、
アプリ側のプリエディット表示は別で、後者は入力経路とアプリの対応に依存する。
GTK入力モジュールとFcitx5は同じnixpkgsの固定リビジョンを参照する。
TUIは実行している端末の入力経路を使う。

設定の反映にはNixOSの再ビルドが必要。Home Managerだけの切替ではシステム側の
Fcitx・Mejiro IMEを更新しない。適用後はログインし直し、各アプリを完全終了して再起動する。

参考: https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en

## 過去の入力経路の検証（公開版への更新前）

ChatGPT・Helium・Spotifyの個別ビルド、Slack・Obsidianを含むHome Managerの
activationPackage全体、NixOS desktop-vm構成のビルドが成功。生成ラッパーから
--gtk-version=4が消え、--enable-wayland-imeと--wayland-text-input-version=3が入ったことを確認した。
Home Manager構成は常用環境へ適用済み。NixOS構成はビルド済みだが、非対話実行で
sudo認証できないためシステムプロファイルの切り替えは未実施。
各アプリの実入力・候補位置・配色描画は、ログインし直しと完全再起動後に確認する。

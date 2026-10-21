# Mozkey・Fcitxとrclone

## 共通設定

`modules/input-method-files.nix`はFcitxのconfig、profile、keyboard.conf、mozkey-ibg.confとMozkeyのconfig1.dbを、リポジトリ内の書き込み可能な個人設定へリンクする。Fcitxの入力方式はMozkey、切替キーは既存のControl+Spaceを維持する。config1.dbは上流config.protoで認証項目を持たない設定形式として確認した。学習履歴、ユーザー辞書、暗号鍵、IPC・ロックファイルは同期対象に含めない。

## MozkeyのNixパッケージ

`packages/mozkey-fcitx5.nix`は使用中と同じMozkey IbG 0.10.4の公式配布物をSHA-256で固定し、NixのFHS環境内だけに/usr/lib/mozkey-ibgを用意する。ホストの/usrへファイルを追加しない。モデルも配布物に含まれる固定版を使う。llama-server、Fcitx5、GTK/Qtの依存は固定済みのnixpkgs-apps系列に揃える。

```sh
nix build .#mozkey-fcitx5
./result/bin/mozkey-fcitx5 --check-runtime
./result/bin/mozkey-fcitx5 --check-model
```

アドオンの動的読み込み、サーバー・モデル・メタデータの配置、Fcitx5とllama-serverの起動経路、CPUでのモデル読み込み・プロンプト処理を一時HOMEで検証した。専用HOME・専用D-Bus・画面なしのFcitx起動でもアドオン読込みを検証する。上流の通常ファイル検証に合わせ、隔離ルート内のサーバー・scorer・モデルはリンクではなく実体配置する。2026-10-21にNixOS VMを起動し、専用Wayland環境のGTK 3・Qt 6で「nihongo → 日本語」の変換・確定に成功した。scorerのZNZ1要求、認証付き/completionの非空応答、ループバック限定待ち受けもVM内で確認した。個人設定のHyprland/UWSMセッションでもGTK/Qtの日本語確定とCtrl+Space切替に成功。設定GUIの表示と通常再ログイン後の入力も成功。IME経由のZenz補正全体は未確認。X11用Qt Fcitxプラグイン経由には未解決の問題がある。起動・ポータル・IPCのタイムアウトは検証方法の問題を切り分け、KVMの新規VMで再確認した。Quickshellの通知修正後は、PAM認証、ロック・解除・再ロック、通常再ログインも成功。実機と全アプリの受け入れ確認は残る。詳細は[Mozkey検証記録](mozkey-verification.md)。

Omarchyは既存のFcitx/Mozkeyプロセスを使い続ける。NixOSはOS側でGTK/Qtフロントエンドを宣言し、Home Managerのfcitx5.serviceから隔離ランタイムを起動する。UWSMのwayland-session-waitenv.serviceを待ってから起動し、WAYLAND_DISPLAYが存在する状態で接続する。NixOS側のHome Manager統合はuseUserPackagesを有効にし、ログインとユーザーサービスから共通アプリを参照できるようにする。Bubblewrapのユーザー名前空間は検証VMの通常ユーザーで動作した。実機で許可を制限する場合は再確認する。FHS環境では/usr/libを実体にし、上流のサーバー実行パス検査と一致させる。

## rclone

`modules/mounts.nix`でGoogleDriveとOneDriveの2サービスを宣言する。rcloneはNixの実行パス、FUSEのsetuidヘルパーはOmarchyの/usr/bin/fusermount3、NixOSの/run/wrappers/bin/fusermount3へ切り替える。存在しなかった旧/usr/bin/fusermount指定を解消し、起動前の強制アンマウントを行わない。

リモート名、マウント先、--vfs-cache-mode writes、--allow-non-emptyは既存値を維持する。--allow-non-emptyを残すため、マウント下のローカル実体がないことの確認は別途必要。FUSE権限を広げる--allow-otherは追加しない。

認証ファイルは既存の~/.config/rclone/rclone.confを参照し、Gitや/nix/storeへ取り込まない。ファイルがない別PCでは認証を用意するまでサービスを起動しない。トークン更新のため、このファイルを読み取り専用のNixファイルにしない。

Home Managerのサービス反映はsuggest方式。現在マウント中のプロセスは停止・再起動しない。次回のログインまたはサービス再起動から新しい実行定義を使う。稼働中のrcloneの版と、保存されたサービス定義の版は移管直後に異なる場合がある。

認証不要の一時ローカルバックエンドで、Nix rcloneによる読み取り専用マウント、ファイル読み込み、解除まで確認した。クラウドへの書き込み・同期・削除は行っていない。

2026-10-21追試: NixOS VMの通常ユーザーでも、Nix版rcloneと/run/wrappers/bin/fusermount3による一時ローカルフォルダの読み取り専用mount、内容比較、unmountに成功。現在のOmarchyのGoogleDrive・OneDriveは両サービス・両マウントがactive。クラウド内容や認証情報は今回の試験へ取り込んでいない。

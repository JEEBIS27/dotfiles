# MozkeyのNixOS検証（2026-10-21）

正式なNixOS対応ではなく、公式Mozkey IbG 0.10.4のArch配布物をNixのFHS環境で動かす個人用互換パッケージ。ホストの/usrや上流バイナリは変更しない。

## 修正した問題

buildFHSEnvの標準構成は/usr/libを/usr/lib64へのリンクにする。Mozcは埋め込みの/usr/lib/mozkey-ibg/mozc_serverと/proc/<pid>/exeを文字列で比較するため、通常ファイルを配置するだけでは接続できなかった。packages/mozkey-fcitx5.nixで専用ルート内の/usr/libを実体にし、/usr/lib64をそのリンクへ変更した。サーバー・scorer・モデルは通常ファイルのまま、上流の身元検査も有効なままとする。

## 確認できた動作

- NixOS 26.05.20261019.f3a73bc、Linux 6.18.57のVMをビルド・起動。Home Managerサービスも正常終了。
- VMの通常ユーザーと専用labwc Wayland環境でGTK 3とQt 6.12にnihongo、Space、Returnを送り、両方で日本語の確定を確認。
- GTK_IM_MODULE・QT_IM_MODULEを強制指定せず、周辺テキスト通知も無効化しない条件で成功。QtWaylandを使用し、Qt用Fcitxプラグインはロードされていない。
- 同VM内で実Mozkey scorerのZNZ1要求に非空応答。子llama-serverの実行パス・モデル・引数を確認し、認証付きPOST /completionの非空contentとループバック限定待ち受けを確認。
- Bubblewrapによる実行がVMの通常ユーザーで成立。Omarchyホストの既存IMEとHome Manager世代は切り替えていない。

## 残る制限

X11用Qt Fcitxプラグイン経由では、周辺テキストに伴うcapability変更でpreeditが消える症状を確認した。上流のcapability変更時にセッションを破棄する処理との相互作用と判断する。専用テストだけでFCITX_QT_ENABLE_SURROUNDING_TEXT=0を設定すると変換できたが、周辺テキスト機能を維持するため通常設定へは採用しない。上流への報告・修正は未実施で、XWaylandを使う対象Qtアプリの確認が必要。

最初の試験はクリーンな一時プロファイルと専用labwcを使用した。続いて下記の個人Hyprlandセッションも確認した。設定GUI・パスワードによるロック解除・再ログイン・実機、IME経由のZenz補正の採用・品質は追加検証する。今回のscorer試験は上流probeの通信・プロセス検査関数を利用したもので、上流のリリース生成・attestationゲート全体ではない。

## 証跡

このPCの計画フォルダのmozkey-nixos-verification/result.mdとvalidation.json、vm/wayland-vm.log、vm/scorer-vm-result.jsonに実行結果を保存した。テスト用verification.nixは正式flakeを読み込み、VM専用のシリアル自動ログインと2GB・2コアを指定する。実機用のユーザー認証設定は変更しない。VMは試験後にpoweroffした。

上流: [配置仕様](https://github.com/kazormia296/mozkey-ibg/blob/82148140d58c1d1f45df4610051de73f87405b53/docs/linux_product_isolation.md)、[実行パス検査](https://github.com/kazormia296/mozkey-ibg/blob/v0.10.4/src/ipc/ipc_path_manager.cc)、[capability処理](https://github.com/kazormia296/mozkey-ibg/blob/v0.10.4/src/unix/fcitx5/mozc_state.cc)。

## 個人Hyprlandセッションでの追加検証

同日の別VMで、正式flakeのdesktop-vmへ個人Home Manager設定を適用し、UWSM経由でHyprland 0.56.2を起動した。VMだけに合成パスワードと自動ログインを用意し、書き込み可能な設定はゲストのリポジトリへ複製した。履歴・辞書・認証情報は持ち込んでいない。

- Hyprland設定エラーなし、260キーバインドを読込み。Quickshellの個人バーが表示され、shell pingに応答。desktop、fcitx5、sleep-lockの3ユーザーサービスがactive。
- 現在のMozkey個人設定のまま、GTK 3とQt 6のネイティブWayland入力欄で日本語の確定を確認。各アプリで既存のCtrl+SpaceがFcitxの有効状態を切り替えることも確認。
- 個人設定はライブ変換が有効なので、nihongo入力後にSpaceを追加せずReturnで確定する。Zenzライブ補正は元から無効で、その設定は変更しない。候補・変換中の画面も保存した。
- GTK_IM_MODULE・QT_IM_MODULEの強制指定、周辺テキスト通知の無効化は行っていない。

実行して初めて見つかった起動上の問題を修正した。runtime.nixの置換順序を直し、Hyprlandの既定モジュールをNixストアの同梱ランタイムから読ませる。desktop/IMEサービスはUWSMのwayland-session-waitenv.serviceを待つ。NixOS側のHome Manager統合にはuseUserPackagesを指定してログイン・サービスから共通アプリを参照できるようにする。Colorシングルトンの名前変更は単語境界に限定し、statusColor等の個人プロパティを壊さない。OSに依存しないXWayland倍率・更新通知抑止の既定値も維持した。

証跡はこのPCのhyprland-nixos-verification/result.md、runtime/xchg/personal-session/result.jsonと画像、vm.nixに保存する。実機のHome Manager世代、IME、rcloneはこの追加試験でも切り替えていない。通常のパスワード認証とサスペンド復帰は未完了であり、自動ログインの成功で代替しない。

## 初回起動・IPCの再検証は未完了

上記の個人入力成功は追加試験の初回で、証跡はhyprland-nixos-verification/earlier-success.jsonとruntime/xchg/automatic-test.logに保存した。Color置換の修正後に新しいVMディスクで再検証すると、UWSMの起動期限、Hyprland reload、ポータル起動、シェルIPC応答にタイムアウトが出た。TCGの遅さはあるが、原因を描画性能だけと断定しない。

VM限定でsystemdとUWSM内部の待ち時間を延ばし、Hyprlandの設定エラーなし・260バインドの読込みまで再確認した。一方、120秒の応答待ちを追加した入力試験も準備完了条件を満たせず終了した。設定GUI試験は当初lock status確認のタイムアウトで停止。待ち時間を延ばした診断では未ロック状態の応答を取得してFcitxの登録アクションを送れたが、設定画面は確認できなかった。入力欄の表示・フォーカスを待つ試験へ改善した後の再試験は、VMの通常の自動ロックを検出して中断した。GUI自体の故障・成功はいずれも確定していない。ロック表示とlocked/sessionLocked/secureへの状態遷移は確認したが、パスワード認証は未確認。ログは同フォルダのserial-ready.log、runtime/xchg/ready-user-journal.log、personal-session/result.json、settings-action-result.json。

したがって、現時点では個人設定での日本語入力に成功した実績と、起動後IPCを含む再現性の未解決問題が併存する。最終構成の受け入れ試験完了や、実機移行可能の最終判定には扱わない。まず初回起動とシェルIPC・ポータル連携を切り分け、設定GUI・通常認証・再ログインを再確認する。Omarchyの現在の世代は維持する。

## 最終の新規KVM VM・通常再ログインでの成功

追加の検証環境修正後、個人設定のGTK/Qt日本語確定・Ctrl+Space、Fcitx登録アクションによるMozkey IbG SettingsのネイティブWayland表示に成功した。現在のライブ変換ON、Zenzライブ補正OFFは維持。画面を確認し、設定変更せず閉じた。

PAM認証と画面からの通常キー入力による解除にも成功した。その過程で見つかったQuickshell 0.3.2の再ロック不能は、上流の通知修正をNixOS用パッケージへバックポートして解消。2回連続のロック・解除・再ロックで状態もfalseへ戻ることを確認した。通常ログアウト後のgreetd画面からユーザー名・VM用パスワードで再ログインし、入力と設定GUIをもう一度成功させた。

前節の未完了記述は切り分け途中の記録。最新判定はnixos-readiness-check/validation.jsonとresult.mdを参照。失敗ログも残す。正式な上流NixOS対応、X11/XWayland用Qtプラグインの問題解消、実機検証完了を主張するものではない。

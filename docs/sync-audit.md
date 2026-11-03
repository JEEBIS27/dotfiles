# デスクトップ再現範囲の監査

調査日: 2026-11-01。対象はHome Manager/NixOS宣言と現在のOmarchyの外観・ログイン・ロケール・既定アプリ。全アプリや全ホームファイルの網羅監査ではない。

## 宣言に追加したもの

NixOS用にGTK Adwaita-dark、Yaru-magentaアイコン、Adwaitaカーソル24、Adwaita Sans 11、dark preference、NixOSのQt Fusion/qtct配色連携を追加。外観パッケージも導入する。Qtアプリ独自のテーマやGTK4/libadwaitaの描画が完全に同一になる保証はない。

Webの既定はHelium（公式AppImageを固定）、ディレクトリはNautilus。OmarchyのHelium、HEY、Aether等への関連付けはコピーしない。アプリ起動用キーバインドやYaziは従来どおり。

日本語ロケール・Asia/Tokyo・コンソールjp106をOSの既定値として追加。HyprlandはNixOS側でjp/jp106を明示し、Omarchy固有のvconsole情報への依存を補う。別配列のPCではこのHyprland設定も変更する。

GNOME Keyring本体とSDDM/PAMの解除連携、dconf、GVfsを追加。既存キーチェーンの内容は移行しない。解除にはログインパスワードとキーチェーンのパスワードが一致する必要があり、自動ログインでは同じ解除を保証しない。

SDDM + AstronautとHyprland UWSMはNixOSで管理する。Omarchy側のログイン・テーマサービスは変更しない。

## 引き続き同期しないもの・別途作業

| 項目 | 扱い |
|---|---|
| GPU・ディスク・暗号化・ブート・ホスト名・ユーザーパスワード | 移行先のconfiguration.nix等を維持。共通Gitには未収録 |
| モニター配置・倍率 | 初期設定あり。UI変更はローカルのmonitors.luaに保存され、Gitへ自動反映しない |
| Wi-Fi/VPNの秘密、SSH/GPG鍵、rclone認証、アプリ認証・ライセンス | Git対象外。移行先で認証 |
| キーチェーンの保存内容 | Git対象外。仕組みだけ再現 |
| 履歴・キャッシュ・学習履歴・ブラウザプロファイル | Git対象外 |
| Google Drive等の実データ | rclone等で別同期 |
| 個人の動画/GIF壁紙と現在選択中の状態 | Gitの固定壁紙とは別。外部ファイルは別同期が必要 |
| テーマ連動 | GTK・NixOSのQt/SDDM・ロックへ追加。SDDMはロック用静止画を公開領域から読む。OmarchyのシステムSDDMは未変更 |
| 指紋・プリンター・特殊デバイス・VPN接続 | 未追加。対象PCで必要なものを追加 |
| メール・PDF・アプリ固有URLの関連付け | 未追加。NixOSに導入していないアプリへの参照をコピーしない |
| TUIOS local.tomlや書込み可能なプラグインlock等 | ローカル変更がGitへ自動反映されるとは限らない。個別に確認・コミット |
| 外部エディタープラグイン等 | 既存のプラグイン管理方式を維持。初回取得が別途必要な場合あり |

## 確認範囲

NixOSモジュールのassertionsとHome Managerの生成評価で確認する。現在のOmarchyへは適用しない。ログイン、キーチェーン解除、テーマ描画、GPU、音声、スリープは移行先で実動作確認が必要。

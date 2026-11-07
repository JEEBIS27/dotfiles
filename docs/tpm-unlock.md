# TPMによる起動時のディスク自動解除（既存Omarchy）

```sh
sudo bash scripts/setup-tpm-unlock.sh prepare
# 再起動し、一度だけ従来のディスクパスワードで解除する。
sudo bash scripts/setup-tpm-unlock.sh enroll
```

`enroll`は端末で既存のディスク解除パスワードを求める。パスワードをチャット・コマンド引数・設定ファイルへ記録しない。登録後はTPMトークンを検証してからSDDMの自動ログインを無効化する。次の起動から「TPMでディスク解除 → SDDMでログイン」となる。SDDMは再起動しない。

対象は`cryptdevice=UUID=…:name`で起動するLUKS2と、既存の`encrypt`フックを使うArch/Omarchy。NixOSのディスクや起動設定を変更するスクリプトではない。

`jeebis-tpm2`フックが既存の`encrypt`の直前でTPMトークンだけを最大15秒試す。未登録・TPM不調・起動内容の不一致では既存のパスワード入力に戻る。PlymouthやBtrfsの既存フックは維持する。

Secure Bootを変更せず、PCR 0/2/4/7/9/12（ファームウェア、拡張ROM、起動コード・UKI、Secure Boot方針、initrd、追加コマンドライン）に登録を結びつける。カーネル・起動ファイル・ファームウェア等の更新後はパスワードが必要になる場合がある。その場合は正しい更新後の環境で`enroll`を再実行する。再登録時に置き換えるのはTPM用スロットだけで、パスワード用スロットは残す。

準備時のLUKSヘッダーと`/boot`はroot専用の`/var/lib/jeebis-tpm-unlock/backup/`に退避する。このディレクトリは秘密情報として扱い、Gitや公開ファイルへ追加しない。準備時のイメージ生成に失敗した場合は、追加フックを削除し退避した起動ファイルを復元する。

準備したフックを実際に実行した起動でなければ`enroll`は拒否する。復旧用イメージを使って起動した場合は、通常の準備済みイメージへ戻ってから登録する。

検証:

```sh
bash scripts/check-tpm-unlock.sh
sudo bash scripts/setup-tpm-unlock.sh status
```

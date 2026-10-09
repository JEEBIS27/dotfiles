#!/bin/bash
set -euo pipefail

echo "=== 5. Changing Default Shell to Zsh ==="

# zsh のパスを取得
ZSH_PATH=$(which zsh || true)

if [ -z "$ZSH_PATH" ]; then
    echo "zsh is not installed. Skipping shell change."
    exit 0
fi

# 現在のデフォルトシェルが zsh でない場合のみ変更処理を実行
if [ "$SHELL" != "$ZSH_PATH" ]; then
    # /etc/shells に zsh が登録されていない場合は追記
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi

    # デフォルトシェルを変更
    echo "Changing shell to $ZSH_PATH for user $USER..."
    sudo chsh -s "$ZSH_PATH" "$USER"
    echo "Shell changed successfully. (Changes will take effect on next login)"
else
    echo "Default shell is already zsh."
fi

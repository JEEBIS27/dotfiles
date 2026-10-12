#!/bin/bash

echo "Setting up system locale to ja_JP.UTF-8..."
# /etc/locale.gen の ja_JP.UTF-8 のコメントアウトを解除（管理者権限が必要）
sudo sed -i '/^#\s*ja_JP.UTF-8 UTF-8/s/^#\s*//' /etc/locale.gen

# ロケールを生成
sudo locale-gen

# システム全体のデフォルト言語を日本語に設定
sudo localectl set-locale LANG=ja_JP.UTF-8

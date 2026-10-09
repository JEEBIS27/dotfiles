#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local"
mkdir -p "$INSTALL_DIR"

echo "=== 4. Installing Neovim (Latest tar.gz) ==="

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    NVIM_TAR="nvim-linux-x86_64.tar.gz"
elif [ "$ARCH" = "aarch64" ]; then
    NVIM_TAR="nvim-linux-arm64.tar.gz"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

DOWNLOAD_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest \
  | grep "browser_download_url.*$NVIM_TAR" \
  | cut -d : -f 2,3 \
  | tr -d \" | tr -d ' ')

curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$NVIM_TAR"

tar -C "$TMP_DIR" -xzf "$TMP_DIR/$NVIM_TAR"
cp -r $TMP_DIR/nvim-linux*/* "$INSTALL_DIR/"

echo "Neovim installed successfully to $INSTALL_DIR/bin/nvim"

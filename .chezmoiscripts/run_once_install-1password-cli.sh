#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

if command -v op &> /dev/null; then
    echo "1Password CLI is already installed."
    exit 0
fi

echo "=== Installing 1Password CLI (op) ==="
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    OP_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    OP_ARCH="arm64"
else
    echo "Unsupported architecture for 1Password CLI: $ARCH"
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# 公式サイトから最新の安定版アーカイブを取得して展開
curl -sS https://cache.agilebits.com/dist/1P/op2/pkg/v2.30.0/op_linux_${OP_ARCH}_v2.30.0.zip -o "$TMP_DIR/op.zip"
unzip -q "$TMP_DIR/op.zip" -d "$TMP_DIR"
install -m 755 "$TMP_DIR/op" "$INSTALL_DIR/op"

echo "1Password CLI installed successfully to $INSTALL_DIR/op"

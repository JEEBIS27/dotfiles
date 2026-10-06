#!/bin/bash
if command -v brew &> /dev/null; then
    echo "=== Installing Homebrew packages ==="
    brew bundle --global
fi

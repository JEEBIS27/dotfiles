#!/bin/bash
set -euo pipefail

if command -v rustup-init &> /dev/null; then
    echo "=== Initializing Rust toolchain (rustc / cargo) ==="
    sudo pacman -S rustup
    rustup default stable
fi

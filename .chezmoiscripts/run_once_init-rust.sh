#!/bin/bash
set -euo pipefail

if command -v rustup-init &> /dev/null; then
    echo "=== Initializing Rust toolchain (rustc / cargo) ==="
    rustup-init -y --no-modify-path || true
fi

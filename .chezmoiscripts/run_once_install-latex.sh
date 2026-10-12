#!/bin/bash
set -euo pipefail

if command -v latex &> /dev/null; then
    echo "=== Installing Latex Packages ==="
    sudo pacman -S texlive-bin texlive-basic texlive-latex texlive-latexrecommended texlive-binextra texlive-langjapanese texlive-science
fi


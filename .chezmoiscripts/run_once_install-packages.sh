#!/bin/bash
set -euo pipefail

echo "=== 1. Checking and Installing Base Tools (wget, curl, git) ==="
if command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y wget curl git build-essential
elif command -v dnf &> /dev/null; then
    sudo dnf install -y wget curl git groupinstall "Development Tools"
elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm --needed wget curl git base-devel
fi

echo "=== 2. Checking and Installing Homebrew ==="
if ! command -v brew &> /dev/null && [ ! -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    echo "Homebrew not found. Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

echo "=== 3. Installing Brewfile Packages ==="
if command -v brew &> /dev/null; then
    if [ -f "$HOME/.Brewfile" ]; then
        # エラーがあってもスクリプトを中断させない処理
        brew bundle --global || true
    fi
fi

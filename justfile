# Run from this checkout or any of its subdirectories.
set shell := ["bash", "-euc"]

# Show available commands.
default:
    @"{{just_executable()}}" --list

# Install/apply the configuration for this OS.
switch:
    @bash scripts/manage.sh switch

# Build without activating (NixOS first run also prepares /etc/nixos).
build:
    @bash scripts/manage.sh build

# Pull configuration changes, then apply them. Keep package pins unchanged.
sync:
    @bash scripts/manage.sh sync

# Refresh CLI and application packages from unstable, then apply.
update-apps:
    nix --extra-experimental-features 'nix-command flakes' flake update nixpkgs-apps
    @bash scripts/manage.sh switch

# Authenticate GitHub CLI and configure Git to use it for HTTPS.
git-auth:
    gh auth login --hostname github.com --git-protocol https --web
    gh auth setup-git

# Show the detected OS without building or activating anything.
host:
    @bash scripts/manage.sh host

# NixOS only: back up /etc/nixos, create the integration flake and build.
setup:
    @bash scripts/manage.sh setup

# Installer routing tests; never activate the host.
test:
    python3 scripts/check-manage.py

# Check installer shell syntax without modifying files.
lint:
    bash -n scripts/manage.sh

# Focused installer checks (not every desktop component).
check: lint test

# NixOS only: prepare local signing keys and an opt-in boot module; no activation.
prepare-tpm:
    @bash scripts/tpm.sh prepare

# NixOS only: register TPM after signed boot + Secure Boot have been verified.
enroll-tpm:
    @bash scripts/tpm.sh enroll

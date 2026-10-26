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

# Show the detected OS without building or activating anything.
host:
    @bash scripts/manage.sh host

# NixOS only: back up /etc/nixos, create the integration flake and build.
setup:
    @bash scripts/manage.sh setup

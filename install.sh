#!/usr/bin/env bash

# Install the sitlctl launcher and its runtime bundle.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITL_IMAGE="${SITL_IMAGE:-vanfleetdev/sitl-ardupilot:4.6.3}"

log_info() {
    printf "%b[INFO]%b %s\n" "$GREEN" "$NC" "$1"
}

log_warn() {
    printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
}

log_error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2
}

log_step() {
    printf "%b[STEP]%b %s\n" "$BLUE" "$NC" "$1"
}

check_docker() {
    log_step "Checking Docker..."
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed."
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not reachable. Start Docker or Colima, then retry."
        exit 1
    fi
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose is not installed."
        exit 1
    fi
    log_info "Docker is ready."
}

check_bin_directory() {
    log_step "Checking ~/bin..."
    mkdir -p "$HOME/bin"
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        log_warn "$HOME/bin is not in PATH. Add: export PATH=\"\$HOME/bin:\$PATH\""
    fi
}

install_runtime() {
    log_step "Installing sitlctl..."
    local source_file="$SCRIPT_DIR/sitlctl"
    local target_file="$HOME/bin/sitlctl"
    local temporary_file="$HOME/bin/.sitlctl.$$"

    if [ ! -f "$source_file" ]; then
        log_error "Launcher not found: $source_file"
        exit 1
    fi

    trap 'rm -f "$temporary_file"' RETURN
    cp "$source_file" "$temporary_file"
    chmod 755 "$temporary_file"
    rm -f "$target_file"
    mv "$temporary_file" "$target_file"
    trap - RETURN

    cp "$SCRIPT_DIR/docker-compose.yml" "$HOME/bin/docker-compose.yml"
    cp "$SCRIPT_DIR/docker-entrypoint.sh" "$HOME/bin/docker-entrypoint.sh"
    cp "$SCRIPT_DIR/locations.txt" "$HOME/bin/locations.txt"
    chmod 755 "$HOME/bin/docker-entrypoint.sh"
    log_info "Runtime bundle installed under ~/bin."
}

ensure_image() {
    log_step "Checking ArduPilot image..."
    if docker image inspect "$SITL_IMAGE" >/dev/null 2>&1; then
        log_info "Keeping cached image: $SITL_IMAGE"
        return 0
    fi

    log_info "Pulling missing image: $SITL_IMAGE"
    docker pull "$SITL_IMAGE"
}

verify_installation() {
    log_step "Verifying sitlctl..."
    if ! "$HOME/bin/sitlctl" --help >/dev/null; then
        log_error "Installed sitlctl did not pass its help smoke test."
        exit 1
    fi
    log_info "sitlctl is executable and its runtime bundle is present."
}

remove_legacy_command() {
    local legacy="$HOME/bin/sitl"
    if [ -d "$legacy" ] && [ ! -L "$legacy" ]; then
        log_error "Cannot remove legacy command because it is a directory: $legacy"
        exit 1
    fi
    if [ -e "$legacy" ] || [ -L "$legacy" ]; then
        rm -f "$legacy"
        log_info "Removed legacy ~/bin/sitl command."
    fi
}

print_success() {
    printf '\n'
    printf 'Installation complete.\n'
    printf '  Start instance 1: sitlctl start 1 copter\n'
    printf '  Start instance 2: sitlctl start 2 rover\n'
    printf '  Check both:       sitlctl status all\n'
    printf '  Stop both:        sitlctl stop all\n'
}

main() {
    check_docker
    check_bin_directory
    install_runtime
    ensure_image
    verify_installation
    remove_legacy_command
    print_success
}

main "$@"

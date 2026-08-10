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
STAGED_RUNTIME_DIR=""

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
    if ! docker compose version >/dev/null 2>&1 \
        && ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is not installed."
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

cleanup_staged_runtime() {
    if [ -n "$STAGED_RUNTIME_DIR" ] && [ -d "$STAGED_RUNTIME_DIR" ]; then
        rm -rf "$STAGED_RUNTIME_DIR"
    fi
}

stage_runtime() {
    log_step "Staging sitlctl runtime..."
    local runtime_files=(sitlctl docker-compose.yml docker-entrypoint.sh locations.txt)
    local name

    STAGED_RUNTIME_DIR=$(mktemp -d "$HOME/bin/.sitlctl-stage.XXXXXX")
    trap cleanup_staged_runtime EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    for name in "${runtime_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$name" ]; then
            log_error "Runtime file not found: $SCRIPT_DIR/$name"
            exit 1
        fi
        cp "$SCRIPT_DIR/$name" "$STAGED_RUNTIME_DIR/$name"
    done
    chmod 755 "$STAGED_RUNTIME_DIR/sitlctl" "$STAGED_RUNTIME_DIR/docker-entrypoint.sh"

    if ! "$STAGED_RUNTIME_DIR/sitlctl" --help >/dev/null; then
        log_error "Staged sitlctl did not pass its help smoke test."
        exit 1
    fi
    log_info "Complete runtime bundle staged and verified."
}

install_staged_runtime() {
    log_step "Installing sitlctl..."
    local runtime_files=(sitlctl docker-compose.yml docker-entrypoint.sh locations.txt)
    local name

    for name in "${runtime_files[@]}"; do
        mv -f "$STAGED_RUNTIME_DIR/$name" "$HOME/bin/$name"
    done
    rmdir "$STAGED_RUNTIME_DIR"
    STAGED_RUNTIME_DIR=""
    trap - EXIT INT TERM
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
    ensure_image
    stage_runtime
    install_staged_runtime
    remove_legacy_command
    print_success
}

main "$@"

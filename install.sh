#!/bin/bash

# ArduPilot SITL CLI - Installation Script
# Supports macOS and Linux (Ubuntu/Debian)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*) PLATFORM="macos" ;;
        Linux*)  PLATFORM="linux" ;;
        *)       PLATFORM="unknown" ;;
    esac
    echo "$PLATFORM"
}

PLATFORM=$(detect_platform)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_docker() {
    log_step "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        echo ""
        
        if [ "$PLATFORM" = "linux" ]; then
            echo "Install Docker on Ubuntu/Debian:"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install -y docker.io docker-compose"
            echo "  sudo usermod -aG docker \$USER"
            echo "  newgrp docker  # or logout/login"
        else
            echo "Install Docker Desktop:"
            echo "  https://docker.com/products/docker-desktop/"
        fi
        echo ""
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or permission denied!"
        echo ""
        
        if [ "$PLATFORM" = "linux" ]; then
            echo "Docker is installed but not accessible. Try:"
            echo "  1. Start Docker service: sudo systemctl start docker"
            echo "  2. Add user to docker group: sudo usermod -aG docker \$USER"
            echo "  3. Apply group changes: newgrp docker"
            echo ""
            echo "Note: You may need to logout and login again for group changes."
        else
            echo "Please start Docker Desktop and wait for it to initialize."
        fi
        echo ""
        exit 1
    fi
    
    log_info "Docker is installed and running ✓"
}

check_bin_directory() {
    log_step "Checking ~/bin directory..."
    
    if [ ! -d "$HOME/bin" ]; then
        log_info "Creating ~/bin directory..."
        mkdir -p "$HOME/bin"
    else
        log_info "~/bin directory exists ✓"
    fi
    
    # Check if ~/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        log_warn "~/bin is not in your PATH!"
        echo ""
        echo "Add the following to your shell configuration file:"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo ""
        if [ "$PLATFORM" = "linux" ]; then
            echo "For bash: ~/.bashrc"
            echo "For zsh: ~/.zshrc"
        else
            echo "For bash: ~/.bashrc"
            echo "For zsh: ~/.zshrc"
        fi
        echo ""
        echo "Then reload your shell configuration:"
        echo "  source ~/.bashrc  # or ~/.zshrc"
        echo ""
    else
        log_info "~/bin is in PATH ✓"
    fi
}

install_sitl_command() {
    log_step "Installing sitl command..."
    
    local source_file="$SCRIPT_DIR/sitl"
    local target_file="$HOME/bin/sitl"
    
    if [ ! -f "$source_file" ]; then
        log_error "sitl script not found at: $source_file"
        exit 1
    fi
    
    # Install the launcher and its runtime bundle together.
    cp "$source_file" "$target_file"
    chmod +x "$target_file"
    cp "$SCRIPT_DIR/docker-compose.yml" "$HOME/bin/docker-compose.yml"
    cp "$SCRIPT_DIR/docker-entrypoint.sh" "$HOME/bin/docker-entrypoint.sh"
    cp "$SCRIPT_DIR/locations.txt" "$HOME/bin/locations.txt"
    chmod +x "$HOME/bin/docker-entrypoint.sh"
    ln -sfn sitl "$HOME/bin/sitlctl"
    
    log_info "sitl and sitlctl installed to ~/bin ✓"
}

pull_docker_image() {
    log_step "Pulling Docker image..."
    
    log_info "This may take a few minutes depending on your connection..."
    echo ""
    
    if docker pull vanfleetdev/sitl-ardupilot:4.6.3; then
        log_info "Docker image pulled successfully ✓"
    else
        log_error "Failed to pull Docker image!"
        exit 1
    fi
}

verify_installation() {
    log_step "Verifying installation..."
    
    if command -v sitl &> /dev/null; then
        log_info "sitl command is available ✓"
        
        # Test help command
        if sitl --help &> /dev/null; then
            log_info "sitl command working correctly ✓"
        else
            log_warn "sitl command may need shell restart to work properly"
        fi
    else
        log_warn "sitl command not found in PATH"
        if [ "$PLATFORM" = "linux" ]; then
            log_info "You may need to restart your terminal or run: source ~/.bashrc"
        else
            log_info "You may need to restart your terminal or run: source ~/.zshrc"
        fi
    fi
}

print_success() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Installation Complete!                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Quick Start:"
    echo "  1. Start SITL:     sitl plane"
    echo "  2. Connect:        mavproxy.py --master=tcp:localhost:5760"
    echo "  3. Stop SITL:      sitl stop"
    echo ""
    echo "Available commands:"
    echo "  sitl plane, sitl copter, sitl quadplane, sitl rover"
    echo "  sitl stop, sitl status, sitl shell, sitl logs"
    echo ""
    echo "For detailed usage: sitl --help"
    echo "Documentation: docs/USAGE.md"
    echo ""
    
    if [ "$PLATFORM" = "linux" ]; then
        echo "Platform: Linux ✓"
    else
        echo "Platform: macOS ✓"
    fi
    echo ""
}

main() {
    echo ""
    echo -e "${BLUE}ArduPilot SITL CLI - Installer${NC}"
    echo ""
    
    if [ "$PLATFORM" = "unknown" ]; then
        log_warn "Unknown platform detected. Proceeding anyway..."
        echo "Supported platforms: macOS, Linux (Ubuntu/Debian)"
        echo ""
    fi
    
    check_docker
    check_bin_directory
    install_sitl_command
    pull_docker_image
    verify_installation
    print_success
}

main "$@"

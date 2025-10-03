#!/bin/bash
# ABOUTME: Simple installation script for VPN Manager core components

set -e  # Exit on any error

# Core configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/vpn"
COMPONENTS=(
    "vpn"
    "vpn-manager"
    "vpn-connector"
    "vpn-error-handler"
    "best-vpn-profile"
    "fix-ovpn-configs"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Simple logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if running as root (shouldn't be)
if [[ $EUID -eq 0 ]]; then
    log_error "Don't run as root. Script will use sudo when needed."
    exit 1
fi

# Check for required dependencies
check_dependencies() {
    local missing=()
    for cmd in openvpn curl bc; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# Install core components
install_components() {
    log_info "Installing VPN Manager components to $INSTALL_DIR"

    for component in "${COMPONENTS[@]}"; do
        if [[ ! -f "src/$component" ]]; then
            log_error "Component not found: src/$component"
            exit 1
        fi

        # Copy with sudo, preserving executable bit
        sudo cp -f "src/$component" "$INSTALL_DIR/"
        sudo chmod 755 "$INSTALL_DIR/$component"
        log_info "Installed: $component"
    done
}

# Create config directory
setup_config() {
    log_info "Creating config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"

    # Create locations subdirectory for .ovpn files
    mkdir -p "$CONFIG_DIR/locations"

    # Create credentials template if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/vpn-credentials.txt" ]]; then
        cat > "$CONFIG_DIR/vpn-credentials.txt" << 'EOF'
# ProtonVPN OpenVPN Credentials
# Line 1: Username
# Line 2: Password
your-username-here
your-password-here
EOF
        chmod 600 "$CONFIG_DIR/vpn-credentials.txt"
        log_warning "Created credentials template: $CONFIG_DIR/vpn-credentials.txt"
        log_warning "Edit this file with your actual ProtonVPN credentials"
    fi
}

# Main installation
main() {
    echo "VPN Manager - Simple Installation"
    echo "=================================="

    # Check we're in the right directory
    if [[ ! -d "src" ]] || [[ ! -f "src/vpn" ]]; then
        log_error "Run this script from the VPN project root directory"
        exit 1
    fi

    check_dependencies
    install_components
    setup_config

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Edit credentials: $CONFIG_DIR/vpn-credentials.txt"
    echo "2. Copy .ovpn files to: $CONFIG_DIR/locations/"
    echo "3. Test with: vpn help"
    echo ""
}

main "$@"

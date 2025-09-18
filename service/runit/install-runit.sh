#!/bin/bash
# ABOUTME: ProtonVPN Config Updater - Runit service installer

set -euo pipefail

# Configuration
SERVICE_NAME="protonvpn-updater"
VPN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_SOURCE="$VPN_ROOT/service/runit/$SERVICE_NAME"
SERVICE_TARGET="/etc/runit/sv/$SERVICE_NAME"
SERVICE_LINK="/etc/runit/runsvdir/current/$SERVICE_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if runit is available
if ! command -v sv >/dev/null 2>&1; then
    log_error "runit (sv command) not found. Is this an Artix system?"
    exit 1
fi

# Check if service source exists
if [ ! -d "$SERVICE_SOURCE" ]; then
    log_error "Service source directory not found: $SERVICE_SOURCE"
    exit 1
fi

# Function to install service
install_service() {
    log_info "Installing ProtonVPN Config Updater service for runit..."

    # Copy service files
    log_info "Copying service files from $SERVICE_SOURCE to $SERVICE_TARGET"
    cp -r "$SERVICE_SOURCE" "$SERVICE_TARGET"

    # Update VPN_ROOT in service file
    log_info "Updating VPN_ROOT path in service file"
    sed -i "s|VPN_ROOT=\".*\"|VPN_ROOT=\"$VPN_ROOT\"|" "$SERVICE_TARGET/run"

    # Set proper permissions
    chown -R root:root "$SERVICE_TARGET"
    chmod +x "$SERVICE_TARGET/run"
    chmod +x "$SERVICE_TARGET/log/run"

    log_info "Service files installed successfully"
}

# Function to enable service
enable_service() {
    log_info "Enabling ProtonVPN Config Updater service..."

    # Create symlink to enable service
    if [ ! -L "$SERVICE_LINK" ]; then
        ln -sf "$SERVICE_TARGET" "$SERVICE_LINK"
        log_info "Service symlink created: $SERVICE_LINK"
    else
        log_warn "Service symlink already exists: $SERVICE_LINK"
    fi

    # Wait a moment for runit to detect the service
    sleep 2

    # Start the service
    if sv start "$SERVICE_NAME" >/dev/null 2>&1; then
        log_info "Service started successfully"
    else
        log_warn "Service may need manual start: sv start $SERVICE_NAME"
    fi
}

# Function to show status
show_status() {
    log_info "Service status:"
    sv status "$SERVICE_NAME" || log_warn "Service not running or not found"
}

# Function to uninstall service
uninstall_service() {
    log_info "Uninstalling ProtonVPN Config Updater service..."

    # Stop service if running
    if sv status "$SERVICE_NAME" >/dev/null 2>&1; then
        log_info "Stopping service..."
        sv stop "$SERVICE_NAME"
        sleep 2
    fi

    # Remove symlink
    if [ -L "$SERVICE_LINK" ]; then
        rm -f "$SERVICE_LINK"
        log_info "Service symlink removed"
    fi

    # Remove service directory
    if [ -d "$SERVICE_TARGET" ]; then
        rm -rf "$SERVICE_TARGET"
        log_info "Service directory removed"
    fi

    log_info "Service uninstalled successfully"
}

# Main script logic
case "${1:-install}" in
    install)
        install_service
        enable_service
        show_status
        log_info "Installation complete! Use 'sv start/stop/status $SERVICE_NAME' to manage the service"
        ;;
    uninstall)
        uninstall_service
        ;;
    status)
        show_status
        ;;
    reinstall)
        uninstall_service
        sleep 2
        install_service
        enable_service
        show_status
        ;;
    *)
        echo "Usage: $0 {install|uninstall|status|reinstall}"
        echo ""
        echo "Commands:"
        echo "  install    - Install and start the ProtonVPN updater service"
        echo "  uninstall  - Stop and remove the ProtonVPN updater service"
        echo "  status     - Show current service status"
        echo "  reinstall  - Uninstall and reinstall the service"
        exit 1
        ;;
esac

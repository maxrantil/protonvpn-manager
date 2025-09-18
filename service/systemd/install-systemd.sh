#!/bin/bash
# ABOUTME: ProtonVPN Config Updater - Systemd service installer

set -euo pipefail

# Configuration
SERVICE_NAME="protonvpn-updater"
VPN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_SOURCE="$VPN_ROOT/service/systemd"
SERVICE_TARGET="/etc/systemd/system"

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

# Check if systemd is available
if ! command -v systemctl >/dev/null 2>&1; then
    log_error "systemd (systemctl command) not found. Is this an Arch system?"
    exit 1
fi

# Function to install service
install_service() {
    log_info "Installing ProtonVPN Config Updater service for systemd..."

    # Copy service files
    log_info "Copying service files to $SERVICE_TARGET"
    cp "$SERVICE_SOURCE/${SERVICE_NAME}.service" "$SERVICE_TARGET/"
    cp "$SERVICE_SOURCE/${SERVICE_NAME}.timer" "$SERVICE_TARGET/"
    cp "$SERVICE_SOURCE/${SERVICE_NAME}-daemon.sh" "/usr/local/bin/"

    # Update VPN_ROOT in service files
    log_info "Updating VPN_ROOT path in service files"
    sed -i "s|/home/user/workspace/claude-code/vpn|$VPN_ROOT|g" "$SERVICE_TARGET/${SERVICE_NAME}.service"
    sed -i "s|/home/user/workspace/claude-code/vpn|$VPN_ROOT|g" "/usr/local/bin/${SERVICE_NAME}-daemon.sh"

    # Set proper permissions
    chmod 644 "$SERVICE_TARGET/${SERVICE_NAME}.service"
    chmod 644 "$SERVICE_TARGET/${SERVICE_NAME}.timer"
    chmod 755 "/usr/local/bin/${SERVICE_NAME}-daemon.sh"

    # Create log directory
    mkdir -p /var/log/protonvpn
    chown nobody:nobody /var/log/protonvpn

    log_info "Service files installed successfully"
}

# Function to enable service
enable_service() {
    log_info "Enabling ProtonVPN Config Updater service..."

    # Reload systemd
    systemctl daemon-reload

    # Enable and start timer (not the service directly)
    systemctl enable "${SERVICE_NAME}.timer"
    systemctl start "${SERVICE_NAME}.timer"

    log_info "Service enabled and timer started successfully"
}

# Function to show status
show_status() {
    log_info "Service status:"
    echo "Timer status:"
    systemctl status "${SERVICE_NAME}.timer" --no-pager || log_warn "Timer not found"
    echo
    echo "Service status:"
    systemctl status "${SERVICE_NAME}.service" --no-pager || log_warn "Service not running"
    echo
    echo "Next scheduled runs:"
    systemctl list-timers "${SERVICE_NAME}.timer" --no-pager || log_warn "Timer info not available"
}

# Function to uninstall service
uninstall_service() {
    log_info "Uninstalling ProtonVPN Config Updater service..."

    # Stop and disable timer and service
    systemctl stop "${SERVICE_NAME}.timer" 2>/dev/null || true
    systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}.timer" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true

    # Remove service files
    rm -f "$SERVICE_TARGET/${SERVICE_NAME}.service"
    rm -f "$SERVICE_TARGET/${SERVICE_NAME}.timer"
    rm -f "/usr/local/bin/${SERVICE_NAME}-daemon.sh"

    # Reload systemd
    systemctl daemon-reload

    log_info "Service uninstalled successfully"
}

# Function to configure timer interval
configure_timer() {
    local interval="$1"

    log_info "Configuring timer interval to: $interval"

    # Create override directory
    mkdir -p "/etc/systemd/system/${SERVICE_NAME}.timer.d"

    # Create override file
    cat > "/etc/systemd/system/${SERVICE_NAME}.timer.d/override.conf" << EOF
[Timer]
# Override default schedule
OnCalendar=
OnCalendar=$interval
EOF

    # Reload and restart timer
    systemctl daemon-reload
    systemctl restart "${SERVICE_NAME}.timer"

    log_info "Timer reconfigured successfully"
}

# Main script logic
case "${1:-install}" in
    install)
        install_service
        enable_service
        show_status
        log_info "Installation complete! Use 'systemctl status ${SERVICE_NAME}.timer' to check status"
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
    configure-timer)
        if [ $# -lt 2 ]; then
            log_error "Timer configuration requires interval"
            echo "Usage: $0 configure-timer 'hourly'"
            echo "       $0 configure-timer '*:0/30'"  # Every 30 minutes
            echo "       $0 configure-timer 'daily'"
            exit 1
        fi
        configure_timer "$2"
        ;;
    *)
        echo "Usage: $0 {install|uninstall|status|reinstall|configure-timer}"
        echo ""
        echo "Commands:"
        echo "  install           - Install and start the ProtonVPN updater service"
        echo "  uninstall         - Stop and remove the ProtonVPN updater service"
        echo "  status            - Show current service and timer status"
        echo "  reinstall         - Uninstall and reinstall the service"
        echo "  configure-timer INTERVAL - Configure timer interval"
        echo ""
        echo "Timer Examples:"
        echo "  configure-timer 'hourly'     - Run every hour"
        echo "  configure-timer 'daily'      - Run daily"
        echo "  configure-timer '*:0/30'     - Run every 30 minutes"
        echo "  configure-timer '*-*-* 6:00' - Run daily at 6 AM"
        exit 1
        ;;
esac

#!/bin/bash
# ABOUTME: ProtonVPN Config Updater daemon for systemd

set -euo pipefail

# Configuration
VPN_ROOT="/home/mqx/workspace/claude-code/vpn"
LOG_DIR="/var/log/protonvpn"
PID_FILE="/run/protonvpn-updater.pid"

# Ensure directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$PID_FILE")"

# Change to VPN directory
cd "$VPN_ROOT" || exit 1

# Check dependencies
if ! command -v "$VPN_ROOT/src/download-engine" >/dev/null 2>&1; then
    echo "ERROR: download-engine not found at $VPN_ROOT/src/download-engine" >&2
    exit 1
fi

# Log startup
echo "$(date): ProtonVPN Config Updater daemon starting (PID: $$)"

# Store PID
echo $$ > "$PID_FILE"

# Cleanup on exit
cleanup() {
    echo "$(date): ProtonVPN Config Updater daemon stopping (PID: $$)"
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup TERM INT

# Single update run (for timer-based execution)
run_update_check() {
    echo "$(date): Starting config update check..."

    # Check if authentication is available
    if "$VPN_ROOT/src/proton-auth" status >/dev/null 2>&1; then
        echo "$(date): Authentication available, checking for config updates..."

        # Run update check (will use real download if authenticated)
        if "$VPN_ROOT/src/download-engine" status; then
            echo "$(date): Config update check completed successfully"
            return 0
        else
            local exit_code=$?
            echo "$(date): Config update check failed (exit code: $exit_code)"
            return $exit_code
        fi
    else
        echo "$(date): No authentication available, skipping update check"
        return 0
    fi
}

# Main execution
run_update_check

#!/bin/bash
# ABOUTME: Simple installation script for VPN Manager core components

set -e # Exit on any error

# Core configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/vpn"
COMPONENTS=(
	"vpn"
	"vpn-manager"
	"vpn-connector"
	"vpn-error-handler"
	"vpn-utils"
	"vpn-colors"
	"vpn-validators"
	"best-vpn-profile"
	"vpn-doctor"
	"vpn-kill-switch"
	"temp-file-manager"
)

# Root-owned system config: tells root-run hooks which user's VPN to manage
# (they refuse to guess when several users are logged in)
SYSTEM_CONF="/etc/protonvpn-manager.conf"

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
	for cmd in openvpn curl ip flock; do
		if ! command -v "$cmd" &>/dev/null; then
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

		# Root-owned, not writable by the user: these scripts run sudo and are
		# executed by root hooks, so a user-writable copy would be a root backdoor
		sudo install -o root -g root -m 755 "src/$component" "$INSTALL_DIR/$component"
		log_info "Installed: $component"
	done
}

# Record the managing user for root-run hooks (sleep / NetworkManager)
setup_system_config() {
	local user
	user=$(id -un)
	if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
		log_warning "Unusual username '$user'; skipping $SYSTEM_CONF"
		return 0
	fi
	printf '# ProtonVPN Manager - user whose VPN the system hooks manage\nVPN_USER=%s\n' "$user" |
		sudo install -o root -g root -m 644 /dev/stdin "$SYSTEM_CONF"
	log_info "Wrote $SYSTEM_CONF (VPN_USER=$user)"
}

# Create config directory
setup_config() {
	log_info "Creating config directory: $CONFIG_DIR"
	# Private: holds credentials and profiles
	(umask 077 && mkdir -p "$CONFIG_DIR/locations")
	chmod 700 "$CONFIG_DIR" "$CONFIG_DIR/locations"

	# Create credentials template if it doesn't exist
	if [[ ! -f "$CONFIG_DIR/vpn-credentials.txt" ]]; then
		(umask 077 && cat >"$CONFIG_DIR/vpn-credentials.txt") <<'EOF'
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
	setup_system_config
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

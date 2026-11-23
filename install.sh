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

# Root-owned helper OpenVPN runs as root to apply the VPN's DNS (resolvconf).
# It must stay root-owned: the connector refuses to use it otherwise.
HELPER_DIR="/usr/local/lib/protonvpn-manager"
DNS_HELPER="vpn-dns-update"

# Root-owned system config: tells root-run hooks which user's VPN to manage
# (they refuse to guess when several users are logged in)
SYSTEM_CONF="/etc/protonvpn-manager.conf"

# NetworkManager DNS (#295): a drop-in that makes NetworkManager hand its DNS
# to openresolv (where the VPN's entry is exclusive) instead of overwriting
# resolv.conf, and the dispatcher hook that repairs resolv.conf on dns-change
NM_CONF_DIR="/etc/NetworkManager/conf.d"
NM_MAIN_CONF="/etc/NetworkManager/NetworkManager.conf"
NM_DISPATCHER_DIR="/etc/NetworkManager/dispatcher.d"
NM_DNS_DROPIN="protonvpn-manager-dns.conf"
DNS_REPAIR_HOOK="40-vpn-dns-repair"
RESOLV_CONF="/etc/resolv.conf"

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

# Install the DNS helper outside the user's reach
install_dns_helper() {
	sudo install -d -o root -g root -m 755 "$HELPER_DIR"
	sudo install -o root -g root -m 755 "src/$DNS_HELPER" "$HELPER_DIR/$DNS_HELPER"
	log_info "Installed: $HELPER_DIR/$DNS_HELPER"
	if ! command -v resolvconf &>/dev/null; then
		log_warning "resolvconf not found: VPN DNS cannot be applied (DNS may leak)."
		log_warning "Install it with: sudo pacman -S openresolv"
	fi
}

# Why the NetworkManager DNS setup must not run here. Prints the reason and
# returns 0 when it must be skipped; returns 1 when every condition holds.
nm_dns_skip_reason() {
	local file
	if ! command -v nmcli &>/dev/null || ! nmcli -t general status &>/dev/null; then
		echo "NetworkManager is not running"
		return 0
	fi
	if ! resolvconf --version 2>/dev/null | grep -qi openresolv; then
		echo "resolvconf is not openresolv"
		return 0
	fi
	# Process names are cut to 15 characters: this matches systemd-resolved
	if pgrep -x systemd-resolve &>/dev/null; then
		echo "systemd-resolved is running (it manages DNS here)"
		return 0
	fi
	if [[ -L $RESOLV_CONF ]]; then
		echo "$RESOLV_CONF is a symlink (another tool manages it)"
		return 0
	fi
	if [[ -L $NM_CONF_DIR ]]; then
		echo "$NM_CONF_DIR is a symlink"
		return 0
	fi
	# Never override an rc-manager the user set; this tool's own drop-in is
	# not a foreign one
	for file in "$NM_MAIN_CONF" "$NM_CONF_DIR"/*.conf; do
		[[ -f $file && $file != "$NM_CONF_DIR/$NM_DNS_DROPIN" ]] || continue
		if [[ ! -r $file ]]; then
			echo "cannot read $file (it may set rc-manager)"
			return 0
		fi
		if grep -qE '^[[:space:]]*rc-manager[[:space:]]*=' "$file"; then
			echo "rc-manager is already set in $file"
			return 0
		fi
	done
	return 1
}

# Install the NetworkManager DNS drop-in and the 40-vpn-dns-repair hook.
# Skips with a message where it can't apply; never fails the installer.
install_nm_dns() {
	local reason src_dropin="etc/NetworkManager/conf.d/$NM_DNS_DROPIN"
	local dropin="$NM_CONF_DIR/$NM_DNS_DROPIN" tmp="$NM_CONF_DIR/.$NM_DNS_DROPIN.tmp"
	if reason=$(nm_dns_skip_reason); then
		log_warning "Skipping NetworkManager DNS setup: $reason"
		log_warning "NetworkManager may overwrite the VPN's DNS while connected; 'vpn status' warns when it does"
		return 0
	fi

	# The hook first: on its own it only repairs resolv.conf while this
	# tool's VPN is up
	[[ -d $NM_DISPATCHER_DIR ]] || sudo install -d -o root -g root -m 755 "$NM_DISPATCHER_DIR"
	sudo install -o root -g root -m 755 "etc/NetworkManager/dispatcher.d/$DNS_REPAIR_HOOK" \
		"$NM_DISPATCHER_DIR/$DNS_REPAIR_HOOK"
	log_info "Installed: $NM_DISPATCHER_DIR/$DNS_REPAIR_HOOK"

	if cmp -s "$src_dropin" "$dropin"; then
		log_info "Unchanged: $dropin"
	else
		[[ -d $NM_CONF_DIR ]] || sudo install -d -o root -g root -m 755 "$NM_CONF_DIR"
		# Atomic: written to a dot-named temp file (NetworkManager loads only
		# *.conf), then renamed over the drop-in
		sudo install -T -o root -g root -m 644 "$src_dropin" "$tmp"
		if ! sudo mv -T "$tmp" "$dropin"; then
			sudo rm -f "$tmp"
			log_warning "Could not write $dropin; NetworkManager DNS left unchanged"
			return 0
		fi
		if ! sudo nmcli general reload conf; then
			sudo rm -f "$dropin"
			log_warning "NetworkManager did not reload its config; removed $dropin again"
			return 0
		fi
		log_info "Installed: $dropin (NetworkManager hands its DNS to resolvconf)"
		# Installed while connected: put the VPN's exclusive entry back in force
		if [[ -n $(resolvconf -l tun0.protonvpn 2>/dev/null) ]]; then
			sudo resolvconf -u || log_warning "resolvconf -u failed; run: sudo resolvconf -u"
		fi
	fi
	log_info "Undo with: ./install.sh --uninstall-nm-dns"
}

# Undo install_nm_dns: remove the drop-in and the hook, and give resolv.conf
# back to NetworkManager. Safe to run when nothing is installed.
uninstall_nm_dns() {
	local dropin="$NM_CONF_DIR/$NM_DNS_DROPIN" hook="$NM_DISPATCHER_DIR/$DNS_REPAIR_HOOK"
	sudo rm -f "$dropin" "$hook"
	log_info "Removed (if present): $dropin and $hook"
	if command -v nmcli &>/dev/null; then
		sudo nmcli general reload conf ||
			log_warning "NetworkManager did not reload its config (is it running?)"
	fi
	command -v resolvconf &>/dev/null || return 0
	# NetworkManager leaves its resolvconf entry behind when it leaves
	# resolvconf mode
	sudo resolvconf -f -d NetworkManager || true
	if [[ -n $(resolvconf -l tun0.protonvpn 2>/dev/null) ]]; then
		# Connected: rebuild resolv.conf from the VPN's exclusive entry
		sudo resolvconf -u || log_warning "resolvconf -u failed; run: sudo resolvconf -u"
	elif command -v nmcli &>/dev/null; then
		# Not connected: openresolv has no entry left, so -u would write a
		# resolv.conf with no nameserver. NetworkManager writes its own back.
		sudo nmcli general reload dns-full ||
			log_warning "NetworkManager did not rewrite resolv.conf; check: cat $RESOLV_CONF"
	fi
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

usage() {
	cat <<EOF
Usage: ./install.sh [--no-nm-dns | --uninstall-nm-dns]
  (no option)         install everything, including the NetworkManager DNS setup
  --no-nm-dns         install everything except the NetworkManager DNS setup (and undo it)
  --uninstall-nm-dns  only undo the NetworkManager DNS setup
EOF
}

# Main installation
main() {
	local nm_dns=install
	if [[ $# -gt 1 ]]; then
		log_error "Too many options: $*"
		usage
		exit 1
	fi
	case "${1:-}" in
	"") ;;
	--no-nm-dns) nm_dns=undo ;;
	--uninstall-nm-dns)
		uninstall_nm_dns
		return 0
		;;
	-h | --help)
		usage
		return 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac

	echo "VPN Manager - Simple Installation"
	echo "=================================="

	# Check we're in the right directory
	if [[ ! -d "src" ]] || [[ ! -f "src/vpn" ]]; then
		log_error "Run this script from the VPN project root directory"
		exit 1
	fi

	check_dependencies
	install_components
	install_dns_helper
	if [[ $nm_dns == install ]]; then
		install_nm_dns
	else
		uninstall_nm_dns
	fi
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

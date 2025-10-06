#!/bin/bash
# ABOUTME: Automated uninstall script for VPN Management System on Artix/Arch Linux

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - auto-detect project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$SCRIPT_DIR"
LOCATIONS_DIR="$VPN_DIR/locations"
SRC_DIR="$VPN_DIR/src"

# Functions
print_banner() {
    echo -e "${RED}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              VPN Management System Uninstaller            ║"
    echo "║                    Artix/Arch Linux                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm_uninstall() {
    echo ""
    log_warning "This will remove the VPN Management System and all its components."
    log_info "The following will be removed:"
    echo "  • VPN scripts and utilities"
    echo "  • Configuration files (except credentials)"
    echo "  • Log files and caches"
    echo "  • PATH modifications"
    echo ""
    log_info "The following will be preserved:"
    echo "  • Your ProtonVPN configuration files (*.ovpn)"
    echo "  • Your credentials file (vpn-credentials.txt)"
    echo "  • System packages (openvpn, curl, etc.)"
    echo ""

    read -p "Do you want to continue with uninstallation? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled by user"
        exit 0
    fi
}

disconnect_vpn() {
    log_info "Ensuring VPN is disconnected..."

    if [[ -f "$SRC_DIR/vpn" ]] && [[ -x "$SRC_DIR/vpn" ]]; then
        if "$SRC_DIR/vpn" disconnect &> /dev/null; then
            log_success "VPN disconnected"
        else
            log_info "VPN was not connected or already disconnected"
        fi
    fi

    # Force cleanup of any remaining processes
    if pgrep -x openvpn &> /dev/null; then
        log_warning "Found running OpenVPN processes, terminating..."
        if sudo pkill -x openvpn 2>/dev/null; then
            log_success "OpenVPN processes terminated"
        else
            log_warning "Could not terminate OpenVPN processes"
        fi
    fi
}

cleanup_temp_files() {
    log_info "Cleaning up temporary files..."

    local temp_files=(
        "/tmp/vpn_connect.lock"
        "/tmp/vpn_performance.cache"
        "/tmp/vpn_tester.log"
        "/tmp/vpn_current_profile.txt"
        "/tmp/vpn_last_profile.txt"
        "/tmp/vpn_backup_dns_*"
    )

    local removed_count=0

    for file_pattern in "${temp_files[@]}"; do
        if compgen -G "$file_pattern" > /dev/null 2>&1; then
            # Intentional globbing for file pattern expansion
            # shellcheck disable=SC2086
            rm -f $file_pattern 2>/dev/null && ((removed_count++))
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_success "Removed $removed_count temporary files"
    else
        log_info "No temporary files to clean up"
    fi
}

backup_user_data() {
    log_info "Backing up user data..."

    local backup_dir
    backup_dir="$HOME/vpn-backup-$(date +%Y%m%d-%H%M%S)"
    local backed_up=0

    # Create backup directory
    if mkdir -p "$backup_dir"; then
        log_success "Created backup directory: $backup_dir"

        # Backup credentials
        if [[ -f "$VPN_DIR/vpn-credentials.txt" ]]; then
            if cp "$VPN_DIR/vpn-credentials.txt" "$backup_dir/"; then
                log_success "Backed up credentials file"
                ((backed_up++))
            fi
        fi

        # Backup OpenVPN configs
        if [[ -d "$LOCATIONS_DIR" ]] && [[ $(find "$LOCATIONS_DIR" -name "*.ovpn" -type f | wc -l) -gt 0 ]]; then
            if mkdir -p "$backup_dir/locations" && cp "$LOCATIONS_DIR"/*.ovpn "$backup_dir/locations/" 2>/dev/null; then
                local ovpn_count
                ovpn_count=$(find "$backup_dir/locations" -name "*.ovpn" -type f | wc -l)
                log_success "Backed up $ovpn_count OpenVPN configuration files"
                ((backed_up++))
            fi
        fi

        # Backup logs if they exist
        if [[ -f "/tmp/vpn_tester.log" ]]; then
            if cp "/tmp/vpn_tester.log" "$backup_dir/"; then
                log_success "Backed up log file"
                ((backed_up++))
            fi
        fi

        if [[ $backed_up -gt 0 ]]; then
            log_success "User data backed up to: $backup_dir"
        else
            # Remove empty backup directory
            rmdir "$backup_dir" 2>/dev/null
            log_info "No user data found to backup"
        fi
    else
        log_error "Failed to create backup directory"
    fi
}

remove_path_modifications() {
    log_info "Removing PATH modifications..."

    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    local removed=0

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            # Create temporary file without VPN PATH entries
            if grep -v "vpn.*PATH\|VPN Management System" "$config" > "${config}.tmp" 2>/dev/null; then
                # Check if anything was actually removed
                if ! cmp -s "$config" "${config}.tmp"; then
                    mv "${config}.tmp" "$config"
                    log_success "Removed PATH modifications from $(basename "$config")"
                    ((removed++))
                else
                    rm -f "${config}.tmp"
                fi
            else
                rm -f "${config}.tmp"
            fi
        fi
    done

    if [[ $removed -eq 0 ]]; then
        log_info "No PATH modifications found to remove"
    fi
}

remove_vpn_directory() {
    log_info "Removing VPN Management System directory..."

    if [[ -d "$VPN_DIR" ]]; then
        # Count files for reporting
        local file_count
        file_count=$(find "$VPN_DIR" -type f | wc -l)

        if rm -rf "$VPN_DIR"; then
            log_success "Removed VPN directory with $file_count files: $VPN_DIR"
        else
            log_error "Failed to remove VPN directory: $VPN_DIR"
            return 1
        fi
    else
        log_info "VPN directory not found: $VPN_DIR"
    fi
}

check_package_removal() {
    log_info "Checking for package removal options..."

    local vpn_packages=("openvpn" "curl" "bc" "libnotify" "iproute2")
    local can_remove=()
    local keep_packages=()

    for pkg in "${vpn_packages[@]}"; do
        if pacman -Qi "$pkg" &> /dev/null; then
            # Check if package is used by other applications (simplified check)
            if [[ "$pkg" == "curl" ]] || [[ "$pkg" == "bc" ]] || [[ "$pkg" == "libnotify" ]] || [[ "$pkg" == "iproute2" ]]; then
                keep_packages+=("$pkg")
            else
                can_remove+=("$pkg")
            fi
        fi
    done

    if [[ ${#can_remove[@]} -gt 0 ]]; then
        log_info "The following packages could be removed if no longer needed:"
        for pkg in "${can_remove[@]}"; do
            echo "  • $pkg"
        done
        echo ""
        log_warning "To remove these packages manually, run:"
        echo "  sudo pacman -Rs ${can_remove[*]}"
        echo ""
    fi

    if [[ ${#keep_packages[@]} -gt 0 ]]; then
        log_info "The following packages are commonly used by other applications and were kept:"
        for pkg in "${keep_packages[@]}"; do
            echo "  • $pkg"
        done
    fi
}

run_post_uninstall_verification() {
    log_info "Running post-uninstall verification..."

    local issues=0

    # Check if VPN directory is gone
    if [[ -d "$VPN_DIR" ]]; then
        log_error "✗ VPN directory still exists: $VPN_DIR"
        ((issues++))
    else
        log_success "✓ VPN directory removed"
    fi

    # Check if OpenVPN processes are stopped
    if pgrep -x openvpn &> /dev/null; then
        log_warning "✗ OpenVPN processes still running"
        ((issues++))
    else
        log_success "✓ No OpenVPN processes running"
    fi

    # Check temp files cleanup
    local temp_files_exist=0
    if [[ -f "/tmp/vpn_connect.lock" ]] || [[ -f "/tmp/vpn_performance.cache" ]] || [[ -f "/tmp/vpn_tester.log" ]]; then
        temp_files_exist=1
    fi

    if [[ $temp_files_exist -eq 1 ]]; then
        log_warning "✗ Some temporary files may still exist"
        ((issues++))
    else
        log_success "✓ Temporary files cleaned up"
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "All post-uninstall verification checks passed"
    else
        log_warning "Post-uninstall verification found $issues issues"
        log_info "These issues may require manual cleanup"
    fi

    return 0
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Uninstallation Complete!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "VPN Management System has been uninstalled successfully!"
    echo ""

    local backup_dirs=("$HOME"/vpn-backup-*)
    if [[ -d "${backup_dirs[0]}" ]]; then
        local backup_dir
        backup_dir=$(find "$HOME" -name "vpn-backup-*" -type d | sort -r | head -1)
        echo -e "${BLUE}Backup Information:${NC}"
        echo "Your configuration files have been backed up to:"
        echo "  $backup_dir"
        echo ""
        log_info "You can restore these files if you reinstall the system later"
        echo ""
    fi

    echo -e "${YELLOW}What was removed:${NC}"
    echo "• VPN management scripts and utilities"
    echo "• Configuration and cache files"
    echo "• Shell PATH modifications"
    echo "• Temporary files and logs"
    echo ""

    echo -e "${YELLOW}What was preserved:${NC}"
    echo "• System packages (openvpn, curl, etc.)"
    echo "• Your personal data (backed up if found)"
    echo ""

    log_info "To completely remove system packages, see the package removal suggestions above"
    echo ""
    log_info "Thank you for using the VPN Management System!"
}

# Main uninstallation process
main() {
    print_banner

    log_info "Starting VPN Management System uninstallation..."

    # Confirm with user
    confirm_uninstall

    # Uninstallation steps
    disconnect_vpn
    cleanup_temp_files
    backup_user_data
    remove_path_modifications
    remove_vpn_directory
    check_package_removal

    # Verification
    run_post_uninstall_verification

    print_completion_message
}

# Run main function
main "$@"

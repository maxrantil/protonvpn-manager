#!/bin/bash
# ABOUTME: Security-hardened installation script for ProtonVPN Service
# ABOUTME: Replaces all hardcoded paths with FHS-compliant secure installation

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SERVICE_USER="protonvpn"
readonly SERVICE_GROUP="protonvpn"
readonly LOG_FILE="/tmp/protonvpn-secure-install.log"

# FHS-compliant paths (NO hardcoded development paths)
readonly CONFIG_DIR="/etc/protonvpn"
readonly LIB_DIR="/usr/local/lib/protonvpn"
readonly BIN_DIR="/usr/local/bin"
readonly VAR_DIR="/var/lib/protonvpn"
readonly LOG_DIR="/var/log/protonvpn"
readonly RUN_DIR="/run/protonvpn"

# Logging function
log_install() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Colored output functions
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root for secure installation"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Detect distribution and init system
detect_system() {
    log_install "INFO" "Detecting system configuration"

    # Detect distribution
    if command -v pacman >/dev/null 2>&1; then
        DISTRO="arch"
        PACKAGE_MANAGER="pacman"
    elif command -v apt >/dev/null 2>&1; then
        DISTRO="debian"
        PACKAGE_MANAGER="apt"
    else
        print_error "Unsupported distribution - requires Arch/Artix or Debian-based system"
        exit 1
    fi

    # Detect init system
    if command -v systemctl >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    elif command -v sv >/dev/null 2>&1; then
        INIT_SYSTEM="runit"
    else
        print_error "Unsupported init system - requires systemd or runit"
        exit 1
    fi

    print_info "Detected: $DISTRO with $INIT_SYSTEM"
    log_install "INFO" "System detected: $DISTRO ($PACKAGE_MANAGER) with $INIT_SYSTEM"
}

# Install system dependencies
install_dependencies() {
    log_install "INFO" "Installing system dependencies"
    print_info "Installing required packages..."

    case "$PACKAGE_MANAGER" in
        "pacman")
            pacman -Sy --noconfirm openvpn curl bc libnotify iproute2 git sqlite gnupg
            ;;
        "apt")
            apt update
            apt install -y openvpn curl bc libnotify-bin iproute2 git sqlite3 gnupg
            ;;
    esac

    print_success "System dependencies installed"
}

# Create service user with maximum security
create_service_user() {
    log_install "INFO" "Creating secure service user: $SERVICE_USER"

    if id "$SERVICE_USER" >/dev/null 2>&1; then
        print_warning "Service user already exists: $SERVICE_USER"
        # Ensure existing user has secure settings
        usermod --shell /bin/false --home "$VAR_DIR" "$SERVICE_USER"
    else
        # Create system user with maximum security restrictions
        useradd \
            --system \
            --shell /bin/false \
            --home-dir "$VAR_DIR" \
            --no-create-home \
            --comment "ProtonVPN Service User - Security Hardened" \
            "$SERVICE_USER"

        print_success "Service user created: $SERVICE_USER"
    fi

    # Ensure user is locked (no password login)
    passwd -l "$SERVICE_USER" >/dev/null 2>&1 || true

    log_install "INFO" "Service user configured securely"
}

# Create secure directory structure
create_secure_directories() {
    log_install "INFO" "Creating secure directory structure"
    print_info "Setting up FHS-compliant directory structure..."

    # Create all required directories
    mkdir -p "$CONFIG_DIR" "$LIB_DIR" "$BIN_DIR" "$VAR_DIR" "$LOG_DIR" "$RUN_DIR"
    mkdir -p "$VAR_DIR/databases" "$VAR_DIR/backups" "$VAR_DIR/cache" "$VAR_DIR/locations"

    # Set directory ownership
    chown root:root "$CONFIG_DIR" "$LIB_DIR" "$BIN_DIR"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$VAR_DIR" "$LOG_DIR" "$RUN_DIR"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$VAR_DIR"/{databases,backups,cache,locations}

    # Set secure permissions
    chmod 755 "$CONFIG_DIR" "$LIB_DIR" "$BIN_DIR"
    chmod 750 "$VAR_DIR" "$LOG_DIR" "$RUN_DIR"
    chmod 700 "$VAR_DIR/databases" "$VAR_DIR/backups"
    chmod 755 "$VAR_DIR/cache" "$VAR_DIR/locations"

    print_success "Secure directory structure created"
    log_install "INFO" "Directory structure: $CONFIG_DIR, $LIB_DIR, $BIN_DIR, $VAR_DIR, $LOG_DIR, $RUN_DIR"
}

# Install service binaries securely
install_service_binaries() {
    log_install "INFO" "Installing service binaries securely"
    print_info "Installing ProtonVPN service components..."

    # List of binaries to install
    local binaries=(
        "download-engine" "proton-auth" "proton-service"
        "secure-database-manager" "secure-config-manager"
        "protonvpn-updater-daemon-secure.sh"
        "vpn-notify" "vpn-logger" "vpn"
    )

    local installed_count=0

    for binary in "${binaries[@]}"; do
        local source_file="$SCRIPT_DIR/src/$binary"
        local target_file="$BIN_DIR/$binary"

        if [[ -f "$source_file" ]]; then
            # Copy binary
            cp "$source_file" "$target_file"

            # Set secure ownership and permissions
            chown root:root "$target_file"
            chmod 755 "$target_file"

            # Special handling for daemon script
            if [[ "$binary" == "protonvpn-updater-daemon-secure.sh" ]]; then
                # Create symlink with standard name
                ln -sf "$target_file" "$BIN_DIR/protonvpn-updater-daemon.sh"
            fi

            print_success "Installed: $binary"
            ((installed_count++))
        else
            print_warning "Binary not found: $binary (skipping)"
        fi
    done

    # Install library files
    if [[ -d "$SCRIPT_DIR" ]]; then
        print_info "Installing library files..."

        # Copy entire source structure (excluding sensitive files)
        rsync -av \
            --exclude='*.log' \
            --exclude='*.tmp' \
            --exclude='.git' \
            --exclude='__pycache__' \
            "$SCRIPT_DIR/" "$LIB_DIR/"

        # Fix ownership and permissions
        chown -R root:root "$LIB_DIR"
        find "$LIB_DIR" -type f -name "*.sh" -exec chmod 755 {} \;
        find "$LIB_DIR" -type f ! -name "*.sh" -exec chmod 644 {} \;

        print_success "Library files installed"
    fi

    print_success "Installed $installed_count service binaries"
    log_install "INFO" "Service binaries installed: $installed_count"
}

# Install secure configuration
install_secure_configuration() {
    log_install "INFO" "Installing secure configuration"
    print_info "Setting up secure configuration system..."

    # Run secure configuration manager
    if [[ -x "$BIN_DIR/secure-config-manager" ]]; then
        "$BIN_DIR/secure-config-manager" install "$SCRIPT_DIR"
        print_success "Secure configuration installed"
    else
        print_error "Secure configuration manager not found"
        return 1
    fi

    # Migrate legacy databases if they exist
    if [[ -x "$BIN_DIR/secure-database-manager" ]]; then
        "$BIN_DIR/secure-database-manager" migrate
        print_success "Database migration completed"
    else
        print_warning "Database manager not found - database features may not work"
    fi

    log_install "INFO" "Secure configuration and database setup completed"
}

# Install service files based on init system
install_service_files() {
    log_install "INFO" "Installing $INIT_SYSTEM service files"
    print_info "Setting up $INIT_SYSTEM service integration..."

    case "$INIT_SYSTEM" in
        "systemd")
            install_systemd_service
            ;;
        "runit")
            install_runit_service
            ;;
        *)
            print_error "Unsupported init system: $INIT_SYSTEM"
            return 1
            ;;
    esac

    print_success "Service files installed for $INIT_SYSTEM"
}

# Install systemd service
install_systemd_service() {
    local service_file="/etc/systemd/system/protonvpn-updater.service"

    cat > "$service_file" <<EOF
[Unit]
Description=ProtonVPN Config Updater (Security Hardened)
Documentation=https://github.com/maxrantil/protonvpn-manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
ExecStart=$BIN_DIR/protonvpn-updater-daemon.sh
Restart=always
RestartSec=30

# Security settings - Maximum hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$VAR_DIR $LOG_DIR $RUN_DIR
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
PrivateDevices=yes
ProtectClock=yes
ProtectHostname=yes
RemoveIPC=yes

# Network restrictions
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

# Resource limits
LimitNOFILE=512
MemoryLimit=25M
CPUQuota=5%
TasksMax=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=protonvpn-updater

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    systemctl daemon-reload

    print_success "Systemd service installed: $service_file"
}

# Install runit service
install_runit_service() {
    local runit_dir="/etc/runit/sv/protonvpn-updater"

    # Create service directory
    mkdir -p "$runit_dir/log"

    # Create main service script
    cat > "$runit_dir/run" <<EOF
#!/bin/sh
# ProtonVPN Config Updater - Runit service (Security Hardened)

# Load secure configuration
exec 2>&1
exec chpst -u $SERVICE_USER:$SERVICE_GROUP \\
    $BIN_DIR/protonvpn-updater-daemon.sh
EOF

    # Create log service script
    cat > "$runit_dir/log/run" <<EOF
#!/bin/sh
exec svlogd -tt $LOG_DIR
EOF

    # Set permissions
    chmod 755 "$runit_dir/run" "$runit_dir/log/run"

    print_success "Runit service installed: $runit_dir"
}

# Perform security validation
validate_security() {
    log_install "INFO" "Performing security validation"
    print_info "Validating security configuration..."

    local issues=0

    # Check for hardcoded development paths
    if grep -r "/home/user/workspace" "$CONFIG_DIR" "$BIN_DIR" "$LIB_DIR" 2>/dev/null; then
        print_error "SECURITY ISSUE: Hardcoded development paths found"
        ((issues++))
    fi

    # Check service user configuration
    if [[ "$(getent passwd "$SERVICE_USER" | cut -d: -f7)" != "/bin/false" ]]; then
        print_error "SECURITY ISSUE: Service user has login shell"
        ((issues++))
    fi

    # Check directory permissions
    for dir in "$VAR_DIR/databases" "$VAR_DIR/backups"; do
        local perms
        perms=$(stat -c "%a" "$dir" 2>/dev/null || echo "000")
        if [[ "$perms" != "700" ]]; then
            print_error "SECURITY ISSUE: Insecure permissions on $dir: $perms"
            ((issues++))
        fi
    done

    # Check binary ownership
    for binary in "$BIN_DIR"/proton*; do
        if [[ -f "$binary" ]]; then
            local owner
            owner=$(stat -c "%U" "$binary")
            if [[ "$owner" != "root" ]]; then
                print_error "SECURITY ISSUE: Binary not owned by root: $binary"
                ((issues++))
            fi
        fi
    done

    if [[ $issues -eq 0 ]]; then
        print_success "Security validation passed"
        return 0
    else
        print_error "Security validation failed: $issues issues found"
        return 1
    fi
}

# Create summary report
create_summary() {
    print_info "Installation Summary:"
    echo "===================="
    echo "Distribution: $DISTRO"
    echo "Init System: $INIT_SYSTEM"
    echo "Service User: $SERVICE_USER"
    echo "Configuration: $CONFIG_DIR"
    echo "Binaries: $BIN_DIR"
    echo "Data: $VAR_DIR"
    echo "Logs: $LOG_DIR"
    echo ""
    echo "Next Steps:"
    echo "1. Configure ProtonVPN credentials"
    echo "2. Start service: systemctl start protonvpn-updater (systemd)"
    echo "   OR: sv up protonvpn-updater (runit)"
    echo "3. Check status: $BIN_DIR/proton-service status"
    echo ""
    echo "Documentation: /usr/local/lib/protonvpn/README.md"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Installation failed with exit code: $exit_code"
        print_info "Check log file: $LOG_FILE"
    fi
    exit $exit_code
}

# Main installation function
main() {
    trap cleanup EXIT

    print_info "ProtonVPN Service - Security Hardened Installation"
    print_info "=================================================="

    log_install "INFO" "Starting security-hardened installation"

    # Pre-flight checks
    check_root
    detect_system

    # Installation steps
    install_dependencies
    create_service_user
    create_secure_directories
    install_service_binaries
    install_secure_configuration
    install_service_files

    # Validation
    if validate_security; then
        print_success "Security-hardened installation completed successfully"
        create_summary
        log_install "INFO" "Installation completed successfully"
    else
        print_error "Installation completed with security warnings"
        log_install "WARN" "Installation completed with security issues"
        exit 1
    fi
}

# Execute main function
main "$@"

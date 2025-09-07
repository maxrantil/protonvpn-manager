#!/bin/bash
# ABOUTME: Automated installation script for VPN Management System on Artix/Arch Linux

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPN_DIR="$HOME/workspace/claude-code/vpn"
LOCATIONS_DIR="$VPN_DIR/locations"
SRC_DIR="$VPN_DIR/src"

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              VPN Management System Installer              ║"
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

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root!"
        log_info "Run as regular user - sudo will be used when needed"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking system dependencies..."

    local missing_deps=()
    local deps=("pacman" "git" "sudo")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and run again"
        exit 1
    fi

    log_success "System dependencies check passed"
}

install_vpn_packages() {
    log_info "Installing VPN management packages..."

    local packages=("openvpn" "curl" "bc" "libnotify" "iproute2")
    local to_install=()

    # Check which packages are not installed
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"

        if sudo pacman -S --noconfirm "${to_install[@]}"; then
            log_success "VPN packages installed successfully"
        else
            log_error "Failed to install VPN packages"
            exit 1
        fi
    else
        log_success "All VPN packages already installed"
    fi
}

create_directory_structure() {
    log_info "Creating directory structure..."

    # Create main directory
    if [[ ! -d "$VPN_DIR" ]]; then
        mkdir -p "$VPN_DIR"
        log_success "Created VPN directory: $VPN_DIR"
    else
        log_info "VPN directory already exists: $VPN_DIR"
    fi

    # Create locations directory
    if [[ ! -d "$LOCATIONS_DIR" ]]; then
        mkdir -p "$LOCATIONS_DIR"
        log_success "Created locations directory: $LOCATIONS_DIR"
    else
        log_info "Locations directory already exists: $LOCATIONS_DIR"
    fi

    log_success "Directory structure created"
}

setup_scripts() {
    log_info "Setting up VPN management scripts..."

    if [[ ! -d "$SRC_DIR" ]]; then
        log_error "Source directory not found: $SRC_DIR"
        log_info "Make sure you've cloned the repository to the correct location"
        exit 1
    fi

    # Make all scripts executable
    if chmod +x "$SRC_DIR"/*; then
        log_success "Made all scripts executable"
    else
        log_error "Failed to make scripts executable"
        exit 1
    fi

    # Test main script
    if "$SRC_DIR/vpn" help &> /dev/null; then
        log_success "Main VPN script is working"
    else
        log_error "Main VPN script test failed"
        exit 1
    fi
}

setup_credentials() {
    log_info "Setting up credentials file..."

    local creds_file="$VPN_DIR/vpn-credentials.txt"

    if [[ ! -f "$creds_file" ]]; then
        log_warning "Credentials file not found, creating template"

        cat > "$creds_file" << 'EOF'
# ProtonVPN Credentials
# Replace these placeholder values with your actual ProtonVPN credentials
#
# Line 1: Your ProtonVPN username (usually starts with your account name)
# Line 2: Your ProtonVPN password
#
# Example:
# your-username+pm
# your-password-here
#
# IMPORTANT: Keep this file secure and never commit it to version control!

your-username-here
your-password-here
EOF

        # Set secure permissions
        chmod 600 "$creds_file"

        log_warning "Created credentials template: $creds_file"
        log_info "Please edit this file with your ProtonVPN credentials"
    else
        log_info "Credentials file already exists"

        # Ensure correct permissions
        chmod 600 "$creds_file"
        log_success "Secured credentials file permissions"
    fi
}

setup_locations_guide() {
    log_info "Creating locations setup guide..."

    local guide_file="$LOCATIONS_DIR/README.md"

    if [[ ! -f "$guide_file" ]]; then
        cat > "$guide_file" << 'EOF'
# VPN Locations Directory

This directory should contain your ProtonVPN OpenVPN configuration files (.ovpn files).

## Setup Instructions

1. **Download ProtonVPN configs**:
   - Log into your ProtonVPN account
   - Go to Downloads section
   - Download OpenVPN configuration files
   - Choose your preferred protocol (UDP recommended for speed)

2. **Copy files to this directory**:
   ```bash
   # Example: Copy all .ovpn files
   cp ~/Downloads/*.ovpn /path/to/vpn/locations/
   ```

3. **File naming convention**:
   ProtonVPN files typically follow this pattern:
   - `se-65.protonvpn.com.udp.ovpn` (Sweden server #65)
   - `nl-42.protonvpn.com.tcp.ovpn` (Netherlands server #42)
   - `ch-secure-core-01.protonvpn.com.udp.ovpn` (Secure Core)

4. **Verify installation**:
   ```bash
   # Should list your .ovpn files
   ls -la /path/to/vpn/locations/

   # Test VPN system
   ./src/vpn help
   ./src/vpn status
   ```

## Supported Countries

The VPN system supports connection by country code:
- `se` - Sweden
- `nl` - Netherlands
- `ch` - Switzerland
- `de` - Germany
- `us` - United States
- `jp` - Japan
- And many more...

## File Requirements

- Files must have `.ovpn` extension
- Files must be valid OpenVPN configuration files
- The system will automatically enhance configs with stability settings

## Security Note

Keep your OpenVPN configuration files secure. They contain server information
but not your credentials (which are stored separately in vpn-credentials.txt).
EOF

        log_success "Created locations setup guide: $guide_file"
    else
        log_info "Locations guide already exists"
    fi
}

add_to_path() {
    log_info "Adding VPN scripts to PATH..."

    local shell_rc=""
    local vpn_path_export="export PATH=\"$SRC_DIR:\$PATH\""

    # Determine shell configuration file
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi

    # Check if already added
    if grep -q "vpn.*PATH" "$shell_rc" 2>/dev/null; then
        log_info "PATH already configured in $shell_rc"
    else
        log_info "Adding to PATH in $shell_rc"
        {
            echo ""
            echo "# VPN Management System"
            echo "$vpn_path_export"
        } >> "$shell_rc"
        log_success "Added VPN scripts to PATH"
        log_info "Restart your shell or run: source $shell_rc"
    fi
}

run_post_install_tests() {
    log_info "Running post-installation tests..."

    # Test main script
    if "$SRC_DIR/vpn" help &> /dev/null; then
        log_success "✓ Main VPN script working"
    else
        log_error "✗ Main VPN script test failed"
        return 1
    fi

    # Test script permissions
    local scripts=("vpn" "vpn-manager" "vpn-connector" "best-vpn-profile")
    for script in "${scripts[@]}"; do
        if [[ -x "$SRC_DIR/$script" ]]; then
            log_success "✓ $script is executable"
        else
            log_error "✗ $script is not executable"
            return 1
        fi
    done

    # Test dependencies
    local deps=("openvpn" "curl" "bc" "notify-send")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "✓ $dep is available"
        else
            log_error "✗ $dep is missing"
            return 1
        fi
    done

    log_success "All post-installation tests passed"
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Installation Complete!                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "VPN Management System installed successfully!"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Copy your ProtonVPN .ovpn files to: $LOCATIONS_DIR"
    echo "2. Edit credentials file: $VPN_DIR/vpn-credentials.txt"
    echo "3. Test installation: $SRC_DIR/vpn help"
    echo "4. Connect to VPN: $SRC_DIR/vpn best"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "- Locations guide: $LOCATIONS_DIR/README.md"
    echo "- Main README: $VPN_DIR/README.md"
    echo "- Development guide: $VPN_DIR/CLAUDE.md"
    echo ""

    if [[ -f "$HOME/.bashrc" ]] || [[ -f "$HOME/.zshrc" ]]; then
        echo -e "${YELLOW}Note:${NC} VPN scripts added to PATH. Restart shell or run:"
        echo "source ~/.bashrc  # or ~/.zshrc"
        echo ""
    fi
}

# Main installation process
main() {
    print_banner

    log_info "Starting VPN Management System installation..."

    # Pre-flight checks
    check_root
    check_dependencies

    # Installation steps
    install_vpn_packages
    create_directory_structure
    setup_scripts
    setup_credentials
    setup_locations_guide
    add_to_path

    # Validation
    if run_post_install_tests; then
        print_completion_message
    else
        log_error "Post-installation tests failed!"
        log_info "Check the errors above and run the installer again"
        exit 1
    fi
}

# Run main function
main "$@"

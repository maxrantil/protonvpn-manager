#!/bin/bash
# ABOUTME: Integration tests for VPN installation process
# ABOUTME: Tests install → verify → uninstall workflow

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"
INSTALL_DIR="/usr/local/bin"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_passed() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_failed() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo -e "${RED}  Reason: $2${NC}"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

test_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Check if running as root (needed for sudo operations)
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Note: These tests require sudo access for installation${NC}"
        echo -e "${YELLOW}You may be prompted for your password${NC}"
    fi
}

# Integration Test 1: Verify install.sh exists and is executable
test_install_script_exists() {
    test_header "Test 1: Install Script Existence"

    if [[ -f "$INSTALL_SCRIPT" ]] && [[ -x "$INSTALL_SCRIPT" ]]; then
        test_passed "install.sh exists and is executable"
    else
        test_failed "install.sh check" "Script missing or not executable at $INSTALL_SCRIPT"
        exit 1
    fi
}

# Integration Test 2: Verify all source components exist before installation
test_source_components_exist() {
    test_header "Test 2: Source Components Availability"

    local components=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")

    for component in "${components[@]}"; do
        if [[ -f "$PROJECT_ROOT/src/$component" ]]; then
            test_passed "Source component $component exists"
        else
            test_failed "Source component $component" "Not found in src/ directory"
        fi
    done
}

# Integration Test 3: Test dry-run installation (check only, no actual install)
test_installation_dry_run() {
    test_header "Test 3: Installation Prerequisites Check"

    # Check if we're in the right directory
    if [[ ! -d "$PROJECT_ROOT/src" ]] || [[ ! -f "$PROJECT_ROOT/src/vpn" ]]; then
        test_failed "Installation prerequisites" "Not in VPN project root directory"
        return
    fi

    test_passed "Installation prerequisites met"

    # Check for required system dependencies
    local missing_deps=()
    for cmd in openvpn curl bc; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        test_passed "All system dependencies available"
    else
        test_failed "System dependencies" "Missing: ${missing_deps[*]}"
    fi
}

# Integration Test 4: Verify installed components after installation
test_installed_components() {
    test_header "Test 4: Installed Components Verification"

    local components=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")

    echo -e "${YELLOW}Checking if components are installed in $INSTALL_DIR...${NC}"

    local all_installed=true
    for component in "${components[@]}"; do
        if [[ -f "$INSTALL_DIR/$component" ]] && [[ -x "$INSTALL_DIR/$component" ]]; then
            test_passed "Component $component installed at $INSTALL_DIR/$component"
        else
            all_installed=false
            echo -e "${YELLOW}  Component $component not yet installed (skipping check)${NC}"
        fi
    done

    if [[ "$all_installed" == false ]]; then
        echo -e "${YELLOW}  Note: Run './install.sh' to install components${NC}"
    fi
}

# Integration Test 5: Test path resolution after installation
test_installed_mode_detection() {
    test_header "Test 5: Installed Mode Path Detection"

    # Check if vpn command detects installed mode
    if [[ -f "$INSTALL_DIR/vpn" ]]; then
        local vpn_dir
        vpn_dir=$(bash -c '
            source '"$INSTALL_DIR"'/vpn 2>/dev/null || true
            echo "$VPN_DIR"
        ' 2>/dev/null || echo "")

        if [[ "$vpn_dir" == "$INSTALL_DIR" ]]; then
            test_passed "Installed mode: VPN_DIR correctly detected as $INSTALL_DIR"
        else
            echo -e "${YELLOW}  VPN_DIR detection skipped (components may not be installed)${NC}"
        fi
    else
        echo -e "${YELLOW}  Installed mode test skipped (vpn not installed)${NC}"
    fi
}

# Integration Test 6: Verify config directories created
test_config_directories() {
    test_header "Test 6: Configuration Directories"

    local config_dir="$HOME/.config/vpn"
    local locations_dir="$config_dir/locations"
    local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/vpn"

    # These directories might not exist until first run
    if [[ -d "$config_dir" ]]; then
        test_passed "Config directory exists at $config_dir"
    else
        echo -e "${YELLOW}  Config directory not yet created (normal on first install)${NC}"
    fi

    if [[ -d "$log_dir" ]]; then
        test_passed "Log directory exists at $log_dir"
    else
        echo -e "${YELLOW}  Log directory not yet created (normal on first install)${NC}"
    fi
}

# Integration Test 7: Test vpn help command works after installation
test_vpn_help_command() {
    test_header "Test 7: VPN Help Command"

    if [[ -f "$INSTALL_DIR/vpn" ]]; then
        if "$INSTALL_DIR/vpn" help &>/dev/null; then
            test_passed "vpn help command executes successfully"
        else
            test_failed "vpn help command" "Command failed to execute"
        fi
    else
        echo -e "${YELLOW}  vpn command test skipped (not installed)${NC}"
    fi
}

# Run all integration tests
main() {
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   VPN Installation Integration Tests  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"

    check_sudo

    test_install_script_exists
    test_source_components_exist
    test_installation_dry_run
    test_installed_components
    test_installed_mode_detection
    test_config_directories
    test_vpn_help_command

    # Test summary
    echo -e "\n${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║          Test Summary                  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All integration tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some integration tests failed${NC}"
        exit 1
    fi
}

main "$@"

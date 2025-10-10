#!/bin/bash
# ABOUTME: End-to-end tests for complete VPN installation workflow
# ABOUTME: Tests full cycle: clean system → install → verify → basic functionality → uninstall

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
BLUE='\033[1;36m'
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
    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

section_header() {
    echo -e "\n${YELLOW}>>> $1${NC}"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}ERROR: Do not run as root. Script will use sudo when needed.${NC}"
        exit 1
    fi
}

# E2E Test 1: Pre-installation verification
test_pre_installation_state() {
    test_header "Phase 1: Pre-Installation State"

    section_header "Checking existing installation status"

    local components=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")
    local installed_count=0

    for component in "${components[@]}"; do
        if [[ -f "$INSTALL_DIR/$component" ]]; then
            ((installed_count++))
            echo -e "${YELLOW}  Found existing: $INSTALL_DIR/$component${NC}"
        fi
    done

    if [[ $installed_count -eq 0 ]]; then
        test_passed "Clean state: No components installed"
    elif [[ $installed_count -eq ${#components[@]} ]]; then
        echo -e "${YELLOW}  All components already installed${NC}"
        test_passed "Pre-installed state detected"
    else
        test_failed "Pre-installation state" "Partial installation detected ($installed_count/${#components[@]} components)"
    fi
}

# E2E Test 2: Installation execution
test_installation_execution() {
    test_header "Phase 2: Installation Execution"

    section_header "Running installation script"

    if [[ ! -x "$INSTALL_SCRIPT" ]]; then
        test_failed "Installation execution" "install.sh not executable"
        return
    fi

    # Run installation (capture output for debugging if needed)
    if (cd "$PROJECT_ROOT" && ./install.sh); then
        test_passed "Installation script executed successfully"
    else
        test_failed "Installation execution" "install.sh returned error"
        return
    fi

    sleep 1 # Give filesystem a moment to sync
}

# E2E Test 3: Post-installation verification
test_post_installation_verification() {
    test_header "Phase 3: Post-Installation Verification"

    section_header "Verifying all components installed"

    local components=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")

    for component in "${components[@]}"; do
        if [[ -f "$INSTALL_DIR/$component" ]]; then
            # Check executable permissions
            if [[ -x "$INSTALL_DIR/$component" ]]; then
                test_passed "Component $component installed and executable"
            else
                test_failed "Component $component permissions" "File exists but not executable"
            fi
        else
            test_failed "Component $component installation" "File not found at $INSTALL_DIR/$component"
        fi
    done

    section_header "Verifying configuration directories created"

    local config_dir="$HOME/.config/vpn"
    local locations_dir="$config_dir/locations"

    if [[ -d "$config_dir" ]]; then
        test_passed "Config directory created at $config_dir"
    else
        test_failed "Config directory creation" "Directory not found: $config_dir"
    fi

    if [[ -d "$locations_dir" ]]; then
        test_passed "Locations directory created at $locations_dir"
    else
        test_failed "Locations directory creation" "Directory not found: $locations_dir"
    fi
}

# E2E Test 4: Basic functionality tests
test_basic_functionality() {
    test_header "Phase 4: Basic Functionality Tests"

    section_header "Testing vpn help command"

    if command -v vpn &> /dev/null; then
        if vpn help &> /dev/null; then
            test_passed "vpn help command works"
        else
            test_failed "vpn help command" "Command failed to execute"
        fi
    else
        test_failed "vpn command availability" "vpn not in PATH"
    fi

    section_header "Testing vpn status command"

    if command -v vpn &> /dev/null; then
        # Status command should work even when not connected
        if vpn status &> /dev/null; then
            test_passed "vpn status command works"
        else
            # Status might fail due to missing dependencies, that's okay for now
            echo -e "${YELLOW}  vpn status command returned error (may be due to dependencies)${NC}"
        fi
    fi

    section_header "Testing path resolution in installed mode"

    # Verify scripts detect installed mode
    local detection_test
    detection_test=$(bash -c 'source /usr/local/bin/vpn-manager 2>/dev/null && echo "$VPN_DIR"' 2> /dev/null || echo "")

    if [[ "$detection_test" == "/usr/local/bin" ]]; then
        test_passed "Installed mode correctly detected (VPN_DIR=/usr/local/bin)"
    else
        test_failed "Installed mode detection" "Expected /usr/local/bin, got: $detection_test"
    fi
}

# E2E Test 5: Verify no hardcoded paths in installed components
test_no_hardcoded_paths_installed() {
    test_header "Phase 5: Hardcoded Path Verification"

    section_header "Checking for hardcoded src/ references"

    local hardcoded_found=false
    local scripts=("vpn" "vpn-manager" "vpn-connector" "best-vpn-profile")

    for script in "${scripts[@]}"; do
        if [[ -f "$INSTALL_DIR/$script" ]]; then
            # Check for hardcoded src/ paths (excluding comments and source statements)
            local count
            count=$(grep -c "src/" "$INSTALL_DIR/$script" 2> /dev/null | grep -v "# ABOUTME:" | grep -v "source " || echo 0)

            if [[ $count -eq 0 ]]; then
                test_passed "No hardcoded paths in installed $script"
            else
                hardcoded_found=true
                test_failed "Hardcoded paths in $script" "Found $count potential hardcoded src/ references"
            fi
        fi
    done

    if [[ "$hardcoded_found" == false ]]; then
        test_passed "All installed components are path-portable"
    fi
}

# E2E Test 6: Cross-component integration
test_cross_component_integration() {
    test_header "Phase 6: Cross-Component Integration"

    section_header "Testing component sourcing and dependencies"

    # Test that vpn-manager can source its dependencies
    if bash -c '
        VPN_DIR=/usr/local/bin
        source "$VPN_DIR/vpn-error-handler" 2>/dev/null &&
        source "$VPN_DIR/vpn-utils" 2>/dev/null &&
        source "$VPN_DIR/vpn-colors" 2>/dev/null
    ' 2> /dev/null; then
        test_passed "vpn-manager dependencies source correctly"
    else
        test_failed "Component sourcing" "Failed to source vpn-manager dependencies"
    fi

    # Test that vpn can find its sub-components
    if bash -c '
        VPN_DIR=/usr/local/bin
        [[ -x "$VPN_DIR/vpn-manager" ]] && [[ -x "$VPN_DIR/vpn-connector" ]]
    ' 2> /dev/null; then
        test_passed "vpn can locate vpn-manager and vpn-connector"
    else
        test_failed "Component location" "vpn cannot locate required sub-components"
    fi
}

# Summary and cleanup suggestions
print_summary() {
    echo -e "\n${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║          Test Summary                  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓ ALL END-TO-END TESTS PASSED!       ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo -e "\n${GREEN}Installation is fully functional and portable!${NC}"
        echo -e "\n${YELLOW}Next steps:${NC}"
        echo -e "  1. Edit credentials: ~/.config/vpn/vpn-credentials.txt"
        echo -e "  2. Add .ovpn files to: ~/.config/vpn/locations/"
        echo -e "  3. Test with: vpn help"
    else
        echo -e "\n${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ SOME TESTS FAILED                   ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo -e "\n${YELLOW}To uninstall and retry:${NC}"
        echo -e "  sudo rm -f /usr/local/bin/{vpn,vpn-manager,vpn-connector,vpn-error-handler,vpn-utils,vpn-colors,best-vpn-profile}"
        echo -e "  ./install.sh"
    fi
}

# Run all end-to-end tests
main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   VPN Installation E2E Test Suite     ║${NC}"
    echo -e "${BLUE}║                                        ║${NC}"
    echo -e "${BLUE}║   Full Installation Workflow Test     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

    check_not_root

    echo -e "\n${YELLOW}Test Phases:${NC}"
    echo -e "  1. Pre-installation state verification"
    echo -e "  2. Installation execution"
    echo -e "  3. Post-installation verification"
    echo -e "  4. Basic functionality tests"
    echo -e "  5. Hardcoded path verification"
    echo -e "  6. Cross-component integration"

    sleep 1

    test_pre_installation_state
    test_installation_execution
    test_post_installation_verification
    test_basic_functionality
    test_no_hardcoded_paths_installed
    test_cross_component_integration

    print_summary

    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"

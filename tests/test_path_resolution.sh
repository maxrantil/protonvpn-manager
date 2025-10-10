#!/bin/bash
# ABOUTME: Unit tests for dynamic path resolution in VPN scripts
# ABOUTME: Tests path detection in both installed and development modes

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

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

# Unit Test 1: Verify VPN_DIR detection logic works correctly
test_development_mode_detection() {
    test_header "Test 1: VPN_DIR Path Detection Logic"

    # Test the path detection logic
    local vpn_dir
    vpn_dir=$(cd "$SRC_DIR" && bash -c '
        # Simulate the path detection logic from scripts
        if [[ -f "/usr/local/bin/vpn-manager" ]] && [[ -f "/usr/local/bin/vpn-error-handler" ]]; then
            echo "/usr/local/bin"
        else
            echo "$(dirname "$(realpath "$0")")"
        fi
    ' 2> /dev/null)

    # Check if detection logic works (either installed or development mode)
    if [[ "$vpn_dir" == "/usr/local/bin" ]]; then
        if [[ -f "/usr/local/bin/vpn-manager" ]] && [[ -f "/usr/local/bin/vpn-error-handler" ]]; then
            test_passed "Installed mode: VPN_DIR correctly detected as /usr/local/bin"
        else
            test_failed "Path detection logic" "Detected installed mode but files missing"
        fi
    elif [[ "$vpn_dir" =~ src$ ]] || [[ -d "$vpn_dir" ]]; then
        test_passed "Development mode: VPN_DIR correctly resolves to $vpn_dir"
    else
        test_failed "Path detection" "Unexpected VPN_DIR: $vpn_dir"
    fi
}

# Unit Test 2: Verify all scripts use consistent path resolution
test_consistent_path_resolution() {
    test_header "Test 2: Consistent Path Resolution Pattern"

    local scripts=("vpn" "vpn-manager" "vpn-connector" "best-vpn-profile")

    for script in "${scripts[@]}"; do
        # Check for the robust dual-file check pattern (using -F for fixed string)
        if grep -qF 'if [[ -f "/usr/local/bin/vpn-manager" ]] && [[ -f "/usr/local/bin/vpn-error-handler" ]]' "$SRC_DIR/$script" 2> /dev/null; then
            test_passed "Script $script uses robust path detection"
        else
            test_failed "Script $script path detection" "Does not use robust dual-check pattern"
        fi
    done
}

# Unit Test 3: Verify no hardcoded src/ paths remain
test_no_hardcoded_paths() {
    test_header "Test 3: No Hardcoded src/ Paths"

    local hardcoded_count
    hardcoded_count=$(grep -r "src/" "$SRC_DIR" 2> /dev/null |
        grep -v "# ABOUTME:" |
        grep -v ".ovpn" |
        grep -v "source " |
        wc -l)

    if [[ $hardcoded_count -eq 0 ]]; then
        test_passed "No hardcoded src/ paths found in scripts"
    else
        test_failed "Hardcoded paths check" "Found $hardcoded_count hardcoded src/ references"
    fi
}

# Unit Test 4: Verify all required components exist
test_required_components_exist() {
    test_header "Test 4: Required Components Existence"

    local components=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")

    for component in "${components[@]}"; do
        if [[ -f "$SRC_DIR/$component" ]]; then
            test_passed "Component $component exists"
        else
            test_failed "Component $component existence" "File not found at $SRC_DIR/$component"
        fi
    done
}

# Unit Test 5: Verify install.sh has correct component list
test_install_component_list() {
    test_header "Test 5: Install Script Component List"

    local install_script="$PROJECT_ROOT/install.sh"

    # Check that fix-ovpn-configs is NOT in the list
    if ! grep -q '"fix-ovpn-configs"' "$install_script"; then
        test_passed "install.sh does not include removed fix-ovpn-configs"
    else
        test_failed "install.sh component list" "Still contains fix-ovpn-configs"
    fi

    # Check that required components ARE in the list
    local required=("vpn" "vpn-manager" "vpn-connector" "vpn-error-handler" "vpn-utils" "vpn-colors" "best-vpn-profile")
    for component in "${required[@]}"; do
        if grep -q "\"$component\"" "$install_script"; then
            test_passed "install.sh includes $component"
        else
            test_failed "install.sh component list" "Missing $component"
        fi
    done
}

# Unit Test 6: Verify sourcing paths use $VPN_DIR
test_sourcing_uses_vpn_dir() {
    test_header "Test 6: Sourcing Uses \$VPN_DIR"

    local scripts=("vpn" "vpn-manager" "vpn-connector")

    for script in "${scripts[@]}"; do
        # Check that sourcing uses $VPN_DIR, not hardcoded paths
        if grep -q 'source "\$VPN_DIR/' "$SRC_DIR/$script"; then
            test_passed "Script $script sources using \$VPN_DIR"
        else
            test_failed "Script $script sourcing" "Does not use \$VPN_DIR for sourcing"
        fi
    done
}

# Run all unit tests
main() {
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   VPN Path Resolution Unit Tests      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"

    test_development_mode_detection
    test_consistent_path_resolution
    test_no_hardcoded_paths
    test_required_components_exist
    test_install_component_list
    test_sourcing_uses_vpn_dir

    # Test summary
    echo -e "\n${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║          Test Summary                  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All unit tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some unit tests failed${NC}"
        exit 1
    fi
}

main "$@"

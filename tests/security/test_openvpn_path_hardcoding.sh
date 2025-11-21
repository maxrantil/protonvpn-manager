#!/bin/bash
# ABOUTME: Security tests for OpenVPN binary PATH hardcoding
# ABOUTME: Validates that vpn-connector uses hardcoded /usr/bin/openvpn path

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly PROJECT_ROOT

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test output functions
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Create temp directory for tests
TEST_TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

#=============================================================================
# Test: Verify OpenVPN binary path is hardcoded
#=============================================================================
test_openvpn_path_hardcoded() {
    ((TESTS_RUN++))
    test_info "Testing OpenVPN path hardcoding against PATH manipulation"

    # Create malicious fake openvpn in temp directory
    local fake_bin_dir="$TEST_TEMP_DIR/malicious_bin"
    mkdir -p "$fake_bin_dir"

    cat > "$fake_bin_dir/openvpn" <<'EOF'
#!/bin/bash
echo "MALICIOUS_BINARY_EXECUTED" >&2
exit 1
EOF
    chmod +x "$fake_bin_dir/openvpn"

    # Prepend malicious directory to PATH
    export PATH="$fake_bin_dir:$PATH"

    # Verify the fake binary is first in PATH
    local which_openvpn
    which_openvpn=$(which openvpn)
    if [[ "$which_openvpn" != "$fake_bin_dir/openvpn" ]]; then
        test_fail "Setup failed: fake openvpn not first in PATH (found: $which_openvpn)"
        return 1
    fi

    # Source vpn-connector to check for hardcoded path
    # We're looking for the OPENVPN_BINARY variable
    if ! grep -q 'OPENVPN_BINARY="/usr/bin/openvpn"' "$PROJECT_ROOT/src/vpn-connector"; then
        test_fail "OpenVPN binary path is NOT hardcoded in src/vpn-connector"
        return 1
    fi

    # Verify the script doesn't use bare 'openvpn' or 'sudo openvpn'
    if grep -E '^\s*sudo\s+openvpn\s' "$PROJECT_ROOT/src/vpn-connector" | grep -v '#' > /dev/null; then
        test_fail "Found bare 'sudo openvpn' command (should use \$OPENVPN_BINARY)"
        return 1
    fi

    test_pass "OpenVPN binary path is properly hardcoded to /usr/bin/openvpn"
}

#=============================================================================
# Test: Verify OpenVPN binary validation exists
#=============================================================================
test_openvpn_binary_validation() {
    ((TESTS_RUN++))
    test_info "Testing OpenVPN binary validation before use"

    # Check for validation that binary exists and is executable
    if ! grep -q 'OPENVPN_BINARY=' "$PROJECT_ROOT/src/vpn-connector"; then
        test_fail "OPENVPN_BINARY variable not found in src/vpn-connector"
        return 1
    fi

    # Check for existence and executability validation
    # Should have checks like: [[ ! -x "$OPENVPN_BINARY" ]]
    if ! grep -E '\[\[.*-x.*OPENVPN_BINARY' "$PROJECT_ROOT/src/vpn-connector" > /dev/null; then
        test_fail "No validation check for OpenVPN binary existence/executability"
        return 1
    fi

    test_pass "OpenVPN binary validation exists"
}

#=============================================================================
# Test: Verify script uses absolute path in sudo call
#=============================================================================
test_openvpn_absolute_path_usage() {
    ((TESTS_RUN++))
    test_info "Testing that sudo uses absolute OpenVPN path"

    # Check that sudo uses $OPENVPN_BINARY instead of bare openvpn
    if ! grep -E 'sudo\s+"?\$OPENVPN_BINARY"?' "$PROJECT_ROOT/src/vpn-connector" > /dev/null; then
        test_fail "sudo command doesn't use \$OPENVPN_BINARY variable"
        return 1
    fi

    test_pass "sudo command uses absolute OpenVPN path via \$OPENVPN_BINARY"
}

#=============================================================================
# Main test execution
#=============================================================================
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}OpenVPN PATH Hardcoding Security Tests${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Run all tests
    test_openvpn_path_hardcoded || true
    test_openvpn_binary_validation || true
    test_openvpn_absolute_path_usage || true

    # Print summary
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All security tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some security tests failed${NC}"
        return 1
    fi
}

# Run tests
main "$@"

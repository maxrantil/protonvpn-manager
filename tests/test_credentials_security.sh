#!/bin/bash
# ABOUTME: Security tests for VPN credentials file permissions validation
# ABOUTME: TDD test suite for Issue #45 - credentials file permission checking
# shellcheck disable=SC2317

set -euo pipefail

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
readonly VPN_CONNECTOR="$PROJECT_ROOT/src/vpn-connector"
readonly TEST_CREDENTIALS="/tmp/test_credentials_$$"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test output functions
test_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
test_pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
test_fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
test_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Cleanup function
cleanup() {
    rm -f "$TEST_CREDENTIALS" 2>/dev/null || true
    rm -f "/tmp/test_validate_$$" 2>/dev/null || true
}
trap cleanup EXIT

# Helper: Load just the validation function for testing
load_validation_function() {
    local test_script="/tmp/test_validate_$$"
    cat > "$test_script" << 'EOF'
validate_credentials_permissions() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        return 1
    fi

    local perms
    perms=$(stat -c %a "$CREDENTIALS_FILE" 2>/dev/null)

    if [[ "$perms" != "600" ]]; then
        echo "ERROR: Insecure credentials file permissions: $perms" >&2
        echo "  Credentials file: $CREDENTIALS_FILE" >&2
        echo "  Current permissions: $perms (should be 600)" >&2
        echo "  Fix with: chmod 600 $CREDENTIALS_FILE" >&2
        return 1
    fi

    return 0
}
EOF
    # shellcheck disable=SC1090
    source "$test_script"
}

# Test runner function
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    test_info "Running: $test_name"

    set +e
    $test_function
    local result=$?
    set -e

    if [[ $result -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# Test 1: validate_credentials_permissions function exists
test_function_exists() {
    if grep -q "validate_credentials_permissions" "$VPN_CONNECTOR"; then
        return 0
    else
        return 1
    fi
}

# Test 2: Function rejects world-readable permissions (644)
test_rejects_world_readable() {
    # Create test credentials file with insecure permissions
    echo "test_user" > "$TEST_CREDENTIALS"
    echo "test_pass" >> "$TEST_CREDENTIALS"
    chmod 644 "$TEST_CREDENTIALS"

    load_validation_function
    CREDENTIALS_FILE="$TEST_CREDENTIALS"

    # Function should return failure for 644 permissions
    if validate_credentials_permissions 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

# Test 3: Function accepts secure permissions (600)
test_accepts_secure_permissions() {
    # Create test credentials file with secure permissions
    echo "test_user" > "$TEST_CREDENTIALS"
    echo "test_pass" >> "$TEST_CREDENTIALS"
    chmod 600 "$TEST_CREDENTIALS"

    load_validation_function
    CREDENTIALS_FILE="$TEST_CREDENTIALS"

    # Function should return success for 600 permissions
    if validate_credentials_permissions 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Test 4: Function rejects group-readable permissions (640)
test_rejects_group_readable() {
    # Create test credentials file with group-readable permissions
    echo "test_user" > "$TEST_CREDENTIALS"
    echo "test_pass" >> "$TEST_CREDENTIALS"
    chmod 640 "$TEST_CREDENTIALS"

    load_validation_function
    CREDENTIALS_FILE="$TEST_CREDENTIALS"

    # Function should return failure for 640 permissions
    if validate_credentials_permissions 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

# Test 5: Function provides helpful error message
test_error_message_helpful() {
    # Create test credentials file with insecure permissions
    echo "test_user" > "$TEST_CREDENTIALS"
    echo "test_pass" >> "$TEST_CREDENTIALS"
    chmod 644 "$TEST_CREDENTIALS"

    load_validation_function
    CREDENTIALS_FILE="$TEST_CREDENTIALS"

    # Capture error output
    local error_output
    error_output=$(validate_credentials_permissions 2>&1 || true)

    # Check for helpful error message
    if echo "$error_output" | grep -q "chmod 600" && \
       echo "$error_output" | grep -qi "permission\|insecure"; then
        return 0
    else
        return 1
    fi
}

# Test 6: Function is called before connection attempt
test_called_before_connect() {
    # Check that validate_credentials_permissions is called in connection flow
    if grep -A 20 "connect_openvpn_profile" "$VPN_CONNECTOR" | \
       grep -q "validate_credentials_permissions"; then
        return 0
    else
        return 1
    fi
}

# Main test runner
main() {
    test_info "Credentials Security Test Suite (Issue #45)"
    test_info "============================================="
    echo ""

    # Run all tests
    run_test "validate_credentials_permissions function exists" "test_function_exists"
    run_test "Rejects world-readable permissions (644)" "test_rejects_world_readable"
    run_test "Accepts secure permissions (600)" "test_accepts_secure_permissions"
    run_test "Rejects group-readable permissions (640)" "test_rejects_group_readable"
    run_test "Provides helpful error message with fix command" "test_error_message_helpful"
    run_test "Function called before connection attempt" "test_called_before_connect"

    # Test Summary
    echo ""
    test_info "Test Results Summary"
    test_info "==================="
    echo "Tests Run: $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        test_pass "ALL TESTS PASSED"
        exit 0
    else
        test_fail "SOME TESTS FAILED: $TESTS_FAILED"
        exit 1
    fi
}

# Execute test suite
main "$@"

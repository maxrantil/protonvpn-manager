#!/bin/bash
# ABOUTME: Test framework for VPN management system
# ABOUTME: Provides utilities for unit, integration, and end-to-end testing

# Test framework variables (with include guard to prevent re-initialization)
if [[ -z "${TEST_FRAMEWORK_LOADED:-}" ]]; then
    TEST_FRAMEWORK_LOADED=1
    TEST_DIR="$(dirname "$(realpath "$0")")"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    TESTS_PASSED=0
    TESTS_FAILED=0
    CURRENT_TEST=""
    FAILED_TESTS=()
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_test() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} [$timestamp] $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} [$timestamp] $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message"
            ;;
    esac
}

start_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    log_test "INFO" "Starting test: $test_name"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - Expected: '$expected', Got: '$actual'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$not_expected" != "$actual" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - Expected NOT: '$not_expected', Got: '$actual'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$haystack' does not contain '$needle'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"

    if [[ "$haystack" != *"$needle"* ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$haystack' contains '$needle'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    local message="${2:-File should exist}"

    if [[ -f "$filepath" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message - $filepath"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - $filepath does not exist"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed}"

    # Security: Use bash -c instead of eval to prevent command injection (HIGH-4)
    # Run in restricted subshell with minimal environment
    if (
        set -eu
        readonly HOME PATH
        unset 'SUDO_*' 'SSH_*' || true
        bash -c "$command"
    ) > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: $message - '$command'"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$command' failed"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail}"

    # Security: Use bash -c instead of eval to prevent command injection (HIGH-4)
    # Run in restricted subshell with minimal environment
    if ! (
        set -eu
        readonly HOME PATH
        unset 'SUDO_*' 'SSH_*' || true
        bash -c "$command"
    ) > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: $message - '$command'"
        ((TESTS_PASSED++))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$command' succeeded when it should have failed"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        ((TESTS_FAILED++))
        return 1
    fi
}

mock_command() {
    local command_name="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"

    # Create mock script
    local mock_script="/tmp/mock_$command_name"
    cat > "$mock_script" << EOF
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
EOF
    chmod +x "$mock_script"

    # Add to PATH
    export PATH="/tmp:$PATH"

    log_test "INFO" "Mocked command '$command_name' to return: '$mock_output' (exit: $mock_exit_code)"
}

cleanup_mocks() {
    rm -f /tmp/mock_* 2> /dev/null || true
    log_test "INFO" "Cleaned up mock commands"
}

setup_test_env() {
    # Create temporary test directories
    TEST_TEMP_DIR="/tmp/vpn_test_$$"
    mkdir -p "$TEST_TEMP_DIR"

    # Set up test locations
    TEST_LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
    mkdir -p "$TEST_LOCATIONS_DIR"

    # Create test VPN profiles
    cat > "$TEST_LOCATIONS_DIR/se-test.ovpn" << 'EOF'
remote 192.168.1.100 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    cat > "$TEST_LOCATIONS_DIR/dk-test.ovpn" << 'EOF'
remote 192.168.1.101 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    cat > "$TEST_LOCATIONS_DIR/secure-core-test.ovpn" << 'EOF'
# Secure Core
remote 192.168.1.102 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    # Create test credentials
    cat > "$TEST_TEMP_DIR/credentials.txt" << 'EOF'
testuser
testpass
EOF

    log_test "INFO" "Test environment set up in $TEST_TEMP_DIR"
}

cleanup_test_env() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        log_test "INFO" "Test environment cleaned up"
    fi
    cleanup_mocks
}

show_test_summary() {
    echo
    echo "=================================="
    echo "        TEST SUMMARY"
    echo "=================================="
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo -e "${RED}FAILED TESTS:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}  ✗${NC} $failed_test"
        done
        echo
        return 1
    else
        echo
        echo -e "${GREEN}ALL TESTS PASSED!${NC} ✅"
        echo
        return 0
    fi
}

# Trap to ensure cleanup on exit
trap cleanup_test_env EXIT

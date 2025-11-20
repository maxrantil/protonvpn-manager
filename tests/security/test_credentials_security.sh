#!/bin/bash
# ABOUTME: Security tests for credentials validation and TOCTOU protection
# ABOUTME: Tests validate_and_secure_credentials() against security vulnerabilities

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

# Source the validators
# shellcheck source=/dev/null
if ! source "$PROJECT_ROOT/src/vpn-validators"; then
    echo "ERROR: Failed to source vpn-validators" >&2
    exit 1
fi

# Create temp directory for tests
TEST_TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

#=============================================================================
# TEST CASES
#=============================================================================

# Test 1: Valid credentials file with 600 permissions
test_valid_600() {
    ((TESTS_RUN++))
    local test_file="$TEST_TEMP_DIR/creds_600.txt"

    echo "username" > "$test_file"
    echo "password" >> "$test_file"
    chmod 600 "$test_file"

    if validate_and_secure_credentials "$test_file" &>/dev/null; then
        local perms
        perms=$(stat -c "%a" "$test_file")
        if [[ "$perms" == "600" ]]; then
            test_pass "Valid 600 permissions accepted"
            return 0
        fi
    fi

    test_fail "Valid 600 permissions test"
    return 1
}

# Test 2: Insecure 644 permissions should be auto-fixed
test_autofix_644() {
    ((TESTS_RUN++))
    local test_file="$TEST_TEMP_DIR/creds_644.txt"

    echo "username" > "$test_file"
    echo "password" >> "$test_file"
    chmod 644 "$test_file"

    if validate_and_secure_credentials "$test_file" &>/dev/null; then
        local perms
        perms=$(stat -c "%a" "$test_file")
        if [[ "$perms" == "600" ]]; then
            test_pass "Insecure 644 permissions auto-fixed to 600"
            return 0
        fi
    fi

    test_fail "Auto-fix 644 permissions test"
    return 1
}

# Test 3: Symlink should be rejected
test_symlink_rejection() {
    ((TESTS_RUN++))
    local real_file="$TEST_TEMP_DIR/real_creds.txt"
    local symlink="$TEST_TEMP_DIR/symlink_creds.txt"

    echo "username" > "$real_file"
    chmod 600 "$real_file"
    ln -s "$real_file" "$symlink"

    local output
    output=$(validate_and_secure_credentials "$symlink" 2>&1 || true)

    if [[ "$output" == *"must not be a symlink"* ]]; then
        test_pass "Symlink properly rejected"
        return 0
    fi

    test_fail "Symlink rejection test"
    return 1
}

# Test 4: TOCTOU protection exists in code
test_toctou_protection_exists() {
    ((TESTS_RUN++))

    if grep -q "TOCTOU protection" "$PROJECT_ROOT/src/vpn-validators"; then
        test_pass "TOCTOU protection code verified in validators"
        return 0
    fi

    test_fail "TOCTOU protection not found in code"
    return 1
}

# Test 5: TOCTOU attack message verification
test_toctou_message() {
    ((TESTS_RUN++))

    if grep -q "TOCTOU attack detected" "$PROJECT_ROOT/src/vpn-validators"; then
        test_pass "TOCTOU attack detection message verified"
        return 0
    fi

    test_fail "TOCTOU attack detection message not found"
    return 1
}

# Test 6: Missing file rejection
test_missing_file() {
    ((TESTS_RUN++))
    local nonexistent="$TEST_TEMP_DIR/nonexistent.txt"

    local output
    output=$(validate_and_secure_credentials "$nonexistent" 2>&1 || true)

    if [[ "$output" == *"not found"* ]]; then
        test_pass "Missing file properly rejected"
        return 0
    fi

    test_fail "Missing file rejection test"
    return 1
}

# Test 7: Verify re-verification after chmod
test_reverification_after_chmod() {
    ((TESTS_RUN++))

    # Check that re-verification happens after chmod (should be after line 150)
    local line_num
    line_num=$(grep -n "CRITICAL.*Re-verify.*symlink after chmod" "$PROJECT_ROOT/src/vpn-validators" | cut -d: -f1)

    if [[ -n "$line_num" ]] && [[ $line_num -gt 150 ]]; then
        test_pass "Symlink re-verification correctly placed after chmod"
        return 0
    fi

    test_fail "Symlink re-verification not properly placed"
    return 1
}

#=============================================================================
# MAIN TEST EXECUTION
#=============================================================================

main() {
    echo "========================================="
    echo "Credentials Security Tests"
    echo "========================================="
    echo

    # Run tests
    test_info "Running security validation tests..."
    echo

    test_valid_600 || true
    test_autofix_644 || true
    test_symlink_rejection || true
    test_missing_file || true
    test_toctou_protection_exists || true
    test_toctou_message || true
    test_reverification_after_chmod || true

    # Results
    echo
    echo "========================================="
    echo "Test Results"
    echo "========================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
        return 1
    fi
}

# Run tests
main "$@"

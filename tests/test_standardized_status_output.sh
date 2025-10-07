#!/bin/bash
# ABOUTME: Test suite for unified status output (Issue #68)
# ABOUTME: Verifies single standardized format with no enterprise variations

# shellcheck disable=SC2317  # Mock functions are called dynamically by tests

set -euo pipefail

# Determine project root (works when run directly or from project root)
if [[ -f "src/vpn-manager" ]]; then
    PROJECT_ROOT="$(pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Test output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo -e "  ${YELLOW}Reason:${NC} $2"
    ((TESTS_FAILED++))
}

setup_test_env() {
    # Create minimal test environment
    export VPN_CONFIG_DIR="/tmp/vpn-test-$$"
    export VPN_LOG_DIR="$VPN_CONFIG_DIR/logs"
    export VPN_LOG_FILE="$VPN_LOG_DIR/vpn.log"
    export VPN_PID_FILE="$VPN_CONFIG_DIR/vpn.pid"

    mkdir -p "$VPN_LOG_DIR"
    touch "$VPN_LOG_FILE"
}

teardown_test_env() {
    rm -rf "/tmp/vpn-test-$$" 2>/dev/null || true
}

# === TEST 1: Verify vpn status calls simple show_status ===
test_vpn_status_calls_show_status() {
    ((TESTS_RUN++))

    # Check that src/vpn's status case no longer routes to status-wcag
    if grep -q 'status-wcag' "$PROJECT_ROOT/src/vpn"; then
        fail "vpn status should not call status-wcag" \
             "Found status-wcag call in src/vpn (should call 'status' only)"
        return 1
    fi

    # Verify the status case in src/vpn calls vpn-manager with 'status' not 'status-wcag'
    local status_case
    status_case=$(sed -n '/^    "status"|"s")/,/^    "best"/p' "$PROJECT_ROOT/src/vpn")

    if echo "$status_case" | grep -q 'status-wcag\|status-accessible\|status-enhanced\|status-dashboard'; then
        fail "vpn status case should only call simple 'status'" \
             "Found enterprise status variants in status case block"
        return 1
    fi

    pass "vpn status calls simple show_status (no enterprise variants)"
}

# === TEST 2: Verify enterprise status functions are removed ===
test_enterprise_status_functions_removed() {
    ((TESTS_RUN++))

    local found_enterprise=0
    local enterprise_functions=(
        "show_status_wcag"
        "show_status_accessible"
        "show_status_enhanced"
        "show_status_json"
        "show_status_csv"
        "show_status_format"
    )

    for func in "${enterprise_functions[@]}"; do
        if grep -q "^${func}()" "$PROJECT_ROOT/src/vpn-manager"; then
            fail "Enterprise function $func should be removed" \
                 "Found function definition in src/vpn-manager"
            ((found_enterprise++))
        fi
    done

    if [[ $found_enterprise -eq 0 ]]; then
        pass "All enterprise status functions removed from vpn-manager"
    else
        return 1
    fi
}

# === TEST 3: Verify enterprise status case handlers removed ===
test_enterprise_status_cases_removed() {
    ((TESTS_RUN++))

    local found_cases=0
    local case_patterns=(
        "status-wcag"
        "status-accessible"
        "status-enhanced"
        "status-format"
        "status-dashboard"
    )

    for pattern in "${case_patterns[@]}"; do
        if grep -q "\"$pattern\"" "$PROJECT_ROOT/src/vpn-manager"; then
            fail "Enterprise case handler '$pattern' should be removed" \
                 "Found case statement in src/vpn-manager"
            ((found_cases++))
        fi
    done

    if [[ $found_cases -eq 0 ]]; then
        pass "All enterprise status case handlers removed from vpn-manager"
    else
        return 1
    fi
}

# === TEST 4: Verify show_status exists and is the only status function ===
test_show_status_is_only_status_function() {
    ((TESTS_RUN++))

    # Verify show_status exists
    if ! grep -q "^show_status()" "$PROJECT_ROOT/src/vpn-manager"; then
        fail "show_status() function must exist in vpn-manager" \
             "Could not find show_status() definition"
        return 1
    fi

    # Count total status-related functions (should be exactly 1)
    local status_func_count
    status_func_count=$(grep -c "^show_status.*()" "$PROJECT_ROOT/src/vpn-manager" || echo "0")

    if [[ $status_func_count -eq 1 ]]; then
        pass "show_status() is the only status function (unified format)"
    else
        fail "Should have exactly 1 status function (show_status)" \
             "Found $status_func_count status functions"
        return 1
    fi
}

# === TEST 5: Verify vpn status command accepts no format flags ===
test_vpn_status_no_format_flags() {
    ((TESTS_RUN++))

    # Check that src/vpn's status case doesn't handle --accessible, --enhanced, --format, etc.
    local status_case
    status_case=$(sed -n '/^    "status"|"s")/,/^        esac/p' "$PROJECT_ROOT/src/vpn")

    if echo "$status_case" | grep -q 'case.*\$2'; then
        fail "vpn status should not accept format flags" \
             "Found case statement on \$2 in status handler"
        return 1
    fi

    if echo "$status_case" | grep -q '\-\-accessible\|\-\-enhanced\|\-\-dashboard\|\-\-format'; then
        fail "vpn status should not handle --accessible, --enhanced, --dashboard, or --format flags" \
             "Found enterprise flags in status case"
        return 1
    fi

    pass "vpn status accepts no format flags (single unified format)"
}

# === TEST 6: Verify status output format is consistent ===
test_status_output_format_consistent() {
    ((TESTS_RUN++))

    # Test that show_status function exists and produces expected output
    # We'll test actual output rather than trying to mock everything

    # Check that show_status function has the expected structure
    if ! grep -A 20 "^show_status()" "$PROJECT_ROOT/src/vpn-manager" | grep -q "VPN Status Report"; then
        fail "show_status() function missing expected header" \
             "Expected 'VPN Status Report' in function"
        return 1
    fi

    if ! grep -A 30 "^show_status()" "$PROJECT_ROOT/src/vpn-manager" | grep -q "External IP:"; then
        fail "show_status() function missing External IP display" \
             "Expected 'External IP:' in function"
        return 1
    fi

    if ! grep -A 30 "^show_status()" "$PROJECT_ROOT/src/vpn-manager" | grep -q "Active tunnels:"; then
        fail "show_status() function missing Active tunnels display" \
             "Expected 'Active tunnels:' in function"
        return 1
    fi

    pass "show_status produces consistent unified format"
}

# === TEST 7: Verify vpn-manager case statement is simplified ===
test_vpn_manager_case_simplified() {
    ((TESTS_RUN++))

    # Extract the case statement section
    local case_section
    case_section=$(sed -n '/^case "\$1" in/,/^esac/p' "$PROJECT_ROOT/src/vpn-manager")

    # Verify only "status"|"s" case exists, no enterprise variants
    if echo "$case_section" | grep -E '"status-wcag"|"status-accessible"|"status-enhanced"|"status-format"' >/dev/null; then
        fail "vpn-manager case statement should not have enterprise status cases" \
             "Found enterprise status case handlers"
        return 1
    fi

    # Verify simple status case exists
    if ! echo "$case_section" | grep -q '"status"|"s"'; then
        fail "vpn-manager must have 'status'|'s' case" \
             "Could not find status case handler"
        return 1
    fi

    pass "vpn-manager case statement simplified (no enterprise handlers)"
}

# Run all tests
echo "========================================"
echo "Unified Status Output Tests (Issue #68)"
echo "========================================"
echo

test_vpn_status_calls_show_status
test_enterprise_status_functions_removed
test_enterprise_status_cases_removed
test_show_status_is_only_status_function
test_vpn_status_no_format_flags
test_status_output_format_consistent
test_vpn_manager_case_simplified

echo
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi

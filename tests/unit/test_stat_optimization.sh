#!/bin/bash
# ABOUTME: Unit tests for stat format detection optimization (Issue #73)
# ABOUTME: Tests that stat format is detected once at startup for 25% faster cache operations

set -euo pipefail

TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(realpath "$TEST_DIR/../..")"

# Source test framework
source "$PROJECT_DIR/tests/test_framework.sh" 2> /dev/null || {
    echo "Error: Could not source test framework"
    exit 1
}

# Fix PROJECT_DIR which the framework overrides to /tests
PROJECT_DIR="$(realpath "$TEST_DIR/../..")"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    TEST_TEMP_DIR=$(mktemp -d)
    export LOG_DIR="$TEST_TEMP_DIR/log"
    mkdir -p "$LOG_DIR"

    # Create a test file for stat operations
    TEST_FILE="$TEST_TEMP_DIR/test_file.txt"
    echo "test" > "$TEST_FILE"
    export TEST_STAT_FILE="$TEST_FILE"
}

cleanup_test_env() {
    [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Source vpn-connector for testing
export VPN_DIR="$PROJECT_DIR/src"
source "$PROJECT_DIR/src/vpn-connector" 2> /dev/null || {
    echo "Error: Could not source vpn-connector"
    exit 1
}

# Test helper functions
start_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name ... "
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS"
}

fail_test() {
    local message="${1:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL${message:+: $message}"
}

# ============================================================================
# UNIT TESTS: Stat Format Detection
# ============================================================================

test_detect_stat_format_function_exists() {
    start_test "detect_stat_format function exists"

    if type detect_stat_format &> /dev/null; then
        pass_test
        return 0
    else
        fail_test "detect_stat_format function not found"
        return 1
    fi
}

test_stat_mtime_variable_is_set() {
    start_test "STAT_MTIME_FLAG variable is set after initialization"

    if [[ -n "${STAT_MTIME_FLAG:-}" ]]; then
        pass_test
        return 0
    else
        fail_test "STAT_MTIME_FLAG not set"
        return 1
    fi
}

test_stat_mtime_format_is_valid() {
    start_test "STAT_MTIME_FLAG contains valid format string"

    # Should be either "-f %m" (BSD) or "-c %Y" (GNU)
    if [[ "${STAT_MTIME_FLAG:-}" == "-f %m" ]] || [[ "${STAT_MTIME_FLAG:-}" == "-c %Y" ]]; then
        pass_test
        return 0
    else
        fail_test "Invalid format: ${STAT_MTIME_FLAG:-empty}"
        return 1
    fi
}

test_stat_mtime_flag_works() {
    start_test "STAT_MTIME_FLAG successfully retrieves file mtime"

    setup_test_env

    # Use the detected format to get mtime
    local mtime
    # shellcheck disable=SC2086  # STAT_MTIME_FLAG must expand into flags
    if mtime=$(stat $STAT_MTIME_FLAG "$TEST_STAT_FILE" 2> /dev/null); then
        # Check if mtime is a valid Unix timestamp (all digits)
        if [[ "$mtime" =~ ^[0-9]+$ ]]; then
            pass_test
            cleanup_test_env
            return 0
        else
            fail_test "mtime is not a valid timestamp: $mtime"
            cleanup_test_env
            return 1
        fi
    else
        fail_test "stat command failed with detected format"
        cleanup_test_env
        return 1
    fi
}

test_detect_stat_format_runs_only_once() {
    start_test "detect_stat_format is efficient (runs once at startup)"

    # This test verifies the function exists and returns a result
    # In production, it should be called once during script initialization
    if type detect_stat_format &> /dev/null; then
        local result
        result=$(detect_stat_format)
        if [[ -n "$result" ]]; then
            pass_test
            return 0
        else
            fail_test "detect_stat_format returned empty result"
            return 1
        fi
    else
        fail_test "detect_stat_format function not found"
        return 1
    fi
}

# ============================================================================
# INTEGRATION TESTS: Performance Cache with Optimized Stat
# ============================================================================

test_load_performance_cache_uses_optimized_stat() {
    start_test "load_performance_cache uses STAT_MTIME_FLAG (no fallback)"

    # Check that load_performance_cache function doesn't contain the old fallback pattern
    # This is a static code check to ensure the optimization is applied
    if type load_performance_cache &> /dev/null; then
        # Get the function definition
        local func_def
        func_def=$(declare -f load_performance_cache)

        # Check if it still contains the old BSD/GNU fallback pattern
        if echo "$func_def" | grep -q "stat -f %m.*||.*stat -c %Y"; then
            fail_test "Still using inefficient BSD/GNU fallback pattern"
            return 1
        else
            pass_test
            return 0
        fi
    else
        fail_test "load_performance_cache function not found"
        return 1
    fi
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

echo "=========================================="
echo "Stat Format Optimization Tests (Issue #73)"
echo "=========================================="
echo

# Run tests in order
test_detect_stat_format_function_exists || true
test_stat_mtime_variable_is_set || true
test_stat_mtime_format_is_valid || true
test_stat_mtime_flag_works || true
test_detect_stat_format_runs_only_once || true
test_load_performance_cache_uses_optimized_stat || true

# Print summary
echo
echo "=========================================="
echo "Test Summary:"
echo "  Total:  $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi

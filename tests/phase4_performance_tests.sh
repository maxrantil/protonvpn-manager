#!/bin/bash
# ABOUTME: Phase 4.2 Server Performance Testing - TDD Tests
# ABOUTME: Tests for multi-server performance testing with scoring algorithm

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly EXPECTED_SCRIPT_PATH="$PROJECT_DIR/src/best-vpn-profile"

test_best_vpn_profile_script_exists() {
    start_test "best-vpn-profile script exists"

    if [[ -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: script not found at $EXPECTED_SCRIPT_PATH"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_help_command_shows_usage() {
    start_test "help command shows usage information"

    if [[ ! -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: script not found"
        return
    fi

    local output
    output=$("$EXPECTED_SCRIPT_PATH" help 2> /dev/null || true)

    if echo "$output" | grep -q "Usage:" && echo "$output" | grep -q "test"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: expected usage information with 'test' command"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cache_command_works() {
    start_test "cache command shows cache status"

    if [[ ! -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: script not found"
        return
    fi

    # Cache command should work even if no cache exists
    if timeout 10 "$EXPECTED_SCRIPT_PATH" cache > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: cache command should succeed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_best_command_returns_profile_name() {
    start_test "best command returns a profile name"

    if [[ ! -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: script not found"
        return
    fi

    # Mock some profiles for testing
    if [[ ! -d "$PROJECT_DIR/locations" ]]; then
        log_test "SKIP" "$CURRENT_TEST: no locations directory found"
        return
    fi

    local result
    result=$(timeout 30 "$EXPECTED_SCRIPT_PATH" best 2> /dev/null | tail -n1 || echo "")

    if [[ -n "$result" ]] && [[ "$result" != "" ]]; then
        log_test "PASS" "$CURRENT_TEST: got result '$result'"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: expected profile name, got empty result"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 4.2 tests
main() {
    log_test "INFO" "Starting Phase 4.2 Server Performance Testing Tests (TDD RED phase)"

    # These tests should FAIL initially (RED phase)
    test_best_vpn_profile_script_exists
    test_help_command_shows_usage
    test_cache_command_works
    test_best_command_returns_profile_name

    show_test_summary

    # Exit with failure if any tests failed (expected in RED phase)
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

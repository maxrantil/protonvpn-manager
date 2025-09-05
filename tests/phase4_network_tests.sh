#!/bin/bash
# ABOUTME: Phase 4.1 Network Connectivity Testing - TDD Tests
# ABOUTME: Tests for internet connectivity, latency testing, DNS resolution, and NetworkManager functionality

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly EXPECTED_SCRIPT_PATH="$PROJECT_DIR/src/vpn-network-test"

test_vpn_network_test_script_exists() {
    start_test "vpn-network-test script exists"

    if [[ -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: script not found at $EXPECTED_SCRIPT_PATH"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_connectivity_command_works() {
    start_test "connectivity command works with internet connection"

    if [[ ! -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: script not found"
        return
    fi

    # Test that connectivity command returns success (0) for working internet
    if timeout 10 "$EXPECTED_SCRIPT_PATH" connectivity >/dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: connectivity command should succeed with internet"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_latency_command_returns_number() {
    start_test "latency command returns numeric millisecond value"

    if [[ ! -f "$EXPECTED_SCRIPT_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: script not found"
        return
    fi

    local result
    result=$(timeout 10 "$EXPECTED_SCRIPT_PATH" latency 8.8.8.8 2>/dev/null | tail -n1)

    # Check if result is numeric
    if [[ "$result" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_test "PASS" "$CURRENT_TEST: got $result ms"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: expected numeric value, got '$result'"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 4.1 tests
main() {
    log_test "INFO" "Starting Phase 4.1 Network Connectivity Tests (TDD RED phase)"

    # These tests should FAIL initially (RED phase)
    test_vpn_network_test_script_exists
    test_connectivity_command_works
    test_latency_command_returns_number

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

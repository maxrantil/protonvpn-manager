#!/bin/bash
# ABOUTME: Phase 5.1 Fast Switching System - TDD Tests
# ABOUTME: Tests for optimized VPN switching with cache-based performance optimization

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_SCRIPT_PATH="$PROJECT_DIR/src/vpn"
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"
readonly BEST_VPN_PROFILE_PATH="$PROJECT_DIR/src/best-vpn-profile"

test_vpn_fast_command_exists() {
    start_test "vpn fast command exists in help"

    local help_output
    help_output=$("$VPN_SCRIPT_PATH" help 2>/dev/null || true)

    if echo "$help_output" | grep -q "fast.*Quick connect"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: 'fast' command not found in help"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_fast_routes_to_connector() {
    start_test "vpn fast routes to vpn-connector fast"

    # Check that vpn script routes fast command to vpn-connector
    if grep -q '"fast"' "$VPN_SCRIPT_PATH" && grep -q 'VPN_CONNECTOR.*fast' "$VPN_SCRIPT_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn script should route fast to vpn-connector"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_connector_has_fast_mode() {
    start_test "vpn-connector supports fast mode"

    local help_output
    help_output=$("$VPN_CONNECTOR_PATH" help 2>/dev/null || true)

    if echo "$help_output" | grep -q "fast"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn-connector should support fast mode"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_best_vpn_profile_supports_reduced_testing() {
    start_test "best-vpn-profile supports reduced profile testing"

    # Test that best-vpn-profile can be called with cache preference
    # This should work differently from regular 'best' command
    local result_cached result_fresh
    result_cached=$("$BEST_VPN_PROFILE_PATH" best 2>/dev/null || echo "FAILED")
    result_fresh=$("$BEST_VPN_PROFILE_PATH" fresh 2>/dev/null || echo "FAILED")

    if [[ "$result_cached" != "FAILED" ]] && [[ "$result_fresh" != "FAILED" ]]; then
        log_test "PASS" "$CURRENT_TEST: supports both cached and fresh modes"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should support both cached and fresh profile selection"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_fast_switching_with_country_filter() {
    start_test "fast switching supports country filtering"

    if [[ ! -f "$VPN_CONNECTOR_PATH" ]]; then
        log_test "SKIP" "$CURRENT_TEST: vpn-connector not found"
        return
    fi

    # Check that vpn-connector fast mode accepts country parameter
    local help_output
    help_output=$("$VPN_CONNECTOR_PATH" help 2>/dev/null || true)

    if echo "$help_output" | grep -q "fast.*country" || echo "$help_output" | grep -q "fast.*\[country\]"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: fast mode should accept country parameter"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cache_fallback_mechanism() {
    start_test "fast switching falls back to full testing when cache empty"

    # Clear cache first
    "$BEST_VPN_PROFILE_PATH" clear >/dev/null 2>&1 || true

    # Test that best command with empty cache works (should fall back)
    local result
    result=$("$BEST_VPN_PROFILE_PATH" best 2>/dev/null || echo "FAILED")

    if [[ "$result" != "FAILED" ]] && [[ -n "$result" ]]; then
        log_test "PASS" "$CURRENT_TEST: fallback mechanism works"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should fallback to full testing when cache empty"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 5.1 tests
main() {
    log_test "INFO" "Starting Phase 5.1 Fast Switching System Tests (TDD RED phase)"

    # These tests should initially FAIL (RED phase)
    test_vpn_fast_command_exists
    test_vpn_fast_routes_to_connector
    test_vpn_connector_has_fast_mode
    test_best_vpn_profile_supports_reduced_testing
    test_fast_switching_with_country_filter
    test_cache_fallback_mechanism

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

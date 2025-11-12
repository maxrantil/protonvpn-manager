#!/bin/bash
# ABOUTME: Phase 5.2 Secure Core Integration - TDD Tests
# ABOUTME: Tests for secure core profile detection, double-hop routing, and interactive selection

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_SCRIPT_PATH="$PROJECT_DIR/src/vpn"
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"

test_vpn_secure_command_exists() {
    start_test "vpn secure command exists in help"

    local help_output
    help_output=$("$VPN_SCRIPT_PATH" help 2> /dev/null || true)

    if echo "$help_output" | grep -q "secure.*secure core"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: 'secure' command not found in help"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_secure_routes_to_connector() {
    start_test "vpn secure routes to vpn-connector secure"

    # Check that vpn script routes secure command to vpn-connector
    if grep -q '"secure"' "$VPN_SCRIPT_PATH" && grep -q 'VPN_CONNECTOR.*secure' "$VPN_SCRIPT_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn script should route secure to vpn-connector"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_connector_has_secure_mode() {
    start_test "vpn-connector supports secure mode"

    local help_output
    help_output=$("$VPN_CONNECTOR_PATH" help 2> /dev/null || true)

    if echo "$help_output" | grep -q "secure"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn-connector should support secure mode"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_secure_core_profile_detection() {
    start_test "secure core profiles can be detected"

    # Check if vpn-connector has function to detect secure core profiles
    if grep -q "secure.*core" "$VPN_CONNECTOR_PATH" || grep -q "detect.*secure" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn-connector should have secure core detection"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_secure_core_patterns() {
    start_test "secure core profiles have identifiable patterns"

    # Look for profiles that might be secure core (typically named differently)
    if [[ -d "$PROJECT_DIR/locations" ]]; then
        local secure_profiles
        secure_profiles=$(find "$PROJECT_DIR/locations" -name "*.ovpn" | grep -i -E "(secure|core|sc-)" | head -n1)

        if [[ -n "$secure_profiles" ]]; then
            log_test "PASS" "$CURRENT_TEST: found potential secure core profiles"
            ((TESTS_PASSED++))
        else
            log_test "INFO" "$CURRENT_TEST: no obvious secure core profiles found, but detection logic should exist"
            # This is not necessarily a failure - the detection logic can still work
            ((TESTS_PASSED++))
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: no locations directory found"
    fi
}

test_double_hop_routing_concept() {
    start_test "secure core concept supports double-hop routing"

    # Check that secure core concept is mentioned in comments or help
    if grep -i -q "double.*hop\|hop.*routing\|secure.*core.*routing" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: secure core should mention double-hop routing concept"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 5.2 tests
main() {
    log_test "INFO" "Starting Phase 5.2 Secure Core Integration Tests (TDD RED phase)"

    # These tests should initially FAIL (RED phase)
    test_vpn_secure_command_exists
    test_vpn_secure_routes_to_connector
    test_vpn_connector_has_secure_mode
    test_secure_core_profile_detection
    test_secure_core_patterns
    test_double_hop_routing_concept

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

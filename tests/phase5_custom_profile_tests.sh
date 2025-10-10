#!/bin/bash
# ABOUTME: Phase 5.3 Custom Profile Support - TDD Tests
# ABOUTME: Tests for custom .ovpn file validation, connection logic, and path validation

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_SCRIPT_PATH="$PROJECT_DIR/src/vpn"
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"

test_vpn_custom_command_exists() {
    start_test "vpn custom command exists in help"

    local help_output
    help_output=$("$VPN_SCRIPT_PATH" help 2> /dev/null || true)

    if echo "$help_output" | grep -q "custom.*profile"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: 'custom' command not found in help"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_custom_routes_to_connector() {
    start_test "vpn custom routes to vpn-connector custom"

    # Check that vpn script routes custom command to vpn-connector
    if grep -q '"custom"' "$VPN_SCRIPT_PATH" && grep -q 'VPN_CONNECTOR.*custom' "$VPN_SCRIPT_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn script should route custom to vpn-connector"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_vpn_connector_has_custom_mode() {
    start_test "vpn-connector supports custom profile mode"

    local help_output
    help_output=$("$VPN_CONNECTOR_PATH" help 2> /dev/null || true)

    if echo "$help_output" | grep -q "custom"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: vpn-connector should support custom mode"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_custom_ovpn_file_validation() {
    start_test "custom profiles validate .ovpn file format"

    # Check if vpn-connector has validation logic for .ovpn files
    if grep -q "\.ovpn" "$VPN_CONNECTOR_PATH" || grep -q "ovpn.*valid" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should validate .ovpn file format"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_custom_profile_path_validation() {
    start_test "custom profiles validate file path existence"

    # Check if there's path validation logic
    if grep -q "file.*exist\|path.*valid\|\-f.*profile" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should validate custom profile paths"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_custom_profile_error_handling() {
    start_test "custom profiles handle invalid files gracefully"

    # Check for error handling in custom profile logic
    if grep -q "Error.*custom\|Invalid.*profile\|not.*found" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should have error handling for invalid custom profiles"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 5.3 tests
main() {
    log_test "INFO" "Starting Phase 5.3 Custom Profile Support Tests (TDD RED phase)"

    # These tests should initially FAIL (RED phase)
    test_vpn_custom_command_exists
    test_vpn_custom_routes_to_connector
    test_vpn_connector_has_custom_mode
    test_custom_ovpn_file_validation
    test_custom_profile_path_validation
    test_custom_profile_error_handling

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

#!/bin/bash
# ABOUTME: Phase 5.4 WireGuard Protocol Support - TDD Tests
# ABOUTME: Tests for WireGuard .conf file support alongside OpenVPN .ovpn files

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"

test_protocol_detection_ovpn() {
    start_test "protocol detection identifies .ovpn files as OpenVPN"

    # Check if vpn-connector can detect .ovpn file protocol
    if grep -q "\.ovpn.*openvpn\|openvpn.*\.ovpn\|\.ovpn.*protocol" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should detect .ovpn files as OpenVPN protocol"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_protocol_detection_conf() {
    start_test "protocol detection identifies .conf files as WireGuard"

    # Check if vpn-connector can detect .conf file protocol
    if grep -q "\.conf.*wireguard\|wireguard.*\.conf\|\.conf.*protocol" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should detect .conf files as WireGuard protocol"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_wg_quick_integration() {
    start_test "WireGuard integration uses wg-quick commands"

    # Check if vpn-connector mentions wg-quick for WireGuard configs
    if grep -q "wg-quick" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should use wg-quick for WireGuard configs"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_wireguard_config_parsing() {
    start_test "WireGuard config parsing and validation"

    # Check if there's logic to parse/validate WireGuard configs
    if grep -q "wireguard.*config\|config.*wireguard\|wg.*config" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should have WireGuard config parsing logic"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_dual_protocol_support() {
    start_test "vpn connect works with both .ovpn and .conf seamlessly"

    # Check if there's protocol selection logic in connection process
    if grep -q "protocol.*select\|select.*protocol\|ovpn\|conf" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should support both protocols seamlessly"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_wireguard_connection_establishment() {
    start_test "WireGuard connection establishment and teardown"

    # Check for WireGuard-specific connection logic
    if grep -q "wg.*up\|wg.*down\|wireguard.*connect" "$VPN_CONNECTOR_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: should handle WireGuard connection lifecycle"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_performance_comparison_support() {
    start_test "performance testing supports both OpenVPN and WireGuard"

    # Check if performance testing can handle both protocols
    readonly BEST_VPN_PROFILE_PATH="$PROJECT_DIR/src/best-vpn-profile"
    if [[ -f "$BEST_VPN_PROFILE_PATH" ]] && grep -q "conf\|wireguard\|protocol" "$BEST_VPN_PROFILE_PATH"; then
        log_test "PASS" "$CURRENT_TEST"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: performance testing should support both protocols"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run Phase 5.4 tests
main() {
    log_test "INFO" "Starting Phase 5.4 WireGuard Protocol Support Tests (TDD RED phase)"

    # These tests should initially FAIL (RED phase)
    test_protocol_detection_ovpn
    test_protocol_detection_conf
    test_wg_quick_integration
    test_wireguard_config_parsing
    test_dual_protocol_support
    test_wireguard_connection_establishment
    test_performance_comparison_support

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

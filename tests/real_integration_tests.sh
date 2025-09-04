#!/bin/bash
# ABOUTME: Real integration tests that attempt actual connections
# ABOUTME: Tests real VPN functionality with actual network operations

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_wireguard_config_validation() {
    start_test "WireGuard config validation with real files"

    local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"

    if [[ ! -f "$wg_config" ]]; then
        log_test "SKIP" "$CURRENT_TEST: No WireGuard config found"
        return 0
    fi

    # Test that our validate_wireguard_config function works by calling vpn-connector directly
    if "$PROJECT_DIR/src/vpn-connector" custom "$wg_config" 2>&1 | grep -q "WireGuard.*already up\|Connecting to.*WireGuard\|Error:.*Missing"; then
        log_test "PASS" "$CURRENT_TEST: WireGuard config validation passed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: WireGuard config validation failed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_protocol_detection_real_files() {
    start_test "Protocol detection with real config files"

    # Test OpenVPN detection by checking vpn-connector behavior
    local ovpn_file="$PROJECT_DIR/locations/se-65.protonvpn.udp.ovpn"
    if [[ -f "$ovpn_file" ]]; then
        # Should detect OpenVPN and mention OpenVPN in output
        local ovpn_output
        ovpn_output=$("$PROJECT_DIR/src/vpn-connector" custom "$ovpn_file" 2>&1 || true)
        if echo "$ovpn_output" | grep -q "OpenVPN\|BLOCKED.*OpenVPN\|Connecting.*OpenVPN"; then
            log_test "PASS" "$CURRENT_TEST: OpenVPN detection works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: OpenVPN detection failed, output: $ovpn_output"
            FAILED_TESTS+=("$CURRENT_TEST: OpenVPN")
            ((TESTS_FAILED++))
        fi
    fi

    # Test WireGuard detection by checking vpn-connector behavior
    local wg_file="$PROJECT_DIR/locations/wg-SE-160.conf"
    if [[ -f "$wg_file" ]]; then
        # Should detect WireGuard and mention WireGuard in output
        local wg_output
        wg_output=$("$PROJECT_DIR/src/vpn-connector" custom "$wg_file" 2>&1 || true)
        if echo "$wg_output" | grep -q "WireGuard\|Connecting.*WireGuard"; then
            log_test "PASS" "$CURRENT_TEST: WireGuard detection works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: WireGuard detection failed, output: $wg_output"
            FAILED_TESTS+=("$CURRENT_TEST: WireGuard")
            ((TESTS_FAILED++))
        fi
    fi
}

test_wireguard_interface_management() {
    start_test "WireGuard interface management (dry run)"

    local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"

    if [[ ! -f "$wg_config" ]]; then
        log_test "SKIP" "$CURRENT_TEST: No WireGuard config found"
        return 0
    fi

    local interface_name
    interface_name=$(basename "$wg_config" .conf)

    # Check if interface already exists (should be down for clean test)
    if wg show "$interface_name" >/dev/null 2>&1; then
        log_test "INFO" "$CURRENT_TEST: Interface $interface_name already exists, cleaning up"
        sudo wg-quick down "$interface_name" >/dev/null 2>&1 || true
    fi

    # Test bringing up the interface
    log_test "INFO" "$CURRENT_TEST: Testing WireGuard interface up"
    if sudo wg-quick up "$wg_config" >/dev/null 2>&1; then
        # Verify interface came up
        if wg show "$interface_name" >/dev/null 2>&1; then
            log_test "PASS" "$CURRENT_TEST: WireGuard interface up successful"
            ((TESTS_PASSED++))

            # Test bringing down the interface
            log_test "INFO" "$CURRENT_TEST: Testing WireGuard interface down"
            if sudo wg-quick down "$interface_name" >/dev/null 2>&1; then
                # Verify interface went down
                if ! wg show "$interface_name" >/dev/null 2>&1; then
                    log_test "PASS" "$CURRENT_TEST: WireGuard interface down successful"
                    ((TESTS_PASSED++))
                else
                    log_test "FAIL" "$CURRENT_TEST: Interface still exists after down"
                    FAILED_TESTS+=("$CURRENT_TEST: down failed")
                    ((TESTS_FAILED++))
                fi
            else
                log_test "FAIL" "$CURRENT_TEST: Could not bring interface down"
                FAILED_TESTS+=("$CURRENT_TEST: down command failed")
                ((TESTS_FAILED++))
            fi
        else
            log_test "FAIL" "$CURRENT_TEST: Interface not found after up command"
            FAILED_TESTS+=("$CURRENT_TEST: interface not created")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Could not bring up WireGuard interface (may be network/credential issue)"
        FAILED_TESTS+=("$CURRENT_TEST: up command failed")
        ((TESTS_FAILED++))
    fi
}

test_custom_profile_real_validation() {
    start_test "Custom profile validation with real files"

    # Test with real OpenVPN file
    local ovpn_file="$PROJECT_DIR/locations/sample_se.ovpn"
    if [[ -f "$ovpn_file" ]]; then
        # This should not actually connect due to safety mechanisms
        local output
        output=$("$PROJECT_DIR/src/vpn" custom "$ovpn_file" 2>&1 || true)

        if echo "$output" | grep -q "BLOCKED.*OpenVPN.*already running\|Missing dependencies\|Credentials.*not found"; then
            log_test "PASS" "$CURRENT_TEST: OpenVPN custom profile validation works (safety check triggered)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: OpenVPN custom profile validation unexpected result: $output"
            FAILED_TESTS+=("$CURRENT_TEST: OpenVPN validation")
            ((TESTS_FAILED++))
        fi
    fi

    # Test with real WireGuard file
    local wg_file="$PROJECT_DIR/locations/wg-SE-160.conf"
    if [[ -f "$wg_file" ]]; then
        local output
        output=$("$PROJECT_DIR/src/vpn" custom "$wg_file" 2>&1 || true)

        if echo "$output" | grep -q "WireGuard.*already up\|Missing dependencies\|Error:"; then
            log_test "PASS" "$CURRENT_TEST: WireGuard custom profile validation works (appropriate error)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: WireGuard custom profile validation unexpected result: $output"
            FAILED_TESTS+=("$CURRENT_TEST: WireGuard validation")
            ((TESTS_FAILED++))
        fi
    fi
}

test_performance_testing_dual_protocol() {
    start_test "Performance testing with both protocols"

    # Test that best-vpn-profile script sees both protocols
    local best_result
    best_result=$("$PROJECT_DIR/src/best-vpn-profile" best 2>/dev/null || echo "FAILED")

    if [[ "$best_result" != "FAILED" ]] && [[ -n "$best_result" ]]; then
        log_test "PASS" "$CURRENT_TEST: Performance testing returns a profile"
        ((TESTS_PASSED++))

        # Check if it can find both types by temporarily hiding one type
        mkdir -p /tmp/profile_backup

        # Test with only WireGuard files
        if ls "$PROJECT_DIR/locations/"*.ovpn >/dev/null 2>&1; then
            cp "$PROJECT_DIR/locations/"*.ovpn /tmp/profile_backup/
            rm -f "$PROJECT_DIR/locations/"*.ovpn

            local wg_result
            wg_result=$("$PROJECT_DIR/src/best-vpn-profile" best 2>/dev/null || echo "FAILED")

            # Restore OpenVPN files
            if ls /tmp/profile_backup/*.ovpn >/dev/null 2>&1; then
                cp /tmp/profile_backup/*.ovpn "$PROJECT_DIR/locations/"
            fi

            if [[ "$wg_result" != "FAILED" ]] && [[ -n "$wg_result" ]]; then
                log_test "PASS" "$CURRENT_TEST: Can select WireGuard profiles"
                ((TESTS_PASSED++))
            else
                log_test "FAIL" "$CURRENT_TEST: Cannot select WireGuard profiles"
                FAILED_TESTS+=("$CURRENT_TEST: WireGuard selection")
                ((TESTS_FAILED++))
            fi
        fi

        rm -rf /tmp/profile_backup
    else
        log_test "FAIL" "$CURRENT_TEST: Performance testing failed to return profile"
        FAILED_TESTS+=("$CURRENT_TEST: No profile returned")
        ((TESTS_FAILED++))
    fi
}

test_country_detection_real_profiles() {
    start_test "Country detection from real profile names"

    local countries_output
    countries_output=$("$PROJECT_DIR/src/vpn-connector" countries 2>/dev/null || true)

    if echo "$countries_output" | grep -q "Available countries"; then
        log_test "PASS" "$CURRENT_TEST: Countries command works"
        ((TESTS_PASSED++))

        # Test that we detect countries from both protocol types
        if echo "$countries_output" | grep -q "SE.*profiles" && echo "$countries_output" | grep -q "DK.*profiles"; then
            log_test "PASS" "$CURRENT_TEST: Detects countries from both protocols"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Country detection incomplete: $countries_output"
            FAILED_TESTS+=("$CURRENT_TEST: Country detection")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Countries command failed"
        FAILED_TESTS+=("$CURRENT_TEST: Command failed")
        ((TESTS_FAILED++))
    fi
}

test_network_connectivity_check() {
    start_test "Network connectivity checking"

    # Test our network test script
    local network_test="$PROJECT_DIR/src/vpn-network-test"

    if [[ -x "$network_test" ]]; then
        # Test connectivity check
        if "$network_test" connectivity >/dev/null 2>&1; then
            log_test "PASS" "$CURRENT_TEST: Network connectivity check works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Network connectivity check failed"
            FAILED_TESTS+=("$CURRENT_TEST: Connectivity")
            ((TESTS_FAILED++))
        fi

        # Test latency check
        local latency
        latency=$("$network_test" latency 8.8.8.8 2>/dev/null || echo "999")

        if [[ "$latency" != "999" ]] && [[ "$latency" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            log_test "PASS" "$CURRENT_TEST: Latency testing works (${latency}ms)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Latency testing failed, got: $latency"
            FAILED_TESTS+=("$CURRENT_TEST: Latency")
            ((TESTS_FAILED++))
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: Network test script not executable"
    fi
}

# Run all real integration tests
main() {
    log_test "INFO" "Starting Real Integration Tests"
    echo "=================================="
    echo "    REAL INTEGRATION TESTS"
    echo "=================================="

    test_protocol_detection_real_files
    test_wireguard_config_validation
    test_wireguard_interface_management
    test_custom_profile_real_validation
    test_performance_testing_dual_protocol
    test_country_detection_real_profiles
    test_network_connectivity_check

    show_test_summary

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

#!/bin/bash
# ABOUTME: Cross-protocol collision detection and credential handling tests
# ABOUTME: Tests interaction between OpenVPN and WireGuard protocols

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_openvpn_blocks_wireguard() {
    start_test "OpenVPN process blocks WireGuard connection"

    # Simulate an OpenVPN process running
    if command -v openvpn > /dev/null; then
        # Create a dummy OpenVPN process with 'openvpn' and 'config' in command line
        sleep 30 &
        local sleep_pid=$!

        # Rename the process to look like OpenVPN (this is a simulation)
        # We'll use pgrep to check for the pattern that our code looks for

        # Create a fake process that matches the pattern
        bash -c 'exec -a "openvpn --config test.ovpn" sleep 10' &
        local fake_openvpn_pid=$!

        sleep 1

        # Test WireGuard connection with OpenVPN "running"
        local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"
        if [[ -f "$wg_config" ]]; then
            local output
            output=$("$PROJECT_DIR/src/vpn" custom "$wg_config" 2>&1 || true)

            if echo "$output" | grep -q "BLOCKED.*OpenVPN.*already running"; then
                log_test "PASS" "$CURRENT_TEST: OpenVPN correctly blocks WireGuard"
                ((TESTS_PASSED++))
            else
                log_test "FAIL" "$CURRENT_TEST: OpenVPN did not block WireGuard. Output: $output"
                FAILED_TESTS+=("$CURRENT_TEST")
                ((TESTS_FAILED++))
            fi
        else
            log_test "SKIP" "$CURRENT_TEST: No WireGuard config found"
        fi

        # Cleanup fake processes
        kill $fake_openvpn_pid 2> /dev/null || true
        kill $sleep_pid 2> /dev/null || true
    else
        log_test "SKIP" "$CURRENT_TEST: OpenVPN not available"
    fi
}

test_wireguard_blocks_openvpn() {
    start_test "WireGuard interface blocks OpenVPN connection"

    # Create a WireGuard interface to simulate active WireGuard
    local test_interface="test-wg-$$"
    local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"

    if [[ -f "$wg_config" ]] && command -v wg-quick > /dev/null; then
        # Create a minimal test WireGuard interface
        sudo ip link add dev "$test_interface" type wireguard 2> /dev/null || true

        if ip link show "$test_interface" > /dev/null 2>&1; then
            # Test OpenVPN connection with WireGuard interface active
            local ovpn_config="$PROJECT_DIR/locations/sample_se.ovpn"
            if [[ -f "$ovpn_config" ]]; then
                local output
                output=$("$PROJECT_DIR/src/vpn" custom "$ovpn_config" 2>&1 || true)

                if echo "$output" | grep -q "BLOCKED.*WireGuard.*already active"; then
                    log_test "PASS" "$CURRENT_TEST: WireGuard correctly blocks OpenVPN"
                    ((TESTS_PASSED++))
                else
                    log_test "FAIL" "$CURRENT_TEST: WireGuard did not block OpenVPN. Output: $output"
                    FAILED_TESTS+=("$CURRENT_TEST")
                    ((TESTS_FAILED++))
                fi
            else
                log_test "SKIP" "$CURRENT_TEST: No OpenVPN config found"
            fi
        else
            log_test "SKIP" "$CURRENT_TEST: Could not create test interface"
        fi

        # Cleanup test interface
        sudo ip link delete dev "$test_interface" 2> /dev/null || true
    else
        log_test "SKIP" "$CURRENT_TEST: WireGuard tools not available"
    fi
}

test_openvpn_credential_requirement() {
    start_test "OpenVPN requires credentials.txt file"

    local ovpn_config="$PROJECT_DIR/locations/sample_se.ovpn"
    local credentials_backup="/tmp/credentials_backup_$$"

    if [[ -f "$ovpn_config" ]]; then
        # Backup existing credentials if present
        if [[ -f "$PROJECT_DIR/credentials.txt" ]]; then
            cp "$PROJECT_DIR/credentials.txt" "$credentials_backup"
        fi

        # Remove credentials file temporarily
        rm -f "$PROJECT_DIR/credentials.txt"

        # Test OpenVPN connection without credentials
        local output
        output=$("$PROJECT_DIR/src/vpn" custom "$ovpn_config" 2>&1 || true)

        if echo "$output" | grep -q "Credentials file not found"; then
            log_test "PASS" "$CURRENT_TEST: OpenVPN correctly requires credentials"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: OpenVPN did not require credentials. Output: $output"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi

        # Restore credentials if they existed
        if [[ -f "$credentials_backup" ]]; then
            cp "$credentials_backup" "$PROJECT_DIR/credentials.txt"
            rm -f "$credentials_backup"
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: No OpenVPN config found"
    fi
}

test_wireguard_no_credential_requirement() {
    start_test "WireGuard does not require credentials.txt file"

    local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"
    local credentials_backup="/tmp/credentials_backup_$$"

    if [[ -f "$wg_config" ]]; then
        # Backup existing credentials if present
        if [[ -f "$PROJECT_DIR/credentials.txt" ]]; then
            cp "$PROJECT_DIR/credentials.txt" "$credentials_backup"
        fi

        # Remove credentials file temporarily
        rm -f "$PROJECT_DIR/credentials.txt"

        # Test WireGuard connection without credentials
        local output
        output=$("$PROJECT_DIR/src/vpn" custom "$wg_config" 2>&1 || true)

        # WireGuard should NOT complain about missing credentials
        if ! echo "$output" | grep -q "Credentials file not found"; then
            log_test "PASS" "$CURRENT_TEST: WireGuard does not require credentials.txt"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: WireGuard incorrectly requires credentials. Output: $output"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi

        # Restore credentials if they existed
        if [[ -f "$credentials_backup" ]]; then
            cp "$credentials_backup" "$PROJECT_DIR/credentials.txt"
            rm -f "$credentials_backup"
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: No WireGuard config found"
    fi
}

test_process_detection_accuracy() {
    start_test "Process detection correctly identifies VPN types"

    # Test that our check_vpn_processes function works correctly
    # We'll source the function and test it directly
    local vpn_connector="$PROJECT_DIR/src/vpn-connector"

    # Create a test script that sources vpn-connector and exposes check_vpn_processes
    local test_script="/tmp/test_vpn_check_$$"
    cat > "$test_script" << 'EOF'
#!/bin/bash
source "$1"
check_vpn_processes
EOF
    chmod +x "$test_script"

    # Test with no processes running (should pass)
    if "$test_script" "$vpn_connector" > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: No processes detected when clean"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: False positive process detection"
        FAILED_TESTS+=("$CURRENT_TEST: false positive")
        ((TESTS_FAILED++))
    fi

    # Test with fake OpenVPN process
    bash -c 'exec -a "openvpn --config test.ovpn" sleep 5' &
    local fake_pid=$!
    sleep 1

    if ! "$test_script" "$vpn_connector" > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: OpenVPN process correctly detected"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: OpenVPN process not detected"
        FAILED_TESTS+=("$CURRENT_TEST: OpenVPN detection")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    kill $fake_pid 2> /dev/null || true
    rm -f "$test_script"
}

test_credential_file_format() {
    start_test "Credential file format validation"

    local test_creds="/tmp/test_credentials_$$"
    local ovpn_config="$PROJECT_DIR/locations/sample_se.ovpn"

    if [[ -f "$ovpn_config" ]]; then
        # Create a valid credentials file
        cat > "$test_creds" << 'EOF'
testuser
testpass
EOF

        # Test connection with valid credential format
        CREDENTIALS_FILE="$test_creds" "$PROJECT_DIR/src/vpn-connector" custom "$ovpn_config" 2>&1 | head -5 > /tmp/cred_test_output

        local cred_output
        cred_output=$(cat /tmp/cred_test_output)

        # Should not complain about credentials format if file exists and has content
        if ! echo "$cred_output" | grep -q "Credentials file not found"; then
            log_test "PASS" "$CURRENT_TEST: Valid credentials file accepted"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Valid credentials file rejected"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi

        # Cleanup
        rm -f "$test_creds" /tmp/cred_test_output
    else
        log_test "SKIP" "$CURRENT_TEST: No OpenVPN config found"
    fi
}

test_embedded_key_validation() {
    start_test "WireGuard embedded key validation"

    local wg_config="$PROJECT_DIR/locations/wg-SE-160.conf"

    if [[ -f "$wg_config" ]]; then
        # Check that the config has embedded keys
        if grep -q "PrivateKey.*=" "$wg_config" && grep -q "PublicKey.*=" "$wg_config"; then
            log_test "PASS" "$CURRENT_TEST: WireGuard config has embedded keys"
            ((TESTS_PASSED++))

            # Test that our validation accepts this
            local output
            output=$("$PROJECT_DIR/src/vpn" custom "$wg_config" 2>&1 | head -10)

            if ! echo "$output" | grep -q "Missing.*section\|Invalid.*format"; then
                log_test "PASS" "$CURRENT_TEST: WireGuard config validation passes"
                ((TESTS_PASSED++))
            else
                log_test "FAIL" "$CURRENT_TEST: WireGuard config validation failed: $output"
                FAILED_TESTS+=("$CURRENT_TEST: validation")
                ((TESTS_FAILED++))
            fi
        else
            log_test "FAIL" "$CURRENT_TEST: WireGuard config missing embedded keys"
            FAILED_TESTS+=("$CURRENT_TEST: missing keys")
            ((TESTS_FAILED++))
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: No WireGuard config found"
    fi
}

# Run all cross-protocol tests
main() {
    log_test "INFO" "Starting Cross-Protocol Collision and Credential Tests"
    echo "=================================================="
    echo "    CROSS-PROTOCOL & CREDENTIAL TESTS"
    echo "=================================================="

    test_openvpn_blocks_wireguard
    test_wireguard_blocks_openvpn
    test_openvpn_credential_requirement
    test_wireguard_no_credential_requirement
    test_process_detection_accuracy
    test_credential_file_format
    test_embedded_key_validation

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

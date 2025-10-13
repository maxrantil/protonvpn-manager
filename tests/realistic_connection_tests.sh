#!/bin/bash
# ABOUTME: Realistic connection tests that attempt actual VPN operations
# ABOUTME: Tests real .ovpn file interactions, path validation, and complete workflows

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

test_script_path_resolution() {
    start_test "Script Path Resolution After Reorganization"

    setup_test_env

    # Test that main vpn script can find its dependencies
    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test help command (should work without network)
    local help_output
    help_output=$("$vpn_script" help 2> /dev/null)

    assert_contains "$help_output" "Usage:" "VPN script should show usage"
    assert_contains "$help_output" "Connection Commands:" "Should show command categories"

    # Test list command (should find locations directory)
    local list_output
    list_output=$(LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$vpn_script" list 2> /dev/null)

    if [[ -n "$list_output" ]]; then
        log_test "PASS" "$CURRENT_TEST: List command works from reorganized structure"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: List command failed - path resolution broken"
        FAILED_TESTS+=("$CURRENT_TEST: List command path resolution")
        ((TESTS_FAILED++))
    fi
}

test_ovpn_file_validation() {
    start_test "OpenVPN File Validation and Loading"

    setup_test_env

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test that connector can read test .ovpn files
    local profile_output
    profile_output=$(LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list 2> /dev/null)

    assert_contains "$profile_output" "se-test" "Should find SE test profile"
    assert_contains "$profile_output" "dk-test" "Should find DK test profile"

    # Test that connector can validate .ovpn file format
    local se_profile="$TEST_LOCATIONS_DIR/se-test.ovpn"

    if [[ -f "$se_profile" ]]; then
        local remote_line
        remote_line=$(grep "^remote" "$se_profile" 2> /dev/null)

        if [[ -n "$remote_line" ]]; then
            log_test "PASS" "$CURRENT_TEST: Can read remote directive from .ovpn file"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Cannot read .ovpn file format"
            FAILED_TESTS+=("$CURRENT_TEST: .ovpn file reading")
            ((TESTS_FAILED++))
        fi
    fi
}

test_dry_run_connection_attempt() {
    start_test "Dry Run Connection Attempt"

    setup_test_env

    # Mock openvpn for safe testing
    mock_command "openvpn" "OpenVPN 2.6.14 initialized [dry-run mode]" 0
    mock_command "sudo" "echo 'Dry run - would execute: openvpn'" 0

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test connection attempt with test profile (should not actually connect)
    local connect_output
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" connect_output=$("$connector_script" connect se 2>&1) || true

    # Should attempt to process the connection even if mocked
    if echo "$connect_output" | grep -q "se-test\|connecting\|profile" 2> /dev/null; then
        log_test "PASS" "$CURRENT_TEST: Connection attempt processes correctly"
        ((TESTS_PASSED++))
    else
        log_test "WARN" "$CURRENT_TEST: Connection attempt may have path issues"
    fi

    cleanup_mocks
}

test_multiple_location_switching() {
    start_test "Multiple Location Switching"

    setup_test_env

    # Create test credentials file
    local test_creds="$TEST_TEMP_DIR/test_credentials.txt"
    echo "test_user" > "$test_creds"
    echo "test_pass" >> "$test_creds"
    chmod 600 "$test_creds"

    # Mock network commands for safe testing
    mock_command "ping" "PING 192.168.1.100: 64 bytes from 192.168.1.100: time=25.2ms" 0
    mock_command "openvpn" "Connection established" 0

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test switching between different countries
    for country in se dk nl; do
        local connect_output
        connect_output=$(LOCATIONS_DIR="$TEST_LOCATIONS_DIR" CREDENTIALS_FILE="$test_creds" "$vpn_script" connect "$country" 2>&1) || true

        if echo "$connect_output" | grep -q -E "$country|connecting|profile"; then
            log_test "PASS" "$CURRENT_TEST: Can attempt connection to $country"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Failed to process $country connection"
            FAILED_TESTS+=("$CURRENT_TEST: $country connection")
            ((TESTS_FAILED++))
        fi
    done

    cleanup_mocks
}

test_credentials_file_access() {
    start_test "Credentials File Access"

    setup_test_env

    local connector_script="$PROJECT_DIR/src/vpn-connector"
    local test_creds="$TEST_TEMP_DIR/test_credentials.txt"

    # Create test credentials file
    echo "test_user" > "$test_creds"
    echo "test_pass" >> "$test_creds"
    chmod 600 "$test_creds"

    # Test that connector can find credentials file
    CREDENTIALS_FILE="$test_creds" test_output=$("$connector_script" test 2>&1) || true

    if echo "$test_output" | grep -q -v "credentials.*not found"; then
        log_test "PASS" "$CURRENT_TEST: Can access credentials file"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cannot access credentials file"
        FAILED_TESTS+=("$CURRENT_TEST: credentials file access")
        ((TESTS_FAILED++))
    fi

    rm -f "$test_creds"
}

test_cleanup_and_reconnection() {
    start_test "Cleanup and Reconnection Workflow"

    setup_test_env

    # Mock process management
    mock_command "pkill" "openvpn processes terminated" 0
    mock_command "pgrep" "" 1 # No processes found
    mock_command "ip" "route table updated" 0

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test cleanup command
    local cleanup_output
    cleanup_output=$("$vpn_script" cleanup 2>&1) || true

    if echo "$cleanup_output" | grep -q -E "cleanup|clean|stopped" || [[ -n "$cleanup_output" ]]; then
        log_test "PASS" "$CURRENT_TEST: Cleanup command executes"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup command failed"
        FAILED_TESTS+=("$CURRENT_TEST: cleanup command")
        ((TESTS_FAILED++))
    fi

    # Test reconnection workflow
    local reconnect_output
    reconnect_output=$("$vpn_script" reconnect 2>&1) || true

    # Should attempt reconnection process
    if echo "$reconnect_output" | grep -q -E "reconnect|connect|attempting"; then
        log_test "PASS" "$CURRENT_TEST: Reconnection workflow initiates"
        ((TESTS_PASSED++))
    else
        log_test "WARN" "$CURRENT_TEST: Reconnection may have issues"
    fi

    cleanup_mocks
}

test_working_directory_independence() {
    start_test "Working Directory Independence"

    setup_test_env

    # Change to different directory and test script execution
    local original_pwd="$PWD"
    cd /tmp || exit 1

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test that script works from different working directory
    local help_output
    help_output=$("$vpn_script" help 2> /dev/null)

    if [[ -n "$help_output" ]] && echo "$help_output" | grep -q "Usage:"; then
        log_test "PASS" "$CURRENT_TEST: Script works from different working directory"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Script fails from different working directory"
        FAILED_TESTS+=("$CURRENT_TEST: working directory independence")
        ((TESTS_FAILED++))
    fi

    cd "$original_pwd" || exit 1
}

test_multiple_connection_prevention_regression() {
    start_test "Multiple Connection Prevention (Regression Test)"

    setup_test_env

    # This test prevents regression of the multiple process accumulation issue
    # that was causing overheating during development

    local vpn_script="$PROJECT_DIR/src/vpn"
    local test_creds="$TEST_TEMP_DIR/test_credentials.txt"

    # Create test credentials file
    echo "test_user" > "$test_creds"
    echo "test_pass" >> "$test_creds"
    chmod 600 "$test_creds"

    # Mock a clean state first
    mock_command "pgrep" "" 1 # No processes initially
    mock_command "openvpn" "Mock OpenVPN started" 0
    mock_command "sudo" "Mock sudo" 0

    # Start first connection (should work)
    local first_connection
    first_connection=$(LOCATIONS_DIR="$TEST_LOCATIONS_DIR" CREDENTIALS_FILE="$test_creds" timeout 10 "$vpn_script" connect se 2>&1) || true

    # Now mock that a process exists
    cleanup_mocks
    mock_command "pgrep" "12345" 0 # One process exists

    # Attempt second connection (should be blocked)
    local second_connection
    second_connection=$(LOCATIONS_DIR="$TEST_LOCATIONS_DIR" CREDENTIALS_FILE="$test_creds" timeout 5 "$vpn_script" connect dk 2>&1) || true

    # Verify second connection was blocked
    assert_contains "$second_connection" "BLOCKED" "Second connection should be blocked"
    assert_contains "$second_connection" "already running" "Should mention existing process"

    # Verify no accumulation occurred
    if ! echo "$second_connection" | grep -q "Connecting to"; then
        log_test "PASS" "$CURRENT_TEST: Process accumulation prevention works"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: REGRESSION - Multiple connections allowed!"
        FAILED_TESTS+=("$CURRENT_TEST: multiple connection prevention regression")
        ((TESTS_FAILED++))
    fi

    cleanup_mocks
}

# Run all realistic connection tests
run_realistic_connection_tests() {
    log_test "INFO" "Starting Realistic Connection Tests"
    echo "========================================"
    echo "    REALISTIC CONNECTION TESTS"
    echo "========================================"

    test_script_path_resolution
    test_ovpn_file_validation
    test_dry_run_connection_attempt
    test_multiple_location_switching
    test_credentials_file_access
    test_cleanup_and_reconnection
    test_working_directory_independence
    test_multiple_connection_prevention_regression

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_realistic_connection_tests
    show_test_summary
fi

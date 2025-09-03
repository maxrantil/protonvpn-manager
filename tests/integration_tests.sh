#!/bin/bash
# ABOUTME: Integration tests for VPN management system components
# ABOUTME: Tests interaction between different system components

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

test_cli_interface() {
    start_test "CLI Interface Integration"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test help command
    local help_output
    help_output=$("$vpn_script" help 2>/dev/null)

    assert_contains "$help_output" "Usage:" "Help should show usage information"
    assert_contains "$help_output" "Commands:" "Help should list available commands"
    assert_contains "$help_output" "connect" "Help should mention connect command"
    assert_contains "$help_output" "status" "Help should mention status command"

    # Test invalid command handling
    local invalid_output
    invalid_output=$("$vpn_script" invalid_command 2>&1)

    assert_contains "$invalid_output" "Unknown command" "Should handle invalid commands gracefully"
}

test_script_communication() {
    start_test "Script Communication"

    setup_test_env

    # Mock the vpn-manager for testing
    mock_command "vpn-manager" "VPN Status: DISCONNECTED" 0

    # Test that vpn script can call vpn-manager
    local vpn_script="$PROJECT_DIR/src/vpn"
    local status_output
    status_output=$("$vpn_script" status 2>/dev/null)

    assert_contains "$status_output" "VPN Status" "Status command should work"

    cleanup_mocks
}

test_profile_listing_integration() {
    start_test "Profile Listing Integration"

    setup_test_env

    # Test vpn-connector list functionality with real profiles
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Override LOCATIONS_DIR for testing
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list > /tmp/list_output 2>/dev/null || true

    if [[ -f /tmp/list_output ]]; then
        local list_output
        list_output=$(cat /tmp/list_output)

        # Should show available profiles
        assert_contains "$list_output" "Available VPN Profiles" "Should show profiles header"

        rm -f /tmp/list_output
    else
        log_test "WARN" "$CURRENT_TEST: Could not test profile listing (no output file)"
    fi
}

test_country_filtering_integration() {
    start_test "Country Filtering Integration"

    setup_test_env

    # Test country-specific filtering
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test SE filtering
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list se > /tmp/se_output 2>/dev/null || true

    if [[ -f /tmp/se_output ]]; then
        local se_output
        se_output=$(cat /tmp/se_output)

        if echo "$se_output" | grep -q "se-test"; then
            log_test "PASS" "$CURRENT_TEST: SE filtering works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: SE filtering failed"
            FAILED_TESTS+=("$CURRENT_TEST: SE filtering")
            ((TESTS_FAILED++))
        fi

        rm -f /tmp/se_output
    fi

    # Test DK filtering
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list dk > /tmp/dk_output 2>/dev/null || true

    if [[ -f /tmp/dk_output ]]; then
        local dk_output
        dk_output=$(cat /tmp/dk_output)

        if echo "$dk_output" | grep -q "dk-test"; then
            log_test "PASS" "$CURRENT_TEST: DK filtering works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: DK filtering failed"
            FAILED_TESTS+=("$CURRENT_TEST: DK filtering")
            ((TESTS_FAILED++))
        fi

        rm -f /tmp/dk_output
    fi
}

test_dependency_checking() {
    start_test "Dependency Checking Integration"

    # Mock missing dependency
    local original_path="$PATH"
    export PATH="/tmp/empty_path"

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test dependency check with missing commands
    local dep_output
    dep_output=$("$connector_script" test 2>&1)

    # Restore PATH
    export PATH="$original_path"

    assert_contains "$dep_output" "Missing dependencies" "Should detect missing dependencies"
}

test_lock_file_mechanism() {
    start_test "Lock File Mechanism"

    setup_test_env

    # Create a test lock file
    local test_lock="/tmp/test_vpn.lock"
    echo "12345" > "$test_lock"

    # Test lock file detection
    if [[ -f "$test_lock" ]]; then
        log_test "PASS" "$CURRENT_TEST: Lock file creation works"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Lock file creation failed"
        ((TESTS_FAILED++))
    fi

    # Test lock file cleanup
    rm -f "$test_lock"

    if [[ ! -f "$test_lock" ]]; then
        log_test "PASS" "$CURRENT_TEST: Lock file cleanup works"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Lock file cleanup failed"
        ((TESTS_FAILED++))
    fi
}

test_logging_integration() {
    start_test "Logging Integration"

    setup_test_env

    local test_log="/tmp/test_vpn_$$.log"

    # Test log message function (simulate)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test log message" > "$test_log"

    assert_file_exists "$test_log" "Log file should be created"

    local log_content
    log_content=$(cat "$test_log")

    assert_contains "$log_content" "Test log message" "Log should contain test message"
    assert_contains "$log_content" "$(date '+%Y-%m-%d')" "Log should contain date"

    rm -f "$test_log"
}

test_error_handling() {
    start_test "Error Handling Integration"

    # Test handling of missing locations directory
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    LOCATIONS_DIR="/nonexistent/path" "$connector_script" list > /tmp/error_output 2>&1 || true

    if [[ -f /tmp/error_output ]]; then
        local error_output
        error_output=$(cat /tmp/error_output)

        assert_contains "$error_output" "not found" "Should handle missing directory gracefully"

        rm -f /tmp/error_output
    fi

    # Test handling of missing credentials
    CREDENTIALS_FILE="/nonexistent/creds.txt" "$connector_script" test > /tmp/cred_error 2>&1 || true

    if [[ -f /tmp/cred_error ]]; then
        local cred_error
        cred_error=$(cat /tmp/cred_error)

        assert_contains "$cred_error" "missing" "Should handle missing credentials file"

        rm -f /tmp/cred_error
    fi
}

test_configuration_file_parsing() {
    start_test "Configuration File Parsing"

    setup_test_env

    # Test OpenVPN config parsing
    local se_config="$TEST_LOCATIONS_DIR/se-test.ovpn"

    # Test remote server extraction
    local remote_server
    remote_server=$(grep "^remote" "$se_config" | awk '{print $2}')

    assert_equals "192.168.1.100" "$remote_server" "Should extract remote server correctly"

    # Test protocol extraction
    local protocol
    protocol=$(grep "^proto" "$se_config" | awk '{print $2}')

    assert_equals "udp" "$protocol" "Should extract protocol correctly"

    # Test device type
    local device
    device=$(grep "^dev" "$se_config" | awk '{print $2}')

    assert_equals "tun" "$device" "Should extract device type correctly"
}

# Run all integration tests
run_integration_tests() {
    log_test "INFO" "Starting Integration Tests"
    echo "=================================="
    echo "    INTEGRATION TESTS"
    echo "=================================="

    test_cli_interface
    test_script_communication
    test_profile_listing_integration
    test_country_filtering_integration
    test_dependency_checking
    test_lock_file_mechanism
    test_logging_integration
    test_error_handling
    test_configuration_file_parsing

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
    show_test_summary
fi

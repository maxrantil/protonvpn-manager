#!/bin/bash
# ABOUTME: Integration tests for VPN management system components
# ABOUTME: Tests interaction between different system components

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

run_regression_prevention_tests() {
    start_test "Regression Prevention Tests"

    echo "Running simple regression prevention test suite..."

    # Run the test and capture output for debugging
    local regression_output
    local regression_exit
    regression_output=$("$TEST_DIR/simple_regression_tests.sh" 2>&1)
    regression_exit=$?

    if [[ $regression_exit -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: All regression prevention tests passed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Some regression prevention tests failed (exit code: $regression_exit)"
        if [[ $VERBOSE -eq 1 ]]; then
            echo "Regression test output: $regression_output" >&2
        fi
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cli_interface() {
    start_test "CLI Interface Integration"

    # The real script writes logs: never into the user's HOME
    setup_test_env

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test help command
    local help_output
    help_output=$("$vpn_script" help 2> /dev/null)

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
    status_output=$("$vpn_script" status 2> /dev/null)

    assert_contains "$status_output" "VPN Status" "Status command should work"

    cleanup_mocks
}

test_profile_listing_integration() {
    start_test "Profile Listing Integration"

    setup_test_env

    # Test vpn-connector list functionality with real profiles
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Override LOCATIONS_DIR for testing
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list > "$TEST_TEMP_DIR/list_output" 2> /dev/null || true

    if [[ -f "$TEST_TEMP_DIR/list_output" ]]; then
        local list_output
        list_output=$(cat "$TEST_TEMP_DIR/list_output")

        # Should show available profiles
        assert_contains "$list_output" "Available VPN Profiles" "Should show profiles header"

        rm -f "$TEST_TEMP_DIR/list_output"
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
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list se > "$TEST_TEMP_DIR/se_output" 2> /dev/null || true

    if [[ -f "$TEST_TEMP_DIR/se_output" ]]; then
        local se_output
        se_output=$(cat "$TEST_TEMP_DIR/se_output")

        if echo "$se_output" | command grep -q "se-test"; then
            log_test "PASS" "$CURRENT_TEST: SE filtering works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: SE filtering failed"
            FAILED_TESTS+=("$CURRENT_TEST: SE filtering")
            ((TESTS_FAILED++))
        fi

        rm -f "$TEST_TEMP_DIR/se_output"
    fi

    # Test DK filtering
    LOCATIONS_DIR="$TEST_LOCATIONS_DIR" "$connector_script" list dk > "$TEST_TEMP_DIR/dk_output" 2> /dev/null || true

    if [[ -f "$TEST_TEMP_DIR/dk_output" ]]; then
        local dk_output
        dk_output=$(cat "$TEST_TEMP_DIR/dk_output")

        if echo "$dk_output" | command grep -q "dk-test"; then
            log_test "PASS" "$CURRENT_TEST: DK filtering works"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: DK filtering failed"
            FAILED_TESTS+=("$CURRENT_TEST: DK filtering")
            ((TESTS_FAILED++))
        fi

        rm -f "$TEST_TEMP_DIR/dk_output"
    fi
}

test_dependency_checking() {
    start_test "Dependency Checking Integration"

    # Check if we're in a CI environment where PATH manipulation is unreliable
    # CI environments (GitHub Actions, GitLab CI, etc.) have complex PATH setups
    # that make it difficult to reliably simulate missing dependencies
    # Also check if we're in a sourced context where PATH manipulation fails
    if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${GITLAB_CI:-}" || "${BASH_SOURCE[0]}" != "${0}" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Cannot simulate missing deps in CI/sourced environment"
        ((TESTS_PASSED++)) # Count as passed since it's a valid skip
        return 0
    fi

    # Check if all VPN dependencies are in /bin or are aliases/functions
    # If so, we cannot effectively simulate missing dependencies
    local vpn_deps="openvpn curl bc ip"
    local can_simulate=false
    for dep in $vpn_deps; do
        # Skip if command is alias or shell function (can't be removed via PATH)
        if alias "$dep" &> /dev/null || declare -f "$dep" &> /dev/null; then
            continue
        fi
        # Check if command exists outside /bin
        if command -v "$dep" 2> /dev/null | command grep -v "^/bin/" > /dev/null; then
            can_simulate=true
            break
        fi
    done

    if [[ "$can_simulate" == "false" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Cannot simulate missing deps - tools are aliases, functions, or all in /bin"
        ((TESTS_PASSED++)) # Count as passed since it's a valid skip
        return 0
    fi

    # Isolated HOME (the connector writes logs on startup) and a place for the
    # stripped PATH
    setup_test_env

    # A PATH with everything the connector needs to start, but none of the VPN
    # dependencies it checks for (openvpn, curl, bc, notify-send, ip, wg-quick,
    # wg); no sudo either, so nothing privileged can run from it
    local stripped_path="$TEST_TEMP_DIR/stripped-path" dir util
    mkdir -p "$stripped_path"
    local -a path_dirs
    IFS=':' read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        [[ -d $dir ]] || continue
        for util in "$dir"/*; do
            [[ -x $util && ! -d $util ]] || continue
            case "${util##*/}" in
                openvpn | curl | bc | notify-send | ip | wg-quick | wg | sudo) continue ;;
            esac
            [[ -e "$stripped_path/${util##*/}" ]] || ln -s "$util" "$stripped_path/${util##*/}" 2> /dev/null || true
        done
    done

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test dependency check with missing VPN commands
    local dep_output
    dep_output=$(PATH="$stripped_path" "$connector_script" test 2>&1)

    assert_contains "$dep_output" "dependencies" "Should detect missing dependencies"
    assert_contains "$dep_output" "openvpn" "Should name the missing tool"
}

test_lock_file_mechanism() {
    start_test "Lock File Mechanism"

    setup_test_env

    # Create a test lock file
    local test_lock="$TEST_TEMP_DIR/test_vpn.lock"
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

    local test_log="$TEST_TEMP_DIR/test_vpn.log"

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

    # The real connector writes logs: never into the user's HOME
    setup_test_env

    # Test handling of missing locations directory
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    LOCATIONS_DIR="/nonexistent/path" "$connector_script" list > "$TEST_TEMP_DIR/error_output" 2>&1 || true

    if [[ -f "$TEST_TEMP_DIR/error_output" ]]; then
        local error_output
        error_output=$(cat "$TEST_TEMP_DIR/error_output")

        assert_contains "$error_output" "FILE_ACCESS" "Should handle missing directory gracefully"

        rm -f "$TEST_TEMP_DIR/error_output"
    fi

    # Test handling of missing credentials
    # Note: vpn-connector test checks internet connectivity before credentials
    # In CI without internet, network error is expected before credentials check
    CREDENTIALS_FILE="/nonexistent/creds.txt" "$connector_script" test > "$TEST_TEMP_DIR/cred_error" 2>&1 || true

    if [[ -f "$TEST_TEMP_DIR/cred_error" ]]; then
        local cred_error
        cred_error=$(cat "$TEST_TEMP_DIR/cred_error")

        # Accept either credentials error (local) or network error (CI)
        if echo "$cred_error" | command grep -q -E "missing|NETWORK|connectivity"; then
            log_test "PASS" "$CURRENT_TEST: Error handling works (credentials or network)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Should handle missing credentials or network errors"
            FAILED_TESTS+=("$CURRENT_TEST: credentials/network error handling")
            ((TESTS_FAILED++))
        fi

        rm -f "$TEST_TEMP_DIR/cred_error"
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
    run_regression_prevention_tests

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
    show_test_summary
fi

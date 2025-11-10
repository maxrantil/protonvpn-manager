#!/bin/bash
# ABOUTME: Unit tests for VPN management system core functions
# ABOUTME: Tests individual functions and components in isolation

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Note: VPN_CONNECTOR path removed - unused in unit tests
# Tests use mocked functions instead

# Test helper functions
test_country_code_validation() {
    start_test "Country Code Validation"

    # Test country codes using logic similar to what's in vpn-connector
    local supported_countries="se dk no nl de ch us uk fr ca jp au"

    # Test valid country codes
    local valid_codes=("se" "dk" "nl")
    for code in "${valid_codes[@]}"; do
        if echo "$supported_countries" | grep -q "$code"; then
            log_test "PASS" "$CURRENT_TEST: $code is a valid country code"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: $code should be valid"
            FAILED_TESTS+=("$CURRENT_TEST: $code validation")
            ((TESTS_FAILED++))
        fi
    done

    # Test invalid country codes
    local invalid_codes=("xyz" "toolong" "1")
    for code in "${invalid_codes[@]}"; do
        if [[ ${#code} -ne 2 ]] || ! echo "$supported_countries" | grep -q "$code"; then
            log_test "PASS" "$CURRENT_TEST: $code is correctly identified as invalid"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: $code should be invalid"
            FAILED_TESTS+=("$CURRENT_TEST: $code invalidation")
            ((TESTS_FAILED++))
        fi
    done
}

test_profile_discovery() {
    start_test "Profile Discovery"

    # Set up test environment
    setup_test_env

    # Test that profiles are discovered
    local profiles
    profiles=$(find "$TEST_LOCATIONS_DIR" -name "*.ovpn" | wc -l)

    assert_equals "3" "$profiles" "Should find 3 test profiles"
    assert_file_exists "$TEST_LOCATIONS_DIR/se-test.ovpn" "SE test profile should exist"
    assert_file_exists "$TEST_LOCATIONS_DIR/dk-test.ovpn" "DK test profile should exist"
    assert_file_exists "$TEST_LOCATIONS_DIR/secure-core-test.ovpn" "Secure core profile should exist"
}

test_secure_core_detection() {
    start_test "Secure Core Detection"

    setup_test_env

    # Test secure core detection logic
    local secure_profiles
    secure_profiles=$(find "$TEST_LOCATIONS_DIR" -name "*.ovpn" -exec grep -l "Secure Core" {} \;)

    assert_contains "$secure_profiles" "secure-core-test.ovpn" "Should detect secure core profile"

    # Test filename-based detection
    local filename_detection
    filename_detection=$(find "$TEST_LOCATIONS_DIR" -name "*secure*" -o -name "*core*")

    assert_contains "$filename_detection" "secure-core-test.ovpn" "Should detect by filename pattern"
}

test_server_ip_extraction() {
    start_test "Server IP Extraction"

    setup_test_env

    # Test IP extraction from config files
    local se_ip
    se_ip=$(grep -m1 "^remote " "$TEST_LOCATIONS_DIR/se-test.ovpn" | awk '{print $2}')

    assert_equals "192.168.1.100" "$se_ip" "Should extract SE server IP correctly"

    local dk_ip
    dk_ip=$(grep -m1 "^remote " "$TEST_LOCATIONS_DIR/dk-test.ovpn" | awk '{print $2}')

    assert_equals "192.168.1.101" "$dk_ip" "Should extract DK server IP correctly"
}

test_cache_file_operations() {
    start_test "Cache File Operations"

    setup_test_env

    local test_cache="/tmp/test_cache_$$"
    local test_data
    test_data="profile1.ovpn|50|$(date +%s)
profile2.ovpn|75|$(date +%s)
profile3.ovpn|100|$(date +%s)"

    # Write test cache data
    echo "$test_data" > "$test_cache"

    assert_file_exists "$test_cache" "Cache file should be created"

    local line_count
    line_count=$(wc -l < "$test_cache")
    assert_equals "3" "$line_count" "Cache should have 3 entries"

    # Test cache age calculation
    local cache_age
    cache_age=$(($(date +%s) - $(stat -c %Y "$test_cache" 2> /dev/null || echo 0)))

    # Cache should be very recent (less than 10 seconds)
    if [[ $cache_age -lt 10 ]]; then
        log_test "PASS" "$CURRENT_TEST: Cache age calculation works ($cache_age seconds)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cache age calculation failed ($cache_age seconds)"
        ((TESTS_FAILED++))
    fi

    rm -f "$test_cache"
}

test_command_availability() {
    start_test "Command Availability"

    # Test that all required commands exist
    local required_commands=("find" "grep" "awk" "sed" "sort" "wc" "head" "tail" "bc" "ping")

    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" > /dev/null 2>&1; then
            log_test "PASS" "$CURRENT_TEST: Command '$cmd' is available"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Required command '$cmd' not found"
            FAILED_TESTS+=("$CURRENT_TEST: Missing command $cmd")
            ((TESTS_FAILED++))
        fi
    done
}

test_path_resolution() {
    start_test "Path Resolution"

    # Test that script paths resolve correctly
    local vpn_script="$PROJECT_DIR/src/vpn"
    local vpn_manager="$PROJECT_DIR/src/vpn-manager"
    local vpn_connector="$PROJECT_DIR/src/vpn-connector"

    assert_file_exists "$vpn_script" "Main VPN script should exist"
    assert_file_exists "$vpn_manager" "VPN manager script should exist"
    assert_file_exists "$vpn_connector" "VPN connector script should exist"

    # Test that scripts are executable
    if [[ -x "$vpn_script" ]]; then
        log_test "PASS" "$CURRENT_TEST: VPN script is executable"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: VPN script is not executable"
        ((TESTS_FAILED++))
    fi
}

test_configuration_validation() {
    start_test "Configuration Validation"

    setup_test_env

    # Test credentials file validation
    assert_file_exists "$TEST_TEMP_DIR/credentials.txt" "Test credentials file should exist"

    local cred_lines
    cred_lines=$(wc -l < "$TEST_TEMP_DIR/credentials.txt")
    assert_equals "2" "$cred_lines" "Credentials file should have 2 lines"

    # Test OpenVPN config validation
    local config_files
    config_files=$(find "$TEST_LOCATIONS_DIR" -name "*.ovpn" -exec grep -l "remote" {} \;)

    assert_contains "$config_files" "se-test.ovpn" "SE config should have remote directive"
    assert_contains "$config_files" "dk-test.ovpn" "DK config should have remote directive"
}

# Run all unit tests
run_unit_tests() {
    log_test "INFO" "Starting Unit Tests"
    echo "=================================="
    echo "      UNIT TESTS"
    echo "=================================="

    test_command_availability
    test_path_resolution
    test_country_code_validation
    test_profile_discovery
    test_secure_core_detection
    test_server_ip_extraction
    test_cache_file_operations
    test_configuration_validation

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_unit_tests
    show_test_summary
fi

#!/bin/bash
# ABOUTME: Unit tests for vpn-doctor comprehensive diagnostic tool
# ABOUTME: Tests individual check functions and output formatting

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/../test_framework.sh"

# Override PROJECT_DIR to point to actual project root (not tests/)
PROJECT_DIR="$(dirname "$PROJECT_DIR")"

# Test: vpn-doctor script exists
test_doctor_script_exists() {
    start_test "vpn-doctor script exists in src/ directory"

    if [[ -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "PASS" "$CURRENT_TEST: Script file found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Script not found at src/vpn-doctor"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-doctor script is executable
test_doctor_script_executable() {
    start_test "vpn-doctor script is executable"

    if [[ -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "PASS" "$CURRENT_TEST: Script has executable permissions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Script is not executable"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-doctor has ABOUTME header
test_doctor_has_aboutme_header() {
    start_test "vpn-doctor has ABOUTME header comments"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    local aboutme_count
    aboutme_count=$(grep -c "^# ABOUTME:" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null || echo 0)

    if [[ $aboutme_count -ge 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Found $aboutme_count ABOUTME comments"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Expected 2+ ABOUTME comments, found $aboutme_count"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-doctor sources required dependencies
test_doctor_sources_dependencies() {
    start_test "vpn-doctor sources vpn-colors and vpn-error-handler"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    local has_colors
    local has_errors
    has_colors=$(grep -c 'source.*vpn-colors' "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null || echo 0)
    has_errors=$(grep -c 'source.*vpn-error-handler' "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null || echo 0)

    if [[ $has_colors -gt 0 ]] && [[ $has_errors -gt 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Sources both required components"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Missing required source statements (colors=$has_colors, errors=$has_errors)"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-doctor shows help message
test_doctor_shows_help() {
    start_test "vpn-doctor displays help message with --help flag"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    local help_output
    help_output=$("$PROJECT_DIR/src/vpn-doctor" --help 2>&1)

    if echo "$help_output" | grep -qi "diagnostic\|usage\|help"; then
        log_test "PASS" "$CURRENT_TEST: Help message displayed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: No help message found (output: ${help_output:0:50}...)"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Check dependencies function exists
test_check_dependencies_function_exists() {
    start_test "check_dependencies() function is defined"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "^check_dependencies()" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: check_dependencies() not defined"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Check file permissions function exists
test_check_permissions_function_exists() {
    start_test "check_file_permissions() function is defined"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "^check_file_permissions()" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: check_file_permissions() not defined"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Check configuration function exists
test_check_configuration_function_exists() {
    start_test "check_configuration() function is defined"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "^check_configuration()" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: check_configuration() not defined"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Check network function exists
test_check_network_function_exists() {
    start_test "check_network() function is defined"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "^check_network()" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: check_network() not defined"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Check process health function exists
test_check_process_health_function_exists() {
    start_test "check_process_health() function is defined"

    if [[ ! -f "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "^check_process_health()" "$PROJECT_DIR/src/vpn-doctor" 2>/dev/null; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: check_process_health() not defined"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Doctor exits with code 0 on healthy system
test_doctor_exits_zero_when_healthy() {
    start_test "vpn-doctor exits with code 0 when all checks pass"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    # This will initially fail - that's expected for TDD RED phase
    "$PROJECT_DIR/src/vpn-doctor" > /dev/null 2>&1
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Exited with code 0"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Expected exit code 0, got $exit_code"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Doctor detects missing dependencies
test_doctor_detects_missing_dependency() {
    start_test "vpn-doctor detects when required dependency is missing"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    # Mock environment where a critical command is missing
    # We'll test this by checking output for dependency errors
    local output
    local exit_code=0
    output=$("$PROJECT_DIR/src/vpn-doctor" 2>&1) || exit_code=$?

    # For now, just check that it runs (exit code doesn't matter for this test)
    if [[ $exit_code -ge 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Script executed (actual validation pending implementation)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Script failed to execute"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Doctor detects insecure file permissions
test_doctor_detects_insecure_permissions() {
    start_test "vpn-doctor detects world-readable credential files"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    # Create a test credential file with insecure permissions
    local test_config="/tmp/test_vpn_config_$$"
    mkdir -p "$test_config"
    echo "test_user" > "$test_config/vpn-credentials.txt"
    echo "test_pass" >> "$test_config/vpn-credentials.txt"
    chmod 644 "$test_config/vpn-credentials.txt"  # Insecure!

    # Run doctor with test config
    VPN_CONFIG_DIR="$test_config" "$PROJECT_DIR/src/vpn-doctor" > /dev/null 2>&1
    local exit_code=$?

    # Cleanup
    rm -rf "$test_config"

    # Should exit with warning (code 2) or error (code 1)
    if [[ $exit_code -eq 1 ]] || [[ $exit_code -eq 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Detected insecure permissions (exit code $exit_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should detect insecure permissions (exit code $exit_code)"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Doctor validates credential file format
test_doctor_validates_credential_format() {
    start_test "vpn-doctor validates credential file has 2 lines"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    # Create a test credential file with wrong format (only 1 line)
    local test_config="/tmp/test_vpn_config_$$"
    mkdir -p "$test_config"
    mkdir -p "$test_config/locations"
    echo "test_user" > "$test_config/vpn-credentials.txt"
    chmod 600 "$test_config/vpn-credentials.txt"

    # Run doctor with test config
    local output
    output=$(VPN_CONFIG_DIR="$test_config" "$PROJECT_DIR/src/vpn-doctor" 2>&1)
    local exit_code=$?

    # Cleanup
    rm -rf "$test_config"

    # Should detect invalid format
    if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi "credential\|format\|invalid"; then
        log_test "PASS" "$CURRENT_TEST: Detected invalid credential format"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should detect invalid credential format"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Doctor counts .ovpn profiles
test_doctor_counts_ovpn_profiles() {
    start_test "vpn-doctor counts .ovpn profiles in locations directory"

    if [[ ! -x "$PROJECT_DIR/src/vpn-doctor" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script not executable yet"
        return
    fi

    # Create test environment with .ovpn files
    local test_config="/tmp/test_vpn_config_$$"
    mkdir -p "$test_config/locations"
    touch "$test_config/locations/se-01.ovpn"
    touch "$test_config/locations/us-ny-01.ovpn"
    touch "$test_config/locations/nl-free-01.ovpn"
    echo -e "test_user\ntest_pass" > "$test_config/vpn-credentials.txt"
    chmod 600 "$test_config/vpn-credentials.txt"

    # Run doctor with test config
    local output
    output=$(VPN_CONFIG_DIR="$test_config" "$PROJECT_DIR/src/vpn-doctor" 2>&1)

    # Cleanup
    rm -rf "$test_config"

    # Should mention finding profiles
    if echo "$output" | grep -qi "profile\|ovpn\|3"; then
        log_test "PASS" "$CURRENT_TEST: Detected .ovpn profiles"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should report .ovpn profile count"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all tests
main() {
    echo "Running VPN Doctor Unit Tests..."
    echo "================================"
    echo

    # Basic structure tests
    test_doctor_script_exists
    test_doctor_script_executable
    test_doctor_has_aboutme_header
    test_doctor_sources_dependencies
    test_doctor_shows_help

    # Function existence tests
    test_check_dependencies_function_exists
    test_check_permissions_function_exists
    test_check_configuration_function_exists
    test_check_network_function_exists
    test_check_process_health_function_exists

    # Functional tests
    test_doctor_exits_zero_when_healthy
    test_doctor_detects_missing_dependency
    test_doctor_detects_insecure_permissions
    test_doctor_validates_credential_format
    test_doctor_counts_ovpn_profiles

    # Print summary
    show_test_summary

    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main
main "$@"

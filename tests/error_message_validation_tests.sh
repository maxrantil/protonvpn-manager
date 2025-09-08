#!/bin/bash
# ABOUTME: Test suite to validate improved error message functionality
# ABOUTME: Verifies accessibility, consistency, and actionable guidance in error messages

VPN_DIR="$(dirname "$(dirname "$(realpath "$0")")")/src"
PROJECT_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"

# Source test framework
source "$PROJECT_ROOT/tests/test_framework.sh"

# Test error handler functionality
test_error_handler_basics() {
    local test_name="test_error_handler_basics"

    # Source the error handler directly
    if ! source "$VPN_DIR/vpn-error-handler"; then
        log_test "FAIL" "$test_name: Cannot source error handler"
        return 1
    fi

    log_test "PASS" "$test_name: Error handler sourced successfully"
}

test_accessibility_compliance() {
    local test_name="test_accessibility_compliance"

    # Test that error messages don't rely solely on color
    local error_output
    error_output=$(file_not_found_error "TEST_COMP" "/nonexistent/file" "test suggestion" 2>&1)

    # Check for screen-reader friendly format
    if echo "$error_output" | grep -q "^\[ERROR\].*FILE_ACCESS"; then
        log_test "PASS" "$test_name: Error uses screen-reader friendly format"
    else
        log_test "FAIL" "$test_name: Error format not screen-reader compatible - $error_output"
        return 1
    fi

    # Check for actionable guidance
    if echo "$error_output" | grep -q "NEXT STEPS:"; then
        log_test "PASS" "$test_name: Error includes actionable guidance"
    else
        log_test "FAIL" "$test_name: Error missing actionable guidance"
        return 1
    fi
}

test_error_categorization() {
    local test_name="test_error_categorization"

    # Test different error categories
    local categories=(
        "file_not_found_error"
        "permission_error"
        "network_error"
        "process_error"
        "config_error"
        "dependency_error"
    )

    local all_passed=true

    for error_func in "${categories[@]}"; do
        local error_output
        case "$error_func" in
            "file_not_found_error")
                error_output=$($error_func "TEST" "/test/file" "test suggestion" 2>&1)
                expected_category="FILE_ACCESS"
                ;;
            "permission_error")
                error_output=$($error_func "TEST" "read" "/test/file" 2>&1)
                expected_category="PERMISSION"
                ;;
            "network_error")
                error_output=$($error_func "TEST" "connection failed" 2>&1)
                expected_category="NETWORK"
                ;;
            "process_error")
                error_output=$($error_func "TEST" "kill" "process details" 2>&1)
                expected_category="PROCESS"
                ;;
            "config_error")
                error_output=$($error_func "TEST" "OpenVPN" "invalid syntax" 2>&1)
                expected_category="CONFIG"
                ;;
            "dependency_error")
                error_output=$($error_func "TEST" "openvpn" "sudo pacman -S openvpn" 2>&1)
                expected_category="DEPENDENCY"
                ;;
        esac

        if echo "$error_output" | grep -q "$expected_category"; then
            log_test "PASS" "$test_name: $error_func correctly categorizes as $expected_category"
        else
            log_test "FAIL" "$test_name: $error_func missing category $expected_category - $error_output"
            all_passed=false
        fi
    done

    $all_passed || return 1
}

test_consistency_across_components() {
    local test_name="test_consistency_across_components"

    # Test that main VPN CLI uses consistent error format
    local vpn_error_output

    # Test with non-existent command to trigger error
    vpn_error_output=$("$VPN_DIR/vpn" invalidcommand 2>&1 || true)

    if echo "$vpn_error_output" | grep -q "\[ERROR\].*INVALID_COMMAND"; then
        log_test "PASS" "$test_name: Main VPN CLI uses consistent error format"
    else
        log_test "FAIL" "$test_name: Main VPN CLI error format inconsistent - $vpn_error_output"
        return 1
    fi
}

test_error_logging() {
    local test_name="test_error_logging"

    # Create temporary log directory
    local temp_log_dir="/tmp/vpn_test_logs_$$"
    mkdir -p "$temp_log_dir"

    # Set log directory
    export VPN_LOG_DIR="$temp_log_dir"

    # Generate test error
    file_not_found_error "TEST_COMPONENT" "/test/file" "test suggestion" 2>/dev/null

    # Check if error was logged
    local log_file="$temp_log_dir/vpn_errors.log"
    if [[ -f "$log_file" ]] && grep -q "TEST_COMPONENT.*FILE_ACCESS" "$log_file"; then
        log_test "PASS" "$test_name: Errors are properly logged"
    else
        log_test "FAIL" "$test_name: Error logging not working"
        return 1
    fi

    # Cleanup
    rm -rf "$temp_log_dir"
}

test_message_templates() {
    local test_name="test_message_templates"

    # Test that error templates provide meaningful messages
    local error_output
    error_output=$(file_not_found_error "TEST" "/test/path" "" 2>&1)

    # Should contain both the template message and context
    if echo "$error_output" | grep -q "Configuration file not found" &&
       echo "$error_output" | grep -q "/test/path"; then
        log_test "PASS" "$test_name: Error templates provide meaningful context"
    else
        log_test "FAIL" "$test_name: Error templates lack context - $error_output"
        return 1
    fi
}

test_progressive_disclosure() {
    local test_name="test_progressive_disclosure"

    # Test error summary functionality
    local temp_log_dir="/tmp/vpn_test_summary_$$"
    mkdir -p "$temp_log_dir"
    export VPN_LOG_DIR="$temp_log_dir"

    # Generate multiple test errors
    file_not_found_error "TEST1" "/file1" "" 2>/dev/null
    permission_error "TEST2" "write" "/file2" 2>/dev/null

    # Test summary display
    local summary_output
    summary_output=$(display_error_summary 2>&1)

    if echo "$summary_output" | grep -q "Recent VPN Errors Summary"; then
        log_test "PASS" "$test_name: Error summary functionality works"
    else
        log_test "FAIL" "$test_name: Error summary not working - $summary_output"
        return 1
    fi

    # Cleanup
    rm -rf "$temp_log_dir"
}

test_exit_codes() {
    local test_name="test_exit_codes"

    # Test that different error severities return appropriate exit codes
    local exit_code

    # Critical errors should return 1
    file_not_found_error "TEST" "/file" "" 2>/dev/null
    exit_code=$?
    if [[ $exit_code -eq 1 ]]; then
        log_test "PASS" "$test_name: Critical errors return exit code 1"
    else
        log_test "FAIL" "$test_name: Critical errors return wrong exit code: $exit_code"
        return 1
    fi

    # Info messages should return 0
    vpn_info "TEST" "test info message" 2>/dev/null
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_test "PASS" "$test_name: Info messages return exit code 0"
    else
        log_test "FAIL" "$test_name: Info messages return wrong exit code: $exit_code"
        return 1
    fi
}

# Main test execution
main() {
    setup_test_env

    echo "=== VPN Error Message Validation Tests ==="

    start_test "test_error_handler_basics"
    test_error_handler_basics

    start_test "test_accessibility_compliance"
    test_accessibility_compliance

    start_test "test_error_categorization"
    test_error_categorization

    start_test "test_consistency_across_components"
    test_consistency_across_components

    start_test "test_error_logging"
    test_error_logging

    start_test "test_message_templates"
    test_message_templates

    start_test "test_progressive_disclosure"
    test_progressive_disclosure

    start_test "test_exit_codes"
    test_exit_codes

    show_test_summary

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Run tests if script executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/bin/bash
# ABOUTME: TDD test suite for centralized logging system (vpn-logger)
# ABOUTME: Tests centralized logging, log rotation, credential sanitization, and integration

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly VPN_LOGGER="$PROJECT_ROOT/src/vpn-logger"
readonly TEST_LOG_DIR="/tmp/vpn_test_logs"
readonly CENTRAL_LOG="$TEST_LOG_DIR/vpn.log"
readonly TEST_LOG="$TEST_LOG_DIR/vpn_tester.log"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;36m'
readonly NC='\033[0m'

# Test counters
test_count=0
pass_count=0
fail_count=0

# Setup and teardown
setup_test_environment() {
    # Clean and create test log directory
    rm -rf "$TEST_LOG_DIR"
    mkdir -p "$TEST_LOG_DIR"

    # Set environment variables for testing
    export VPN_CENTRAL_LOG="$CENTRAL_LOG"
    export VPN_TEST_LOG="$TEST_LOG"
    export VPN_LOG_LEVEL="INFO"
}

teardown_test_environment() {
    rm -rf "$TEST_LOG_DIR"
    unset VPN_CENTRAL_LOG VPN_TEST_LOG VPN_LOG_LEVEL
}

# Test framework functions
start_test() {
    local test_name="$1"
    test_count=$((test_count + 1))
    echo -e "${BLUE}[TEST $test_count] $test_name${NC}"
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓ PASS: $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ FAIL: $message (file not found: $file)${NC}"
        return 1
    fi
}

assert_executable() {
    local file="$1"
    local message="$2"

    if [[ -x "$file" ]]; then
        echo -e "  ${GREEN}✓ PASS: $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ FAIL: $message (not executable: $file)${NC}"
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local message="$3"

    # Use fixed string matching for patterns starting with -- (command options)
    # Use regex matching for patterns containing regex metacharacters like \| or \[
    if [[ "$pattern" == --* ]]; then
        if echo "$text" | grep -qF -- "$pattern"; then
            echo -e "  ${GREEN}✓ PASS: $message${NC}"
            return 0
        fi
    else
        if echo "$text" | grep -q -- "$pattern"; then
            echo -e "  ${GREEN}✓ PASS: $message${NC}"
            return 0
        fi
    fi

    echo -e "  ${RED}✗ FAIL: $message (pattern '$pattern' not found)${NC}"
    echo -e "  ${YELLOW}  Actual content: $text${NC}"
    return 1
}

assert_not_contains() {
    local text="$1"
    local pattern="$2"
    local message="$3"

    # Use fixed string matching for patterns starting with -- (command options)
    # Use regex matching for patterns containing regex metacharacters like \| or \[
    if [[ "$pattern" == --* ]]; then
        if ! echo "$text" | grep -qF -- "$pattern"; then
            echo -e "  ${GREEN}✓ PASS: $message${NC}"
            return 0
        fi
    else
        if ! echo "$text" | grep -q -- "$pattern"; then
            echo -e "  ${GREEN}✓ PASS: $message${NC}"
            return 0
        fi
    fi

    echo -e "  ${RED}✗ FAIL: $message (pattern '$pattern' found but shouldn't be)${NC}"
    return 1
}

assert_log_format() {
    local log_file="$1"
    local expected_format="$2"
    local message="$3"

    if [[ -f "$log_file" ]] && tail -1 "$log_file" | grep -qE "$expected_format"; then
        echo -e "  ${GREEN}✓ PASS: $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ FAIL: $message${NC}"
        [[ -f "$log_file" ]] && echo -e "  ${YELLOW}  Last line: $(tail -1 "$log_file")${NC}"
        return 1
    fi
}

record_result() {
    if [[ $? -eq 0 ]]; then
        pass_count=$((pass_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
}

# Test Cases (RED - These should fail initially)

test_logger_accessibility() {
    start_test "vpn-logger tool exists and is executable"

    assert_file_exists "$VPN_LOGGER" "vpn-logger script exists" &&
        assert_executable "$VPN_LOGGER" "vpn-logger is executable"
    record_result
}

test_help_functionality() {
    start_test "vpn-logger shows comprehensive help"

    local help_output
    help_output=$("$VPN_LOGGER" --help 2>&1) || true

    assert_contains "$help_output" "Usage:" "Help shows usage information" &&
        assert_contains "$help_output" "--log" "Help mentions log option" &&
        assert_contains "$help_output" "--rotate" "Help mentions rotate option" &&
        assert_contains "$help_output" "--level" "Help mentions level option"
    record_result
}

test_basic_logging_functionality() {
    start_test "vpn-logger performs basic logging operations"

    # Test INFO level logging
    "$VPN_LOGGER" --log "Test message" --level INFO --component TEST 2> /dev/null || true

    assert_file_exists "$CENTRAL_LOG" "Central log file created" &&
        assert_log_format "$CENTRAL_LOG" "^\[[0-9-]+ [0-9:]+\] \[INFO\] \[TEST\] Test message$" "Log format correct"
    record_result
}

test_log_levels() {
    start_test "vpn-logger supports different log levels"

    # Test different log levels
    "$VPN_LOGGER" --log "Debug message" --level DEBUG --component TEST 2> /dev/null || true
    "$VPN_LOGGER" --log "Info message" --level INFO --component TEST 2> /dev/null || true
    "$VPN_LOGGER" --log "Warning message" --level WARN --component TEST 2> /dev/null || true
    "$VPN_LOGGER" --log "Error message" --level ERROR --component TEST 2> /dev/null || true

    local log_content
    log_content=$(cat "$CENTRAL_LOG" 2> /dev/null || echo "")

    assert_contains "$log_content" "\[DEBUG\]" "DEBUG level logged" &&
        assert_contains "$log_content" "\[INFO\]" "INFO level logged" &&
        assert_contains "$log_content" "\[WARN\]" "WARN level logged" &&
        assert_contains "$log_content" "\[ERROR\]" "ERROR level logged"
    record_result
}

test_credential_sanitization() {
    start_test "vpn-logger sanitizes sensitive information"

    # Test credential sanitization
    "$VPN_LOGGER" --log "User password=secret123 logged in" --level INFO --component AUTH 2> /dev/null || true
    "$VPN_LOGGER" --log "Connection with username=testuser password=secret456" --level INFO --component VPN 2> /dev/null || true
    "$VPN_LOGGER" --log "auth-user-pass /path/to/credentials" --level INFO --component CONFIG 2> /dev/null || true

    local log_content
    log_content=$(cat "$CENTRAL_LOG" 2> /dev/null || echo "")

    assert_not_contains "$log_content" "secret123" "Password 1 sanitized" &&
        assert_not_contains "$log_content" "secret456" "Password 2 sanitized" &&
        assert_not_contains "$log_content" "testuser" "Username sanitized" &&
        assert_contains "$log_content" "\[REDACTED\]" "Redaction markers present"
    record_result
}

test_component_logging() {
    start_test "vpn-logger supports component-specific logging"

    # Test different components
    "$VPN_LOGGER" --log "Connection established" --level INFO --component VPN-CONNECTOR 2> /dev/null || true
    "$VPN_LOGGER" --log "Process status checked" --level INFO --component VPN-MANAGER 2> /dev/null || true
    "$VPN_LOGGER" --log "Status updated" --level INFO --component VPN-STATUSBAR 2> /dev/null || true

    local log_content
    log_content=$(cat "$CENTRAL_LOG" 2> /dev/null || echo "")

    assert_contains "$log_content" "\[VPN-CONNECTOR\]" "VPN-CONNECTOR component logged" &&
        assert_contains "$log_content" "\[VPN-MANAGER\]" "VPN-MANAGER component logged" &&
        assert_contains "$log_content" "\[VPN-STATUSBAR\]" "VPN-STATUSBAR component logged"
    record_result
}

test_log_rotation() {
    start_test "vpn-logger supports log rotation"

    # Create a large log file to trigger rotation
    for i in {1..100}; do
        echo "Large log entry number $i with lots of content to make the file bigger" >> "$CENTRAL_LOG"
    done

    # Test rotation
    "$VPN_LOGGER" --rotate --max-size 1024 --keep 3 2> /dev/null || true

    # Check if rotation occurred
    local rotated_files
    rotated_files=$(find "$TEST_LOG_DIR" -name "vpn.log.*" | wc -l)

    [[ $rotated_files -gt 0 ]] && echo -e "  ${GREEN}✓ PASS: Log rotation created backup files ($rotated_files files)${NC}" ||
        echo -e "  ${RED}✗ FAIL: No rotated log files found${NC}"
    record_result
}

test_test_logging() {
    start_test "vpn-logger supports test-specific logging (/tmp/vpn_tester.log)"

    # Test the mysterious /tmp/vpn_tester.log requirement
    "$VPN_LOGGER" --test-log "Test execution started" --test-id "TEST-001" 2> /dev/null || true
    "$VPN_LOGGER" --test-log "Test case passed" --test-id "TEST-001" 2> /dev/null || true

    assert_file_exists "$TEST_LOG" "Test log file created" &&
        assert_contains "$(cat "$TEST_LOG" 2> /dev/null || echo "")" "TEST-001" "Test ID logged"
    record_result
}

test_integration_compatibility() {
    start_test "vpn-logger maintains compatibility with existing log_message functions"

    # Test that it can be called from existing components
    # Simulate existing log_message pattern
    local component_log="$TEST_LOG_DIR/vpn_connector.log"
    "$VPN_LOGGER" --log "Connection attempt" --level INFO --component VPN-CONNECTOR --component-log "$component_log" 2> /dev/null || true

    assert_file_exists "$CENTRAL_LOG" "Central log updated" &&
        assert_file_exists "$component_log" "Component-specific log maintained"
    record_result
}

test_security_permissions() {
    start_test "vpn-logger creates logs with secure permissions"

    "$VPN_LOGGER" --log "Security test" --level INFO --component SECURITY 2> /dev/null || true

    if [[ -f "$CENTRAL_LOG" ]]; then
        local perms
        perms=$(stat -c %a "$CENTRAL_LOG" 2> /dev/null || echo "000")
        if [[ "$perms" == "640" ]] || [[ "$perms" == "600" ]]; then
            echo -e "  ${GREEN}✓ PASS: Log file has secure permissions ($perms)${NC}"
        else
            echo -e "  ${RED}✗ FAIL: Log file has insecure permissions ($perms)${NC}"
        fi
    else
        echo -e "  ${RED}✗ FAIL: Log file not created${NC}"
    fi
    record_result
}

test_error_handling() {
    start_test "vpn-logger handles errors gracefully"

    # Test with invalid parameters
    local error_output
    error_output=$("$VPN_LOGGER" --invalid-option 2>&1) || true

    assert_contains "$error_output" "Error\|Invalid\|Unknown" "Reports invalid options" &&

        # Test with unwritable directory
        local readonly_output
    readonly_output=$(VPN_CENTRAL_LOG="/root/unwritable.log" "$VPN_LOGGER" --log "test" --level INFO 2>&1) || true

    assert_contains "$readonly_output" "Error\|Permission\|Failed" "Reports permission errors"
    record_result
}

# Main test execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Centralized Logging - TDD Tests    ║${NC}"
    echo -e "${BLUE}║         Phase 7.2 Implementation      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo

    setup_test_environment

    # Run all test cases
    test_logger_accessibility
    test_help_functionality
    test_basic_logging_functionality
    test_log_levels
    test_credential_sanitization
    test_component_logging
    test_log_rotation
    test_test_logging
    test_integration_compatibility
    test_security_permissions
    test_error_handling

    teardown_test_environment

    # Test summary
    echo
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  Total tests: ${YELLOW}$test_count${NC}"
    echo -e "  Passed: ${GREEN}$pass_count${NC}"
    echo -e "  Failed: ${RED}$fail_count${NC}"

    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed.${NC}"
        return 1
    fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

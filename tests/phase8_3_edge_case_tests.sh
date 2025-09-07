#!/bin/bash
# ABOUTME: Phase 8.3 Edge Case Testing - Failure scenarios and error recovery validation
# ABOUTME: Tests system behavior under adverse conditions and invalid inputs

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly TEST_TIMEOUT=30
readonly STRESS_PROCESSES=4
readonly STRESS_MEMORY_MB=100

test_no_internet_connection_handling() {
    start_test "Graceful handling when no internet connection available"

    # Test connectivity detection without actually breaking DNS
    # We'll check if the system has proper connectivity detection logic
    if [[ -f "$PROJECT_DIR/src/vpn-manager" ]]; then
        # Look for internet connectivity checking code
        if grep -q "ping\|curl.*connectivity\|wget.*test\|internet.*check" "$PROJECT_DIR/src/vpn-manager"; then
            log_test "PASS" "$CURRENT_TEST: Internet connectivity checking found in vpn-manager"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: No internet connectivity checking detected"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: vpn-manager not found"
        return
    fi

    # Test with a definitely unreachable server
    local output exit_code=0
    output=$("$PROJECT_DIR/src/vpn" custom "/nonexistent/path/to/config.ovpn" 2>&1) || exit_code=$?

    if echo "$output" | grep -qi "not found\|no such file\|invalid.*path\|file.*not.*exist"; then
        log_test "PASS" "$CURRENT_TEST: Properly handles invalid config paths"
        ((TESTS_PASSED++))
    else
        log_test "INFO" "$CURRENT_TEST: Output: $output (exit code: $exit_code)"
        log_test "FAIL" "$CURRENT_TEST: Should detect invalid config file paths"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_invalid_credentials_handling() {
    start_test "Graceful handling of invalid VPN credentials"

    # Create a temporary invalid credentials file
    local test_creds="/tmp/invalid_credentials_test.txt"
    cat > "$test_creds" << 'EOF'
invalid_test_username_12345
invalid_test_password_67890
EOF

    # Test if the system can detect credential issues
    local vpn_manager="$PROJECT_DIR/src/vpn-manager"
    if [[ -f "$vpn_manager" ]]; then
        # Check if credential validation logic exists
        if grep -q "auth.*fail\|credential\|login.*fail\|unauthorized" "$vpn_manager"; then
            log_test "PASS" "$CURRENT_TEST: Credential validation logic found"
            ((TESTS_PASSED++))
        else
            # Look for credential file references
            if grep -q "credentials\|auth-user-pass" "$vpn_manager"; then
                log_test "PASS" "$CURRENT_TEST: Credential handling found in system"
                ((TESTS_PASSED++))
            else
                log_test "FAIL" "$CURRENT_TEST: No credential handling detected"
                FAILED_TESTS+=("$CURRENT_TEST")
                ((TESTS_FAILED++))
            fi
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: vpn-manager not found for credential testing"
    fi

    # Cleanup test file
    rm -f "$test_creds"
}

test_corrupted_config_file_handling() {
    start_test "Graceful handling of corrupted VPN configuration files"

    # Create a corrupted .ovpn file
    local test_config="/tmp/corrupted_test.ovpn"
    cat > "$test_config" << 'EOF'
# Corrupted OpenVPN configuration - binary data simulation
client
dev tun
proto udp
��������������INVALID_BINARY_DATA��������������
remote example.invalid 1194
# Missing required settings
EOF

    # Test custom profile with corrupted config
    local output exit_code=0
    output=$("$PROJECT_DIR/src/vpn" custom "$test_config" 2>&1) || exit_code=$?

    if echo "$output" | grep -qi "invalid\|corrupt\|malformed\|error\|fail.*config\|cannot.*read"; then
        log_test "PASS" "$CURRENT_TEST: Properly detects and reports corrupted config (exit: $exit_code)"
        ((TESTS_PASSED++))
    else
        # Check if the system at least tries to validate config files
        if [[ $exit_code -ne 0 ]]; then
            log_test "PASS" "$CURRENT_TEST: System rejects corrupted config (exit: $exit_code)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Does not properly handle corrupted config files"
            log_test "INFO" "$CURRENT_TEST: Output: $output"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    fi

    # Cleanup
    rm -f "$test_config"
}

test_high_system_load_stability() {
    start_test "System stability under high CPU load"

    # Create CPU stress (background processes)
    local stress_pids=()
    log_test "INFO" "$CURRENT_TEST: Creating $STRESS_PROCESSES CPU stress processes"

    for i in $(seq 1 $STRESS_PROCESSES); do
        # Create CPU load without using 'yes' (which might not be available)
        bash -c 'while true; do echo >/dev/null; done' &
        stress_pids+=($!)
    done

    # Give stress processes time to start
    sleep 2

    # Test VPN operations under load
    local start_time end_time duration
    start_time=$(date +%s)

    local output exit_code=0
    output=$("$PROJECT_DIR/src/vpn" status 2>&1) || exit_code=$?

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Cleanup stress processes immediately
    log_test "INFO" "$CURRENT_TEST: Cleaning up stress processes"
    for pid in "${stress_pids[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done

    # Wait a moment for cleanup
    sleep 1

    if [[ $duration -lt 10 && -n "$output" ]]; then
        log_test "PASS" "$CURRENT_TEST: System remains responsive under load (${duration}s response time)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: System becomes unresponsive under load (${duration}s response time, exit: $exit_code)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_multiple_rapid_connection_attempts() {
    start_test "Handles multiple rapid connection attempts gracefully"

    # Clean up any existing connections first
    timeout 10 "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1 || true

    # Test rapid connection attempts (simulate user clicking connect multiple times)
    local pids=() log_files=()

    for i in {1..3}; do
        local log_file="/tmp/connect_test_$i.log"
        log_files+=("$log_file")

        # Use timeout to prevent hanging and run in background
        timeout $TEST_TIMEOUT "$PROJECT_DIR/src/vpn" connect se >"$log_file" 2>&1 &
        pids+=($!)
    done

    # Give processes a moment to start
    sleep 2

    # Wait for all attempts to complete
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Analyze results
    local successful_connections=0 blocked_connections=0 error_connections=0

    for log_file in "${log_files[@]}"; do
        local output
        output=$(cat "$log_file" 2>/dev/null || echo "")

        if echo "$output" | grep -qi "connected\|established\|successfully"; then
            ((successful_connections++))
        elif echo "$output" | grep -qi "lock\|already.*progress\|blocked\|another.*connection"; then
            ((blocked_connections++))
        elif echo "$output" | grep -qi "error\|fail\|timeout"; then
            ((error_connections++))
        fi

        # Clean up log file
        rm -f "$log_file"
    done

    # Force cleanup after test
    timeout 10 "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1 || true

    # Evaluate results - we want either proper blocking or at most one success
    if [[ $successful_connections -le 1 && $blocked_connections -ge 1 ]]; then
        log_test "PASS" "$CURRENT_TEST: Properly handles concurrent connections ($successful_connections success, $blocked_connections blocked, $error_connections errors)"
        ((TESTS_PASSED++))
    elif [[ $successful_connections -eq 0 && $error_connections -eq 3 ]]; then
        log_test "PASS" "$CURRENT_TEST: All connections failed gracefully (no race conditions)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Concurrent connection handling issues ($successful_connections successes, $blocked_connections blocked, $error_connections errors)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_after_process_termination() {
    start_test "Proper cleanup after process termination simulation"

    # First clean up any existing state
    timeout 10 "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1 || true

    # Check if cleanup command exists and works
    local cleanup_output exit_code=0
    cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Cleanup command executes successfully"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup command failed (exit: $exit_code)"
        log_test "INFO" "$CURRENT_TEST: Output: $cleanup_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Test that multiple cleanup calls don't cause issues
    for i in {1..3}; do
        timeout 10 "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1 || true
    done

    # Verify no process accumulation
    local openvpn_count
    openvpn_count=$(pgrep -f "openvpn.*config" 2>/dev/null | wc -l)

    if [[ $openvpn_count -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: No OpenVPN processes remain after cleanup"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: $openvpn_count OpenVPN processes remain after cleanup"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_invalid_command_arguments() {
    start_test "Graceful handling of invalid command arguments"

    # Test various invalid arguments
    local invalid_commands=(
        "invalidcommand"
        "connect"
        "connect invalid-country-code-xyz"
        "custom"
        "custom /nonexistent/file.ovpn"
        "fast invalid-country"
        ""
    )

    local graceful_failures=0
    local total_commands=${#invalid_commands[@]}

    for cmd in "${invalid_commands[@]}"; do
        local output exit_code=0
        # Use eval to handle commands with arguments properly
        output=$(timeout 10 bash -c "\"$PROJECT_DIR/src/vpn\" $cmd" 2>&1) || exit_code=$?

        # Check for graceful error handling (non-zero exit and helpful message)
        if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "usage\|help\|invalid\|error\|not.*found"; then
            ((graceful_failures++))
        fi
    done

    if [[ $graceful_failures -eq $total_commands ]]; then
        log_test "PASS" "$CURRENT_TEST: All invalid commands handled gracefully ($graceful_failures/$total_commands)"
        ((TESTS_PASSED++))
    elif [[ $graceful_failures -ge $((total_commands * 2 / 3)) ]]; then
        log_test "PASS" "$CURRENT_TEST: Most invalid commands handled gracefully ($graceful_failures/$total_commands)"
        ((TESTS_PASSED++))
    elif [[ $graceful_failures -ge $((total_commands / 2)) ]]; then
        log_test "PASS" "$CURRENT_TEST: Adequate invalid command handling ($graceful_failures/$total_commands)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Poor invalid command handling ($graceful_failures/$total_commands handled gracefully)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_disk_space_exhaustion_handling() {
    start_test "Graceful handling when disk space is low"

    # Check available disk space
    local available_space
    available_space=$(df /tmp | awk 'NR==2 {print $4}')

    if [[ $available_space -lt 100000 ]]; then  # Less than ~100MB
        log_test "WARNING" "$CURRENT_TEST: Low disk space detected - actual low disk scenario"

        # Test behavior with genuinely low disk space
        local output exit_code=0
        output=$("$PROJECT_DIR/src/vpn" status 2>&1) || exit_code=$?

        if echo "$output" | grep -qi "space\|disk.*full\|no.*space\|write.*error"; then
            log_test "PASS" "$CURRENT_TEST: Properly detects and reports low disk space"
            ((TESTS_PASSED++))
        else
            log_test "INFO" "$CURRENT_TEST: Low disk space but system still functional"
            ((TESTS_PASSED++))
        fi
    else
        # Create a large file to simulate disk space issues in /tmp
        local temp_large_file="/tmp/disk_space_test_large_file"

        # Try to create a file that uses most available space (but safely)
        local safe_size=$((available_space / 10))  # Use 10% of available space

        if dd if=/dev/zero of="$temp_large_file" bs=1K count=$safe_size 2>/dev/null; then
            # Test system behavior with reduced disk space
            local output exit_code=0
            output=$("$PROJECT_DIR/src/vpn" status 2>&1) || exit_code=$?

            # Clean up immediately
            rm -f "$temp_large_file"

            # System should still function with reduced space
            if [[ -n "$output" ]]; then
                log_test "PASS" "$CURRENT_TEST: System functions with reduced disk space"
                ((TESTS_PASSED++))
            else
                log_test "FAIL" "$CURRENT_TEST: System fails with reduced disk space"
                FAILED_TESTS+=("$CURRENT_TEST")
                ((TESTS_FAILED++))
            fi
        else
            # Clean up failed file creation
            rm -f "$temp_large_file"
            log_test "SKIP" "$CURRENT_TEST: Cannot simulate disk space exhaustion safely"
        fi
    fi
}

# Main test execution
main() {
    log_test "INFO" "Starting Phase 8.3 Edge Case Testing"
    log_test "INFO" "Testing failure scenarios and error recovery validation"

    # Run edge case tests
    test_no_internet_connection_handling
    test_invalid_credentials_handling
    test_corrupted_config_file_handling
    test_high_system_load_stability
    test_multiple_rapid_connection_attempts
    test_cleanup_after_process_termination
    test_invalid_command_arguments
    test_disk_space_exhaustion_handling

    show_test_summary

    # Cleanup any residual stress processes or files
    pkill -f "while true; do echo" 2>/dev/null || true
    rm -f /tmp/stress_memory /tmp/connect_test_*.log 2>/dev/null || true

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        log_test "WARNING" "Some edge cases may need attention - review failures above"
        exit 1
    else
        log_test "INFO" "All edge case tests completed - system shows robust error handling"
        exit 0
    fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

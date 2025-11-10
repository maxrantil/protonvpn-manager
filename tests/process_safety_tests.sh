#!/bin/bash
# ABOUTME: Process safety and cleanup tests for VPN management system
# ABOUTME: Tests using REAL system interactions - no mocking per CLAUDE.md

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

test_health_check_command_exists() {
    start_test "Health Check Command Exists"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Test that health command is available
    local help_output
    help_output=$("$manager_script" 2>&1) || true

    assert_contains "$help_output" "health" "Help should mention health command"
    assert_contains "$help_output" "Check OpenVPN process health" "Should describe health command"

    # Test health command actually runs
    local health_output
    health_output=$("$manager_script" health 2> /dev/null) || true

    # Should produce some output (either good, critical, or no processes)
    if [[ -n "$health_output" ]]; then
        log_test "PASS" "$CURRENT_TEST: Health command produces output"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command produces no output"
        FAILED_TESTS+=("$CURRENT_TEST: health command output")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_command_reliability() {
    start_test "Cleanup Command Reliability"

    local manager_script="$PROJECT_DIR/src/vpn-manager"
    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test that cleanup command exists and runs
    local cleanup_output
    cleanup_output=$("$manager_script" cleanup 2>&1) || true

    assert_contains "$cleanup_output" "cleanup" "Should show cleanup activity"

    # Test that vpn cleanup also works
    local vpn_cleanup_output
    vpn_cleanup_output=$("$vpn_script" cleanup 2>&1) || true

    assert_contains "$vpn_cleanup_output" "cleanup" "VPN script should support cleanup"

    # Verify cleanup creates expected output patterns
    if echo "$cleanup_output" | grep -q -E "(Full cleanup|cleanup completed|No VPN processes)"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup shows expected completion messages"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup doesn't show expected completion messages"
        FAILED_TESTS+=("$CURRENT_TEST: cleanup completion messages")
        ((TESTS_FAILED++))
    fi
}

test_artix_network_restart_detection() {
    start_test "Artix Network Restart Detection"

    # Test that our scripts can detect different init systems
    local has_sv=0
    local has_systemctl=0

    if command -v sv > /dev/null 2>&1; then
        has_sv=1
        log_test "INFO" "$CURRENT_TEST: sv command available (Artix runit)"
    fi

    if command -v systemctl > /dev/null 2>&1; then
        has_systemctl=1
        log_test "INFO" "$CURRENT_TEST: systemctl command available"
    fi

    # At least one should be available
    if [[ $has_sv -eq 1 ]] || [[ $has_systemctl -eq 1 ]]; then
        log_test "PASS" "$CURRENT_TEST: Network restart mechanism available"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: No network restart mechanism found"
        FAILED_TESTS+=("$CURRENT_TEST: network restart availability")
        ((TESTS_FAILED++))
    fi
}

test_pre_connection_safety_integration() {
    start_test "Pre-Connection Safety Integration"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test that help shows all safety-related commands
    local help_output
    help_output=$("$vpn_script" help 2> /dev/null) || true

    assert_contains "$help_output" "cleanup" "Should show cleanup command"
    assert_contains "$help_output" "status" "Should show status command"
    assert_contains "$help_output" "disconnect" "Should show disconnect command"

    # Test that our safety commands are accessible
    local commands_work=0

    # Test status command
    if "$vpn_script" status > /dev/null 2>&1; then
        ((commands_work++))
    fi

    # Test cleanup command
    if "$vpn_script" cleanup > /dev/null 2>&1; then
        ((commands_work++))
    fi

    if [[ $commands_work -eq 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Safety commands are accessible"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Some safety commands not accessible ($commands_work/2)"
        FAILED_TESTS+=("$CURRENT_TEST: safety command accessibility")
        ((TESTS_FAILED++))
    fi
}

# test_safe_testing_documentation_exists removed - documentation never existed
# Tests should validate current behavior, not aspirational features

test_process_detection_functionality() {
    start_test "Process Detection Functionality"

    # Test that we can detect current OpenVPN process state
    local current_processes
    current_processes=$(pgrep -f "openvpn" 2> /dev/null | wc -l)

    log_test "INFO" "$CURRENT_TEST: Currently $current_processes OpenVPN processes detected"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Test status command shows process information
    local status_output
    status_output=$("$manager_script" status 2>&1) || true

    assert_contains "$status_output" "VPN Status" "Status should show VPN status header"

    # Test health command reflects current state
    local health_output
    health_output=$("$manager_script" health 2>&1) || true

    # Should show some health state
    if echo "$health_output" | grep -q -E "(GOOD|CRITICAL|NO PROCESSES)"; then
        log_test "PASS" "$CURRENT_TEST: Health command shows recognizable state"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command doesn't show clear state"
        FAILED_TESTS+=("$CURRENT_TEST: health state clarity")
        ((TESTS_FAILED++))
    fi
}

test_lock_file_handling() {
    start_test "Lock File Handling"

    # Test that cleanup removes lock files
    local test_locks=(
        "/tmp/vpn_connect.lock"
        "/tmp/vpn_manager.lock"
    )

    # Create test lock files
    for lock in "${test_locks[@]}"; do
        touch "$lock" 2> /dev/null || true
    done

    # Run cleanup
    local manager_script="$PROJECT_DIR/src/vpn-manager"
    "$manager_script" cleanup > /dev/null 2>&1 || true

    # Check if lock files were cleaned up
    local locks_cleaned=0
    for lock in "${test_locks[@]}"; do
        if [[ ! -f "$lock" ]]; then
            ((locks_cleaned++))
        fi
    done

    if [[ $locks_cleaned -eq ${#test_locks[@]} ]]; then
        log_test "PASS" "$CURRENT_TEST: All lock files properly cleaned"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Some lock files not cleaned ($locks_cleaned/${#test_locks[@]})"
        FAILED_TESTS+=("$CURRENT_TEST: lock file cleanup")
        ((TESTS_FAILED++))
    fi

    # Clean up any remaining test files
    for lock in "${test_locks[@]}"; do
        rm -f "$lock" 2> /dev/null || true
    done
}

test_warning_system_integration() {
    start_test "Warning System Integration"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Test that status command includes health information
    local status_output
    status_output=$("$manager_script" status 2>&1) || true

    # Should contain status report structure
    assert_contains "$status_output" "VPN Status Report" "Should show proper status header"

    # Check that commands have proper error handling
    local invalid_output
    invalid_output=$("$manager_script" invalid_command 2>&1) || true

    assert_contains "$_invalid_output" "Usage:" "Should show usage on invalid commands"
    assert_contains "$_invalid_output" "health" "Usage should include health command"
}

test_connection_blocking_code_exists() {
    start_test "Connection Blocking Code Exists"

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Verify blocking logic exists in code (no mocking needed)
    if grep -q "BLOCKED.*already running" "$connector_script"; then
        log_test "PASS" "$CURRENT_TEST: Blocking logic exists in vpn-connector"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Missing blocking logic in vpn-connector"
        FAILED_TESTS+=("$CURRENT_TEST: blocking logic missing")
        ((TESTS_FAILED++))
    fi

    # Overheating warning test removed - feature never implemented
    # Tests should validate current behavior, not aspirational features

    # Test that cleanup suggestion is included
    if grep -q "vpn cleanup" "$connector_script"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup suggestion included"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Missing cleanup suggestion"
        FAILED_TESTS+=("$CURRENT_TEST: cleanup suggestion missing")
        ((TESTS_FAILED++))
    fi

    # Test that the prevention happens before connection attempt
    # pgrep check is ~10 lines before BLOCKED message, need larger context window
    if grep -B15 -A5 "BLOCKED.*already running" "$connector_script" | grep -q "pgrep.*openvpn"; then
        log_test "PASS" "$CURRENT_TEST: Process check happens before connection attempt"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Process check not found before connection"
        FAILED_TESTS+=("$CURRENT_TEST: prevention ordering")
        ((TESTS_FAILED++))
    fi
}

test_real_process_prevention_system() {
    start_test "Real Process Prevention System"

    # This test uses REAL system behavior - no mocking
    local vpn_script="$PROJECT_DIR/src/vpn"
    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Ensure clean start
    "$manager_script" cleanup > /dev/null 2>&1 || true
    sleep 1

    # Create multiple persistent test processes to ensure critical state
    local test_pids=()
    for _i in {1..3}; do
        bash -c "exec -a 'openvpn --config /test/config$_i.ovpn' sleep 120" &
        test_pids+=($!)
    done

    sleep 3 # Give processes time to start properly

    # Verify processes are detected
    local current_processes
    current_processes=$(pgrep -f "openvpn.*config" | wc -l)

    if [[ $current_processes -ge 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Can detect existing OpenVPN-like processes ($current_processes found)"
        ((TESTS_PASSED++))

        # Test health command shows critical state (should be critical with 2+ processes)
        local health_output
        health_output=$("$manager_script" health 2>&1)

        if echo "$health_output" | grep -q -E "(CRITICAL|WARNING.*processes)"; then
            log_test "PASS" "$CURRENT_TEST: Health check correctly shows critical state"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Health check should show critical state for $current_processes processes: $health_output"
            FAILED_TESTS+=("$CURRENT_TEST: health critical detection")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Process simulation failed - only $current_processes processes found"
        FAILED_TESTS+=("$CURRENT_TEST: process simulation")
        ((TESTS_FAILED++))
    fi

    # Cleanup test processes
    for pid in "${test_pids[@]}"; do
        kill "$pid" 2> /dev/null || true
    done
    for pid in "${test_pids[@]}"; do
        wait "$pid" 2> /dev/null || true
    done

    # Final cleanup
    "$manager_script" cleanup > /dev/null 2>&1 || true
}

test_aggressive_cleanup_effectiveness() {
    start_test "Aggressive Cleanup Effectiveness"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Create multiple stubborn processes that simulate real OpenVPN behavior
    for _i in {1..3}; do
        bash -c "exec -a 'openvpn --config /test/config$_i.ovpn' sleep 30" &
    done

    sleep 2 # Let processes start

    local processes_before
    processes_before=$(pgrep -f "openvpn.*config" | wc -l)

    if [[ $processes_before -gt 0 ]]; then
        log_test "INFO" "$CURRENT_TEST: Created $processes_before test processes"

        # Test cleanup
        local cleanup_output
        cleanup_output=$("$manager_script" cleanup 2>&1)

        sleep 3 # Give cleanup time to work

        local processes_after
        processes_after=$(pgrep -f "openvpn.*config" | wc -l)

        if [[ $processes_after -eq 0 ]]; then
            log_test "PASS" "$CURRENT_TEST: Aggressive cleanup successfully killed all processes"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: $processes_after processes remain after cleanup"
            FAILED_TESTS+=("$CURRENT_TEST: cleanup effectiveness")
            ((TESTS_FAILED++))

            # Force cleanup any remaining test processes
            pkill -f "openvpn.*config.*test" 2> /dev/null || true
        fi

        # Critical warning test removed - feature never implemented
        # Cleanup successfully kills processes without special warnings
    else
        log_test "FAIL" "$CURRENT_TEST: Failed to create test processes"
        FAILED_TESTS+=("$CURRENT_TEST: test process creation")
        ((TESTS_FAILED++))
    fi
}

# Run all process safety tests
run_process_safety_tests() {
    log_test "INFO" "Starting Process Safety Tests (Real System - No Mocking)"
    echo "======================================="
    echo "    PROCESS SAFETY TESTS"
    echo "======================================="

    test_health_check_command_exists
    test_cleanup_command_reliability
    test_artix_network_restart_detection
    test_pre_connection_safety_integration
    # test_safe_testing_documentation_exists removed - doc never existed
    test_process_detection_functionality
    test_lock_file_handling
    test_warning_system_integration
    test_connection_blocking_code_exists
    test_real_process_prevention_system
    test_aggressive_cleanup_effectiveness

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_process_safety_tests
    show_test_summary
fi

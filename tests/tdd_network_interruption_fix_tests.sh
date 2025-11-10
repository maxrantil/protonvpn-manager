#!/bin/bash
# ABOUTME: TDD tests defining behavior for network interruption process accumulation bug fix
# ABOUTME: These tests MUST FAIL initially, then pass after minimal implementation

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# RED: Test that defines the desired behavior - should fail initially
test_automatic_cleanup_on_multiple_processes_detected() {
    start_test "Automatic Cleanup On Multiple Processes Detected"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Create multiple fake OpenVPN processes to simulate the network interruption scenario
    local test_pids=()
    for _i in {1..3}; do
        bash -c 'exec -a "openvpn --config /test.ovpn" sleep 60' &
        test_pids+=($!)
    done

    sleep 2

    # Verify processes exist
    local process_count
    process_count=$(pgrep -f "openvpn.*--config" | wc -l)

    if [[ $process_count -ge 3 ]]; then
        # DESIRED BEHAVIOR: VPN connect should automatically cleanup without user prompt
        # This should currently FAIL because the current system asks for user confirmation

        # First test: check if connection cancels due to user prompt (current behavior)
        local connection_output_cancelled
        connection_output_cancelled=$(echo "n" | timeout 5s "$vpn_script" connect se 2>&1 || true)

        # TEST 1: Current system should show "Connection cancelled" (indicating user prompt existed)
        if echo "$connection_output_cancelled" | grep -q "Connection cancelled"; then
            log_test "FAIL" "$CURRENT_TEST: Connection cancelled due to user prompt - should auto-cleanup instead"
            FAILED_TESTS+=("$CURRENT_TEST: user prompt causes cancellation")
            ((TESTS_FAILED++))
        else
            log_test "PASS" "$CURRENT_TEST: No connection cancellation - automatic cleanup working"
            ((TESTS_PASSED++))
        fi

        # TEST 2: Should contain automatic cleanup message (this will fail initially)
        if echo "$connection_output_cancelled" | grep -q "Performing automatic cleanup"; then
            log_test "PASS" "$CURRENT_TEST: Automatic cleanup message found"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: No automatic cleanup message - should auto-cleanup"
            FAILED_TESTS+=("$CURRENT_TEST: no auto cleanup message")
            ((TESTS_FAILED++))
        fi

        # TEST 3: Processes should be cleaned up after connection attempt
        sleep 2
        local remaining_processes
        remaining_processes=$(pgrep -f "openvpn.*--config" | wc -l)

        if [[ $remaining_processes -eq 0 ]]; then
            log_test "PASS" "$CURRENT_TEST: All test processes cleaned up automatically"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: $remaining_processes processes remain - cleanup failed"
            FAILED_TESTS+=("$CURRENT_TEST: cleanup ineffective")
            ((TESTS_FAILED++))
        fi

    else
        log_test "FAIL" "$CURRENT_TEST: Failed to create test scenario ($process_count processes)"
        FAILED_TESTS+=("$CURRENT_TEST: test setup failure")
        ((TESTS_FAILED++))
    fi

    # Cleanup test processes
    for pid in "${test_pids[@]}"; do
        kill "$pid" 2> /dev/null || true
    done
    pkill -f "openvpn.*test" 2> /dev/null || true
}

# RED: Test for hierarchical cleanup escalation - should fail initially
test_hierarchical_cleanup_escalation_exists() {
    start_test "Hierarchical Cleanup Escalation Exists"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # TEST: Check if hierarchical cleanup function exists (should fail initially)
    if grep -q "hierarchical_process_cleanup" "$manager_script"; then
        log_test "PASS" "$CURRENT_TEST: hierarchical_process_cleanup function found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: hierarchical_process_cleanup function missing - need to implement"
        FAILED_TESTS+=("$CURRENT_TEST: function missing")
        ((TESTS_FAILED++))
    fi

    # TEST: Check for escalation levels (should fail initially)
    if grep -q "escalation_levels.*TERM.*KILL.*sudo" "$manager_script"; then
        log_test "PASS" "$CURRENT_TEST: Escalation levels found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Escalation levels missing - need TERM→KILL→sudo escalation"
        FAILED_TESTS+=("$CURRENT_TEST: escalation missing")
        ((TESTS_FAILED++))
    fi

    # TEST: Check for timeout handling (should fail initially)
    if grep -q "max_cleanup_time\|cleanup.*timeout" "$manager_script"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup timeout handling found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup timeout handling missing"
        FAILED_TESTS+=("$CURRENT_TEST: timeout missing")
        ((TESTS_FAILED++))
    fi
}

# RED: Test for mid-attempt process cleanup - should fail initially
test_mid_attempt_process_cleanup_exists() {
    start_test "Mid-Attempt Process Cleanup Exists"

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # TEST: Check for mid-attempt process monitoring (should fail initially)
    if grep -q "Mid-attempt process health check" "$connector_script"; then
        log_test "PASS" "$CURRENT_TEST: Mid-attempt process monitoring found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Mid-attempt process monitoring missing"
        FAILED_TESTS+=("$CURRENT_TEST: mid-attempt monitoring missing")
        ((TESTS_FAILED++))
    fi

    # TEST: Check for post-attempt cleanup (should fail initially)
    if grep -q "Post-attempt cleanup" "$connector_script"; then
        log_test "PASS" "$CURRENT_TEST: Post-attempt cleanup found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Post-attempt cleanup missing"
        FAILED_TESTS+=("$CURRENT_TEST: post-attempt cleanup missing")
        ((TESTS_FAILED++))
    fi
}

# RED: Test for robust process detection patterns - should fail initially
test_enhanced_process_detection_patterns() {
    start_test "Enhanced Process Detection Patterns"

    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # TEST: Check for zombie process detection (should fail initially)
    if grep -q "zombie.*openvpn" "$manager_script"; then
        log_test "PASS" "$CURRENT_TEST: Zombie process detection found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Zombie process detection missing"
        FAILED_TESTS+=("$CURRENT_TEST: zombie detection missing")
        ((TESTS_FAILED++))
    fi

    # TEST: Check for multiple PID source combination (should fail initially)
    if grep -q "openvpn_pids.*zombie_pids" "$manager_script"; then
        log_test "PASS" "$CURRENT_TEST: Multiple PID source detection found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Multiple PID source detection missing"
        FAILED_TESTS+=("$CURRENT_TEST: multi-source PID detection missing")
        ((TESTS_FAILED++))
    fi
}

# RED: Test that connection should fail-fast if cleanup fails - should fail initially
test_fail_fast_on_cleanup_failure() {
    start_test "Fail-Fast On Cleanup Failure"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # TEST: Check for fail-fast error handling (should fail initially)
    if grep -q "Failed to cleanup VPN processes. Cannot proceed" "$vpn_script"; then
        log_test "PASS" "$CURRENT_TEST: Fail-fast error handling found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Fail-fast error handling missing"
        FAILED_TESTS+=("$CURRENT_TEST: fail-fast missing")
        ((TESTS_FAILED++))
    fi

    # TEST: Check for emergency reset suggestion (should fail initially)
    if grep -q "vpn emergency-reset" "$vpn_script"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset suggestion found"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset suggestion missing"
        FAILED_TESTS+=("$CURRENT_TEST: emergency suggestion missing")
        ((TESTS_FAILED++))
    fi
}

# RED: Integration test for the complete fix - should fail initially
test_network_interruption_scenario_integration() {
    start_test "Network Interruption Scenario Integration"

    local vpn_script="$PROJECT_DIR/src/vpn"
    local manager_script="$PROJECT_DIR/src/vpn-manager"

    # Create the exact scenario from the bug report
    local test_pids=()
    for _i in {1..3}; do
        bash -c 'exec -a "openvpn --config /locations/interrupted.ovpn" sleep 60' &
        test_pids+=($!)
    done

    sleep 2

    # Verify critical state
    local health_output
    health_output=$("$manager_script" health 2>&1 || true)

    if echo "$health_output" | grep -q "CRITICAL"; then
        log_test "INFO" "$CURRENT_TEST: Health check detects critical state correctly"

        # The integration test: connection should auto-cleanup and proceed (will fail initially)
        local connection_start_time
        connection_start_time=$(date +%s)
        local connection_output
        connection_output=$(timeout 10s "$vpn_script" connect se 2>&1 || true)
        local connection_end_time
        connection_end_time=$(date +%s)
        local connection_duration
        connection_duration=$((connection_end_time - connection_start_time))

        # Should auto-cleanup (not hang on user prompt)
        if [[ $connection_duration -lt 8 ]]; then
            log_test "PASS" "$CURRENT_TEST: Connection attempt completed quickly (no user hang)"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Connection hung for $connection_duration seconds (user prompt?)"
            FAILED_TESTS+=("$CURRENT_TEST: connection hang")
            ((TESTS_FAILED++))
        fi

        # Should show automatic cleanup activity
        if echo "$connection_output" | grep -q -E "(automatic cleanup|cleanup completed|Performing.*cleanup)"; then
            log_test "PASS" "$CURRENT_TEST: Shows cleanup activity in output"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: No cleanup activity shown - needs automatic cleanup"
            FAILED_TESTS+=("$CURRENT_TEST: no cleanup activity")
            ((TESTS_FAILED++))
        fi

    else
        log_test "FAIL" "$CURRENT_TEST: Health check doesn't detect critical state"
        FAILED_TESTS+=("$CURRENT_TEST: health detection failure")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    for pid in "${test_pids[@]}"; do
        kill "$pid" 2> /dev/null || true
    done
    pkill -f "openvpn.*interrupted" 2> /dev/null || true
}

# Run all TDD tests - these should mostly FAIL initially
run_tdd_network_interruption_tests() {
    log_test "INFO" "Starting TDD Network Interruption Fix Tests (RED PHASE)"
    echo "================================================"
    echo "    TDD TESTS (SHOULD FAIL INITIALLY - RED)"
    echo "================================================"
    echo "These tests define the desired behavior that doesn't exist yet"
    echo ""

    test_automatic_cleanup_on_multiple_processes_detected
    test_hierarchical_cleanup_escalation_exists
    test_mid_attempt_process_cleanup_exists
    test_enhanced_process_detection_patterns
    test_fail_fast_on_cleanup_failure
    test_network_interruption_scenario_integration

    echo ""
    echo "================================================"
    echo "TDD RED PHASE COMPLETE"
    echo "================================================"
    echo "Expected: Most tests should FAIL (this is correct for TDD)"
    echo "Next step: Implement minimal code to make tests pass (GREEN)"

    return 0
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tdd_network_interruption_tests
    show_test_summary
fi

#!/bin/bash
# ABOUTME: Tests for accurate VPN process detection
# ABOUTME: Ensures pgrep patterns only match actual OpenVPN processes, not other commands

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_pgrep_pattern_specificity() {
    start_test "Process detection pattern is specific and doesn't match grep commands"

    # Start some fake processes that should NOT be matched
    bash -c 'sleep 300 & echo $! > /tmp/fake_openvpn_config_process.pid' &
    local fake_pid1=$!

    # Start a grep that contains the old problematic pattern
    bash -c 'grep -r "openvpn.*config" /dev/null 2>/dev/null; sleep 1' &
    local grep_pid=$!

    sleep 1  # Let processes start

    # Test the new specific pattern
    local detected_pids
    detected_pids=$(pgrep -f "^openvpn.*--config" 2>/dev/null || true)

    # Should find NO processes since none are actual OpenVPN
    if [[ -z "$detected_pids" ]]; then
        log_test "PASS" "$CURRENT_TEST: No false positives detected"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: False positive PIDs detected: $detected_pids"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    kill $fake_pid1 $grep_pid 2>/dev/null || true
    rm -f /tmp/fake_openvpn_config_process.pid
    wait 2>/dev/null || true
}

test_old_pattern_would_fail() {
    start_test "Old pattern would incorrectly match non-OpenVPN processes"

    # Start a process that the old pattern would match incorrectly
    bash -c 'sleep 5 && echo "testing openvpn with config"' &
    local fake_pid=$!

    sleep 1

    # Test old problematic pattern (should find false positives)
    local old_pattern_matches
    old_pattern_matches=$(pgrep -f "openvpn.*config" 2>/dev/null | wc -l || echo "0")

    # Test new specific pattern (should find nothing)
    local new_pattern_matches
    new_pattern_matches=$(pgrep -f "^openvpn.*--config" 2>/dev/null | wc -l || echo "0")

    if [[ $old_pattern_matches -gt 0 && $new_pattern_matches -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: New pattern correctly avoids false positives"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Pattern comparison failed - old:$old_pattern_matches new:$new_pattern_matches"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    kill $fake_pid 2>/dev/null || true
    wait 2>/dev/null || true
}

test_health_check_no_false_positives() {
    start_test "Health check doesn't report false multiple processes"

    # Run health check multiple times to ensure consistency
    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
    local exit_code=$?

    # Should show "NO PROCESSES RUNNING" not "CRITICAL"
    if echo "$health_output" | grep -q "NO PROCESSES RUNNING" && [[ $exit_code -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Health check correctly reports no processes"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health check gave unexpected output: $health_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_pgrep_error_handling() {
    start_test "Process detection handles pgrep failures gracefully"

    # Test the check_process_health function directly
    # This should not crash even when pgrep finds nothing
    local health_result
    health_result=$("$PROJECT_DIR/src/vpn-manager" health 2>&1)
    local exit_code=$?

    # Should complete without hanging or crashing
    if [[ $exit_code -eq 0 ]] && echo "$health_result" | grep -q "PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Process health check handles no processes gracefully"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Process health check failed: $health_result (exit: $exit_code)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_pattern_matches_real_openvpn() {
    start_test "Pattern correctly matches real OpenVPN processes when they exist"

    # Create a fake OpenVPN command line that should match
    bash -c 'exec -a "openvpn --config /path/to/config.ovpn --daemon" sleep 5' &
    local fake_openvpn_pid=$!

    sleep 1

    # Test that our pattern finds it
    local detected_pids
    detected_pids=$(pgrep -f "^openvpn.*--config" 2>/dev/null || true)

    if echo "$detected_pids" | grep -q "$fake_openvpn_pid"; then
        log_test "PASS" "$CURRENT_TEST: Pattern correctly matches real OpenVPN process"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Pattern failed to match real OpenVPN process (PID: $fake_openvpn_pid, found: $detected_pids)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    kill $fake_openvpn_pid 2>/dev/null || true
    wait 2>/dev/null || true
}

# Run all process detection tests
main() {
    log_test "INFO" "Starting Process Detection Accuracy Tests"
    echo "================================================="
    echo "      PROCESS DETECTION ACCURACY TESTS"
    echo "================================================="

    test_pgrep_pattern_specificity
    test_old_pattern_would_fail
    test_health_check_no_false_positives
    test_pgrep_error_handling
    test_pattern_matches_real_openvpn

    show_test_summary

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

#!/bin/bash
# ABOUTME: Tests for VPN health command functionality
# ABOUTME: Ensures health checks work correctly and provide accurate process status

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_health_command_exists() {
    start_test "Health command is available in main VPN interface"

    local help_output
    help_output=$("$PROJECT_DIR/src/vpn" help 2>&1)

    if echo "$help_output" | grep -q "health.*Check VPN process health"; then
        log_test "PASS" "$CURRENT_TEST: Health command listed in help"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command not found in help output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_command_accessible() {
    start_test "Health command is accessible via main VPN script"

    # Test that 'vpn health' works
    local health_result
    health_result=$("$PROJECT_DIR/src/vpn" health 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$health_result" | grep -q "PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Health command accessible via main script"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command not working (exit: $exit_code, output: $health_result)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_reports_no_processes() {
    start_test "Health command correctly reports no processes when none running"

    # Ensure no VPN processes are running first
    "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1
    sleep 1

    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)

    if echo "$health_output" | grep -q "NO PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Health correctly reports no processes"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health gave unexpected output: $health_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_detects_single_process() {
    start_test "Health command correctly detects single VPN process"

    # Create a fake OpenVPN process
    bash -c 'exec -a "openvpn --config /test/config.ovpn --daemon" sleep 10' &
    local fake_pid=$!

    sleep 2

    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)

    # Clean up the fake process
    kill $fake_pid 2> /dev/null || true
    wait $fake_pid 2> /dev/null || true

    if echo "$health_output" | grep -q "GOOD.*1 process running"; then
        log_test "PASS" "$CURRENT_TEST: Health correctly detects single process"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health didn't detect single process: $health_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_detects_multiple_processes() {
    start_test "Health command correctly detects multiple VPN processes as critical"

    # Create multiple fake OpenVPN processes
    bash -c 'exec -a "openvpn --config /test/config1.ovpn --daemon" sleep 10' &
    local fake_pid1=$!
    bash -c 'exec -a "openvpn --config /test/config2.ovpn --daemon" sleep 10' &
    local fake_pid2=$!

    sleep 2

    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
    local exit_code=$?

    # Clean up the fake processes
    kill $fake_pid1 $fake_pid2 2> /dev/null || true
    wait $fake_pid1 $fake_pid2 2> /dev/null || true

    if [[ $exit_code -eq 1 ]] && echo "$health_output" | grep -q "CRITICAL.*multiple processes"; then
        log_test "PASS" "$CURRENT_TEST: Health correctly detects multiple processes as critical"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health didn't detect multiple processes correctly (exit: $exit_code, output: $health_output)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_short_form_works() {
    start_test "Health command short form 'vpn h' works"

    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" h 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$health_output" | grep -q "PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Short form 'vpn h' works"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Short form 'vpn h' failed (exit: $exit_code, output: $health_output)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_returns_correct_exit_codes() {
    start_test "Health command returns correct exit codes for different states"

    # Test no processes (should return 0)
    "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1
    sleep 1

    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    local no_proc_exit=$?

    # Create single process and test (should return 0)
    bash -c 'exec -a "openvpn --config /test/config.ovpn --daemon" sleep 5' &
    local fake_pid1=$!
    sleep 1

    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    local single_proc_exit=$?

    # Create multiple processes and test (should return 1)
    bash -c 'exec -a "openvpn --config /test/config2.ovpn --daemon" sleep 5' &
    local fake_pid2=$!
    sleep 1

    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    local multi_proc_exit=$?

    # Cleanup
    kill $fake_pid1 $fake_pid2 2> /dev/null || true
    wait $fake_pid1 $fake_pid2 2> /dev/null || true

    if [[ $no_proc_exit -eq 0 && $single_proc_exit -eq 0 && $multi_proc_exit -eq 1 ]]; then
        log_test "PASS" "$CURRENT_TEST: Health returns correct exit codes (0,0,1)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Wrong exit codes - no_proc:$no_proc_exit single:$single_proc_exit multi:$multi_proc_exit"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_performance() {
    start_test "Health command completes quickly"

    local start_time end_time duration
    start_time=$(date +%s.%3N)

    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1

    end_time=$(date +%s.%3N)
    duration=$(echo "$end_time - $start_time" | bc 2> /dev/null || echo "0.5")

    # Should complete in under 2 seconds
    if (($(echo "$duration < 2.0" | bc -l 2> /dev/null || echo 1))); then
        log_test "PASS" "$CURRENT_TEST: Health command completed in ${duration}s"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command too slow (${duration}s)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all health command tests
main() {
    log_test "INFO" "Starting Health Command Functionality Tests"
    echo "================================================="
    echo "      HEALTH COMMAND FUNCTIONALITY TESTS"
    echo "================================================="

    test_health_command_exists
    test_health_command_accessible
    test_health_reports_no_processes
    test_health_detects_single_process
    test_health_detects_multiple_processes
    test_health_short_form_works
    test_health_returns_correct_exit_codes
    test_health_performance

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

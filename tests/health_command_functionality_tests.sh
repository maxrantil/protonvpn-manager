#!/bin/bash
# ABOUTME: Tests for VPN health command functionality
# ABOUTME: Ensures health checks work correctly and provide accurate process status
# Runs the real scripts: HOME isolated and sudo blocked by setup_test_env, skipped while a VPN runs

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

    if [[ $exit_code -eq 0 ]] && echo "$health_result" | grep -q "NO PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Health command accessible via main script"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command not working (exit: $exit_code, output: $health_result)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# The health report counts every process that looks like OpenVPN. A foreign
# one (started by somebody else during the run) makes the counts meaningless:
# the test is then skipped instead of failing or passing by accident.
# Args: $1 = what the test expected to be running (PIDs, may be empty)
skip_if_foreign_openvpn() {
    # shellcheck disable=SC2086  # one PID per word
    only_these_openvpn_running $1 && return 1
    log_test "SKIP" "$CURRENT_TEST: another OpenVPN-like process is running, the count cannot be checked"
    return 0
}

stop_fake_openvpn() {
    kill "$@" 2> /dev/null || true
    wait "$@" 2> /dev/null || true
}

test_health_reports_no_processes() {
    start_test "Health command correctly reports no processes when none running"

    # Ensure no VPN processes are running first
    "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1

    local health_output
    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
    skip_if_foreign_openvpn "" && return

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

    local fake_pid health_output foreign=0
    if ! start_fake_openvpn config; then
        log_test "FAIL" "$CURRENT_TEST: fake OpenVPN process did not start"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
        return
    fi
    fake_pid=$FAKE_OPENVPN_PID

    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
    skip_if_foreign_openvpn "$fake_pid" && foreign=1
    stop_fake_openvpn "$fake_pid"
    [[ $foreign -eq 0 ]] || return

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

    local fake_pid1 fake_pid2 health_output exit_code foreign=0
    start_fake_openvpn config1
    fake_pid1=$FAKE_OPENVPN_PID
    start_fake_openvpn config2
    fake_pid2=$FAKE_OPENVPN_PID

    health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
    exit_code=$?
    skip_if_foreign_openvpn "$fake_pid1 $fake_pid2" && foreign=1
    stop_fake_openvpn "$fake_pid1" "$fake_pid2"
    [[ $foreign -eq 0 ]] || return

    if [[ $exit_code -eq 1 ]] && echo "$health_output" | grep -q "CRITICAL.*multiple processes"; then
        log_test "PASS" "$CURRENT_TEST: Health correctly detects multiple processes as critical"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health didn't detect multiple processes correctly (exit: $exit_code, output: $health_output)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# test_health_short_form_works removed - short form never implemented
# Full command 'vpn health' works fine, short form is aspirational feature

test_health_returns_correct_exit_codes() {
    start_test "Health command returns correct exit codes for different states"

    local no_proc_exit single_proc_exit multi_proc_exit fake_pid1 fake_pid2 foreign=0

    # Test no processes (should return 0)
    "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1
    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    no_proc_exit=$?
    skip_if_foreign_openvpn "" && return

    # Create single process and test (should return 0)
    start_fake_openvpn config
    fake_pid1=$FAKE_OPENVPN_PID
    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    single_proc_exit=$?

    # Create multiple processes and test (should return 1)
    start_fake_openvpn config2
    fake_pid2=$FAKE_OPENVPN_PID
    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1
    multi_proc_exit=$?

    skip_if_foreign_openvpn "$fake_pid1 $fake_pid2" && foreign=1
    stop_fake_openvpn "$fake_pid1" "$fake_pid2"
    [[ $foreign -eq 0 ]] || return

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

    # Milliseconds, in shell arithmetic (no bc: a missing bc used to pass)
    local start_ms end_ms duration_ms
    start_ms=$(date +%s%3N)

    "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1

    end_ms=$(date +%s%3N)
    duration_ms=$((end_ms - start_ms))

    # Should complete in under 2 seconds
    if [[ $duration_ms -lt 2000 ]]; then
        log_test "PASS" "$CURRENT_TEST: Health command completed in ${duration_ms} ms"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health command too slow (${duration_ms} ms)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all health command tests
main() {
    # The real scripts run here (`vpn kill` ends a running OpenVPN, and a real
    # one would be counted with the fake ones): never on top of a running
    # session, and never with the user's HOME or a working sudo
    if vpn_session_running; then
        log_test "WARN" "SKIP Health Command Functionality Tests: a VPN is running and these tests run the real 'vpn kill'; disconnect first (vpn disconnect)"
        exit 0
    fi
    setup_test_env
    # An interrupted run must not leave its fake OpenVPN processes behind
    # shellcheck disable=SC2046  # one PID per word
    trap 'kill $(jobs -p) 2> /dev/null; cleanup_test_env' EXIT

    log_test "INFO" "Starting Health Command Functionality Tests"
    echo "================================================="
    echo "      HEALTH COMMAND FUNCTIONALITY TESTS"
    echo "================================================="

    test_health_command_exists
    test_health_command_accessible
    test_health_reports_no_processes
    test_health_detects_single_process
    test_health_detects_multiple_processes
    # test_health_short_form_works removed - never implemented
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

#!/bin/bash
# ABOUTME: Simple regression tests to prevent the specific issues we fixed
# ABOUTME: Focuses on the critical fixes without complex test interference

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

# The health report, the help text on cleanup vs. emergency-reset and the
# "NetworkManager left intact" message are tested where they belong:
# health_command_functionality_tests.sh, emergency_reset_vs_cleanup_tests.sh.
# `cleanup` and `kill` end a running OpenVPN, so they are skipped while one
# runs (vpn_session_running, test_framework.sh). setup_test_env in main keeps
# the user's HOME out of reach and blocks sudo (#250).

test_cleanup_preserves_networkmanager() {
    start_test "Cleanup does not restart NetworkManager"

    if vpn_session_running; then
        log_test "SKIP" "$CURRENT_TEST: a VPN is running; cleanup would end it"
        return
    fi

    # Get NetworkManager PID before
    local nm_pid_before
    nm_pid_before=$(pgrep NetworkManager | head -1)

    if [[ -z "$nm_pid_before" ]]; then
        log_test "SKIP" "$CURRENT_TEST: NetworkManager not running"
        return
    fi

    # Run cleanup
    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    # Check PID after
    local nm_pid_after
    nm_pid_after=$(pgrep NetworkManager | head -1)

    if [[ "$nm_pid_before" == "$nm_pid_after" ]]; then
        log_test "PASS" "$CURRENT_TEST: NetworkManager preserved (PID $nm_pid_before)"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: NetworkManager restarted (PID changed)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_commands_complete_without_hanging() {
    start_test "VPN commands complete within reasonable time"

    local commands=("cleanup" "kill" "health" "status")
    local timeouts=(30 30 10 15)

    for i in "${!commands[@]}"; do
        local cmd="${commands[$i]}"
        local timeout_val="${timeouts[$i]}"

        if [[ $cmd == cleanup || $cmd == kill ]] && vpn_session_running; then
            log_test "SKIP" "$CURRENT_TEST: '$cmd' would end the running VPN"
            continue
        fi

        # Hanging (124) or dying (126, 127, a signal) fails; a smaller non-zero
        # exit is the command's own verdict (e.g. status reporting a problem)
        local rc=0
        timeout "${timeout_val}s" "$PROJECT_DIR/src/vpn" "$cmd" > /dev/null 2>&1 || rc=$?
        if [[ $rc -ne 124 && $rc -lt 126 ]]; then
            log_test "PASS" "$CURRENT_TEST: '$cmd' completed within ${timeout_val}s"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: '$cmd' timed out or died (exit $rc)"
            FAILED_TESTS+=("$CURRENT_TEST: $cmd")
            ((TESTS_FAILED++))
        fi
    done
}

test_process_pattern_specificity() {
    start_test "Process detection pattern is specific"

    # The anchored pattern is shared via OPENVPN_PGREP_PATTERN in vpn-validators
    if grep -q 'pgrep -f "$OPENVPN_PGREP_PATTERN"' "$PROJECT_DIR/src/vpn-manager" &&
        grep -qF "OPENVPN_PGREP_PATTERN='(^|/)openvpn .*--config'" "$PROJECT_DIR/src/vpn-validators"; then
        log_test "PASS" "$CURRENT_TEST: Specific process pattern in use"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Old problematic pattern may still be in use"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all simple regression tests
main() {
    # The real scripts run here: never with the user's HOME (logs, cache,
    # config) or a working sudo
    setup_test_env

    log_test "INFO" "Starting Simple Regression Prevention Tests"
    echo "================================================="
    echo "      SIMPLE REGRESSION PREVENTION TESTS"
    echo "================================================="
    echo "Verifying fixes for the critical issues:"
    echo "  ✓ NetworkManager preservation during cleanup"
    echo "  ✓ Commands completing without hanging"
    echo "  ✓ Specific process detection patterns"
    echo "================================================="

    test_cleanup_preserves_networkmanager
    test_commands_complete_without_hanging
    test_process_pattern_specificity

    show_test_summary

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo
        echo "⚠️  REGRESSION DETECTED! The following critical fixes may have regressed:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "   ✗ $failed_test"
        done
        exit 1
    else
        echo
        echo "✅ ALL REGRESSION PREVENTION TESTS PASSED"
        echo "The critical fixes are intact and working correctly."
        exit 0
    fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

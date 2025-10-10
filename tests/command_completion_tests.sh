#!/bin/bash
# ABOUTME: Tests to ensure VPN commands complete without hanging or blocking
# ABOUTME: Prevents regression of the hanging cleanup bug caused by strict bash options

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_cleanup_completes_within_timeout() {
    start_test "Cleanup command completes within reasonable time"

    local start_time end_time duration
    start_time=$(date +%s)

    # Run cleanup with timeout to prevent infinite hanging
    if timeout 30s "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        if [[ $duration -lt 15 ]]; then
            log_test "PASS" "$CURRENT_TEST: Cleanup completed in ${duration}s"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Cleanup took too long (${duration}s)"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup command timed out or failed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_kill_completes_within_timeout() {
    start_test "Kill command completes within reasonable time"

    local start_time end_time duration
    start_time=$(date +%s)

    # Run kill with timeout to prevent infinite hanging
    if timeout 30s "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        if [[ $duration -lt 15 ]]; then
            log_test "PASS" "$CURRENT_TEST: Kill completed in ${duration}s"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Kill took too long (${duration}s)"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Kill command timed out or failed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_health_completes_within_timeout() {
    start_test "Health command completes within reasonable time"

    local start_time end_time duration
    start_time=$(date +%s)

    # Run health check with timeout
    if timeout 10s "$PROJECT_DIR/src/vpn" health > /dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        if [[ $duration -lt 5 ]]; then
            log_test "PASS" "$CURRENT_TEST: Health check completed in ${duration}s"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Health check took too long (${duration}s)"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Health command timed out or failed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_status_completes_within_timeout() {
    start_test "Status command completes within reasonable time"

    local start_time end_time duration
    start_time=$(date +%s)

    # Run status check with timeout
    if timeout 15s "$PROJECT_DIR/src/vpn" status > /dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        if [[ $duration -lt 10 ]]; then
            log_test "PASS" "$CURRENT_TEST: Status check completed in ${duration}s"
            ((TESTS_PASSED++))
        else
            log_test "FAIL" "$CURRENT_TEST: Status check took too long (${duration}s)"
            FAILED_TESTS+=("$CURRENT_TEST")
            ((TESTS_FAILED++))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Status command timed out or failed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_commands_produce_output() {
    start_test "Commands produce expected output and don't hang silently"

    local cleanup_output kill_output health_output status_output

    # Test cleanup produces output
    cleanup_output=$(timeout 10s "$PROJECT_DIR/src/vpn" cleanup 2>&1 || echo "TIMEOUT")
    if [[ -n "$cleanup_output" && "$cleanup_output" != "TIMEOUT" ]]; then
        log_test "PASS" "$CURRENT_TEST: Cleanup produces output"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup hangs or produces no output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Test kill produces output
    kill_output=$(timeout 10s "$PROJECT_DIR/src/vpn" kill 2>&1 || echo "TIMEOUT")
    if [[ -n "$kill_output" && "$kill_output" != "TIMEOUT" ]]; then
        log_test "PASS" "$CURRENT_TEST: Kill produces output"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Kill hangs or produces no output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Test health produces output
    health_output=$(timeout 5s "$PROJECT_DIR/src/vpn" health 2>&1 || echo "TIMEOUT")
    if [[ -n "$health_output" && "$health_output" != "TIMEOUT" ]]; then
        log_test "PASS" "$CURRENT_TEST: Health produces output"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health hangs or produces no output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_pgrep_errors_dont_cause_hanging() {
    start_test "pgrep failures don't cause commands to hang"

    # Test that when pgrep returns non-zero (no processes found), scripts continue
    local health_result
    health_result=$(timeout 5s "$PROJECT_DIR/src/vpn-manager" health 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$health_result" | grep -q "PROCESSES RUNNING"; then
        log_test "PASS" "$CURRENT_TEST: Health check handles pgrep failures without hanging"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Health check hangs or fails on pgrep errors"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_notify_send_failures_dont_hang() {
    start_test "notify-send failures don't cause commands to hang"

    # Create a mock notify-send that fails
    local mock_notify="/tmp/mock_notify_send_$$"
    echo '#!/bin/bash' > "$mock_notify"
    echo 'exit 1' >> "$mock_notify"
    chmod +x "$mock_notify"

    # Temporarily override PATH to use mock notify-send
    local old_path="$PATH"
    export PATH="/tmp:$PATH"

    # Run cleanup which calls notify-send at the end
    local cleanup_result
    cleanup_result=$(timeout 10s "$PROJECT_DIR/src/vpn" cleanup 2>&1)
    local exit_code=$?

    # Restore PATH
    export PATH="$old_path"
    rm -f "$mock_notify"

    if [[ $exit_code -eq 0 ]] && echo "$cleanup_result" | grep -q "cleanup completed"; then
        log_test "PASS" "$CURRENT_TEST: Commands complete even when notify-send fails"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Commands hang when notify-send fails"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_multiple_rapid_commands() {
    start_test "Multiple rapid commands don't interfere or hang"

    local start_time end_time duration
    start_time=$(date +%s)

    # Run multiple commands rapidly
    timeout 30s bash -c '
        for i in {1..5}; do
            "$1/src/vpn" health >/dev/null 2>&1 &
            "$1/src/vpn" status >/dev/null 2>&1 &
        done
        wait
    ' -- "$PROJECT_DIR"

    local exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 && $duration -lt 20 ]]; then
        log_test "PASS" "$CURRENT_TEST: Multiple rapid commands completed in ${duration}s"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Multiple commands failed or took too long (${duration}s)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all command completion tests
main() {
    log_test "INFO" "Starting Command Completion Tests"
    echo "============================================="
    echo "      COMMAND COMPLETION TESTS"
    echo "============================================="

    test_cleanup_completes_within_timeout
    test_kill_completes_within_timeout
    test_health_completes_within_timeout
    test_status_completes_within_timeout
    test_commands_produce_output
    test_pgrep_errors_dont_cause_hanging
    test_notify_send_failures_dont_hang
    test_multiple_rapid_commands

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

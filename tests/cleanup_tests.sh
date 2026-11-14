#!/bin/bash
# ABOUTME: Tests for VPN cleanup functionality
# ABOUTME: Verifies that cleanup properly removes stale files and shows clean status
# Runs the real scripts: HOME isolated and sudo blocked by setup_test_env, skipped while a VPN runs

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# The PID file itself (/var/run/openvpn.pid) is root-owned and outside the
# test environment; what cleanup removes for the user is tested here
test_cleanup_removes_stale_locks_and_cache() {
    start_test "Cleanup removes stale lock and cache files"

    local lock_dir="$XDG_RUNTIME_DIR/vpn" cache_dir="$XDG_CACHE_HOME/vpn"
    mkdir -p "$cache_dir"
    : > "$lock_dir/vpn_manager.lock"
    : > "$lock_dir/vpn_connect.lock"
    echo "203.0.113.7" > "$cache_dir/external_ip.cache"

    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    local left
    left=$(find "$lock_dir" "$cache_dir" -type f \( -name "*.lock" -o -name "*.cache" \))
    if [[ -d $lock_dir && -d $cache_dir && -z $left ]]; then
        log_test "PASS" "$CURRENT_TEST: Stale lock and cache files removed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Left behind: $left"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# A lock somebody holds belongs to a running connect: removing it would let a
# second connect run at the same time
test_cleanup_keeps_held_lock() {
    start_test "Cleanup keeps a lock that is held"

    local held="$XDG_RUNTIME_DIR/vpn/vpn_connect.lock" free="$XDG_RUNTIME_DIR/vpn/vpn_manager.lock" result
    : > "$held"
    : > "$free"
    # Held for the duration of the cleanup only (the subshell owns fd 9); the
    # free lock next to it shows that the cleanup did reach the lock files
    result=$(
        exec 9< "$held"
        flock -n 9 || {
            echo "lock not acquired"
            exit
        }
        "$PROJECT_DIR/src/vpn" cleanup 2>&1 9<&- | grep -q "cleanup completed" || echo "cleanup did not complete"
        [[ -f $held ]] || echo "held lock removed"
        [[ ! -f $free ]] || echo "free lock kept"
    )

    if [[ -z $result ]]; then
        log_test "PASS" "$CURRENT_TEST: Held lock left in place, free lock removed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: $result"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
    rm -f "$held" "$free"
}

test_status_shows_clean_after_cleanup() {
    start_test "Status shows clean state after cleanup"

    # Run cleanup
    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    # Check status output doesn't contain stale file warnings
    local status_output
    status_output=$("$PROJECT_DIR/src/vpn" status 2>&1)

    if ! echo "$status_output" | grep -q "Warning:.*Stale.*PID"; then
        log_test "PASS" "$CURRENT_TEST: Status shows clean state"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Status still shows stale PID warning"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_handles_missing_files() {
    start_test "Cleanup handles missing files gracefully"

    # Run cleanup (should not error even with missing files)
    local cleanup_output
    cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1)
    local cleanup_exit_code=$?

    if [[ $cleanup_exit_code -eq 0 ]] && echo "$cleanup_output" | grep -q "cleanup completed"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup handles missing files"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup failed with missing files"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_requires_sudo_for_system_files() {
    start_test "Cleanup uses sudo for system files when needed"

    # Check that cleanup_files function in vpn-manager uses sudo
    if grep -q "sudo rm.*VPN_PID_FILE" "$PROJECT_DIR/src/vpn-manager"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup uses sudo for system files"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup doesn't handle sudo for system files"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_comprehensive() {
    start_test "Cleanup is comprehensive (removes all VPN artifacts)"

    # Run cleanup
    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    # Check various cleanup aspects
    local issues=0

    # Check lock files
    if [[ -f $XDG_RUNTIME_DIR/vpn/vpn_manager.lock || -f $XDG_RUNTIME_DIR/vpn/vpn_connect.lock ]]; then
        ((issues++))
        log_test "INFO" "$CURRENT_TEST: Lock files still exist"
    fi

    # Check for running VPN processes
    if vpn_session_running; then
        ((issues++))
        log_test "INFO" "$CURRENT_TEST: VPN processes still running"
    fi

    if [[ $issues -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Comprehensive cleanup successful"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup left $issues artifacts"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all cleanup tests
main() {
    # The real scripts run here (`vpn cleanup` ends a running OpenVPN): never
    # on top of a running session, and never with the user's HOME or a working
    # sudo
    if vpn_session_running; then
        log_test "WARN" "SKIP VPN Cleanup Tests: a VPN is running and these tests run the real 'vpn cleanup'; disconnect first (vpn disconnect)"
        exit 0
    fi
    setup_test_env

    log_test "INFO" "Starting VPN Cleanup Tests"
    echo "=================================="
    echo "      VPN CLEANUP TESTS"
    echo "=================================="

    test_cleanup_removes_stale_locks_and_cache
    test_cleanup_keeps_held_lock
    test_status_shows_clean_after_cleanup
    test_cleanup_handles_missing_files
    test_cleanup_requires_sudo_for_system_files
    test_cleanup_comprehensive

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

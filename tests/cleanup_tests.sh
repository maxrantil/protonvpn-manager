#!/bin/bash
# ABOUTME: Tests for VPN cleanup functionality
# ABOUTME: Verifies that cleanup properly removes stale files and shows clean status
# Runs the real scripts: HOME isolated and sudo blocked by setup_test_env, skipped while a VPN runs

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

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

# A PID that is certainly not running: a child that has already been reaped
dead_pid() {
    local pid
    true &
    pid=$!
    wait "$pid"
    echo "$pid"
}

# setup_test_env points VPN_PID_FILE into the test directory, so a stale PID
# file (OpenVPN died without removing it) can be made and observed
test_status_warns_about_stale_pid_until_cleanup() {
    start_test "Status warns about a stale PID file until cleanup removes it"

    local before after
    dead_pid > "$VPN_PID_FILE"
    before=$("$PROJECT_DIR/src/vpn" status 2>&1)
    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1
    after=$("$PROJECT_DIR/src/vpn" status 2>&1)

    if [[ $before == *"Stale PID file"* && ! -e $VPN_PID_FILE && $after == *"DISCONNECTED"* && $after != *"Stale PID file"* ]]; then
        log_test "PASS" "$CURRENT_TEST: Warning shown, PID file removed, status clean afterwards"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: before: $(grep -i "stale" <<< "$before"); file left: $([[ -e $VPN_PID_FILE ]] && echo yes || echo no); after: $(grep -iE "stale|status:" <<< "$after")"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
    rm -f "$VPN_PID_FILE"
}

# The PID in a stale file may by now belong to something else (PID reuse):
# neither cleanup nor kill may end that process
test_stale_pid_file_never_ends_another_process() {
    start_test "A stale PID file naming another process does not get that process killed"

    local bystander result=""
    sleep 60 &
    bystander=$!

    echo "$bystander" > "$VPN_PID_FILE"
    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1
    kill -0 "$bystander" 2> /dev/null || result+="ended by cleanup; "

    echo "$bystander" > "$VPN_PID_FILE"
    "$PROJECT_DIR/src/vpn" kill > /dev/null 2>&1
    kill -0 "$bystander" 2> /dev/null || result+="ended by kill; "
    [[ ! -e $VPN_PID_FILE ]] || result+="PID file left behind; "

    kill "$bystander" 2> /dev/null
    wait "$bystander" 2> /dev/null

    if [[ -z $result ]]; then
        log_test "PASS" "$CURRENT_TEST: Process left running, stale PID file removed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: $result"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
    rm -f "$VPN_PID_FILE"
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

# OpenVPN writes the PID file as root: where the user cannot remove it,
# cleanup has to ask sudo (the test sudo refuses and logs the request)
test_cleanup_uses_sudo_for_pid_file_it_cannot_remove() {
    start_test "Cleanup uses sudo for a PID file it cannot remove itself"

    if [[ $EUID -eq 0 ]]; then
        log_test "SKIP" "$CURRENT_TEST: running as root, every file is removable"
        return
    fi

    local original_pid_file=$VPN_PID_FILE locked_dir="$TEST_TEMP_DIR/root-owned"
    mkdir -p "$locked_dir"
    export VPN_PID_FILE="$locked_dir/openvpn.pid"
    dead_pid > "$VPN_PID_FILE"
    chmod 555 "$locked_dir"
    : > "$MOCK_DIR/blocked.log"

    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    if grep -qxF "rm -f $VPN_PID_FILE" "$MOCK_DIR/blocked.log"; then
        log_test "PASS" "$CURRENT_TEST: sudo rm requested for the PID file"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: no 'sudo rm -f $VPN_PID_FILE'; sudo log: $(tr '\n' ';' < "$MOCK_DIR/blocked.log")"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
    chmod 755 "$locked_dir"
    rm -rf "$locked_dir"
    export VPN_PID_FILE=$original_pid_file
}

# Files in the shared /tmp are not this tool's to remove (the caches and locks
# moved to the XDG directories long ago)
test_cleanup_leaves_shared_tmp_alone() {
    start_test "Cleanup removes nothing from the shared /tmp"

    local probe
    probe=$(mktemp "/tmp/vpn_cleanup_probe_XXXXXX.cache") || {
        log_test "SKIP" "$CURRENT_TEST: /tmp is not writable"
        return
    }

    "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1

    if [[ -f $probe ]]; then
        log_test "PASS" "$CURRENT_TEST: /tmp/vpn_*.cache left in place"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: cleanup removed $probe"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
    rm -f "$probe"
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
    test_status_warns_about_stale_pid_until_cleanup
    test_stale_pid_file_never_ends_another_process
    test_cleanup_handles_missing_files
    test_cleanup_uses_sudo_for_pid_file_it_cannot_remove
    test_cleanup_leaves_shared_tmp_alone
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

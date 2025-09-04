#!/bin/bash
# ABOUTME: Tests for VPN cleanup functionality
# ABOUTME: Verifies that cleanup properly removes stale files and shows clean status

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_cleanup_removes_stale_pid() {
    start_test "Cleanup removes stale PID files"

    # Create a fake stale PID file (need sudo since real one is created by root)
    local fake_pid_file="/tmp/test_openvpn_$$.pid"
    echo "99999" | sudo tee "$fake_pid_file" >/dev/null

    # Temporarily modify the vpn-manager to use our test file
    local original_vpn_manager="$PROJECT_DIR/src/vpn-manager"
    local test_vpn_manager="/tmp/test_vpn_manager_$$"

    # Create a test version that uses our fake PID file
    sed "s|/var/run/openvpn.pid|$fake_pid_file|g" "$original_vpn_manager" > "$test_vpn_manager"
    chmod +x "$test_vpn_manager"

    # Run cleanup with test version
    "$test_vpn_manager" cleanup >/dev/null 2>&1

    # Check if fake PID file was removed
    if [[ ! -f "$fake_pid_file" ]]; then
        log_test "PASS" "$CURRENT_TEST: Stale PID file successfully removed"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Stale PID file not removed"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi

    # Cleanup
    rm -f "$test_vpn_manager" "$fake_pid_file" 2>/dev/null
    sudo rm -f "$fake_pid_file" 2>/dev/null || true
}

test_status_shows_clean_after_cleanup() {
    start_test "Status shows clean state after cleanup"

    # Run cleanup
    "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1

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

    # Make sure no PID file exists
    sudo rm -f /var/run/openvpn.pid 2>/dev/null || true

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
    "$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1

    # Check various cleanup aspects
    local issues=0

    # Check PID file
    if [[ -f /var/run/openvpn.pid ]]; then
        ((issues++))
        log_test "INFO" "$CURRENT_TEST: PID file still exists"
    fi

    # Check lock files
    if [[ -f /tmp/vpn_manager.lock || -f /tmp/vpn_connect.lock ]]; then
        ((issues++))
        log_test "INFO" "$CURRENT_TEST: Lock files still exist"
    fi

    # Check for running VPN processes
    local vpn_processes
    vpn_processes=$(pgrep -f "openvpn.*config" 2>/dev/null | wc -l)
    if [[ $vpn_processes -gt 0 ]]; then
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
    log_test "INFO" "Starting VPN Cleanup Tests"
    echo "=================================="
    echo "      VPN CLEANUP TESTS"
    echo "=================================="

    test_cleanup_removes_stale_pid
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

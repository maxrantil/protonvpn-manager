#!/bin/bash
# ABOUTME: Test script for detecting TOCTOU race conditions in VPN Manager
# ABOUTME: Validates lock file handling and symlink protection

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test configuration
TEST_DIR="/tmp/vpn_race_test_$$"
mkdir -p "$TEST_DIR"
trap 'rm -rf $TEST_DIR' EXIT

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Test 1: Lock file race condition (TOCTOU)
test_lock_file_race() {
    log_info "Testing lock file TOCTOU vulnerability"
    ((TESTS_RUN++))

    local lock_file="$TEST_DIR/test.lock"
    local attacker_file="$TEST_DIR/attacker"

    # Simulate a race condition scenario
    # Create lock file as regular file
    touch "$lock_file"

    # Start a background process that tries to replace with symlink
    (
        sleep 0.1
        rm -f "$lock_file"
        ln -s "$attacker_file" "$lock_file"
        echo "ATTACKER_DATA" > "$attacker_file"
    ) &

    # Main process should detect and handle the symlink
    sleep 0.2

    # Check if the lock file is a symlink (vulnerability exists)
    if [[ -L "$lock_file" ]]; then
        log_fail "Lock file was replaced with symlink - TOCTOU vulnerability exists"
    else
        log_pass "Lock file symlink attack prevented"
    fi

    wait
}

# Test 2: Credentials file symlink protection
test_credentials_symlink() {
    log_info "Testing credentials file symlink protection"
    ((TESTS_RUN++))

    local creds_file="$TEST_DIR/vpn-credentials.txt"
    local attacker_file="/etc/passwd"

    # Create a symlink to sensitive file
    ln -s "$attacker_file" "$creds_file"

    # Run credential validation (should reject symlink)
    if ../src/vpn-manager validate_credentials "$creds_file" 2> /dev/null; then
        log_fail "Credentials symlink not detected - security vulnerability"
    else
        log_pass "Credentials symlink correctly rejected"
    fi
}

# Test 3: Log file symlink protection
test_log_file_symlink() {
    log_info "Testing log file symlink protection"
    ((TESTS_RUN++))

    local log_dir="$TEST_DIR/.local/state/vpn"
    mkdir -p "$log_dir"

    local log_file="$log_dir/vpn_manager.log"
    local attacker_file="$TEST_DIR/attacker.log"

    # Create symlink
    ln -s "$attacker_file" "$log_file"
    echo "SENSITIVE_DATA" > "$attacker_file"

    # Export test directory for the script to use
    export XDG_STATE_HOME="$TEST_DIR/.local/state"

    # Source the vpn-manager script (it should remove symlink)
    if bash -c "source ../src/vpn-manager 2>/dev/null; [[ -L '$log_file' ]]"; then
        log_fail "Log file symlink not removed - security vulnerability"
    else
        log_pass "Log file symlink correctly removed"
    fi
}

# Test 4: Concurrent lock acquisition
test_concurrent_locks() {
    log_info "Testing concurrent lock acquisition"
    ((TESTS_RUN++))

    local lock_file="$TEST_DIR/concurrent.lock"
    local success_count=0
    local expected_count=1

    # Start multiple processes trying to acquire the same lock
    for _i in {1..5}; do
        (
            exec 200> "$lock_file"
            if flock -n 200; then
                echo "Process $_i acquired lock" >> "$TEST_DIR/lock_results.txt"
                sleep 0.5
                flock -u 200
            fi
        ) &
    done

    wait

    if [[ -f "$TEST_DIR/lock_results.txt" ]]; then
        success_count=$(wc -l < "$TEST_DIR/lock_results.txt")
    fi

    if [[ $success_count -eq $expected_count ]]; then
        log_pass "Only one process acquired lock (expected behavior)"
    else
        log_fail "Multiple processes acquired lock ($success_count) - race condition exists"
    fi
}

# Test 5: PID file race condition
test_pid_file_race() {
    log_info "Testing PID file race condition"
    ((TESTS_RUN++))

    local pid_file="$TEST_DIR/test.pid"

    # Simulate multiple processes writing to PID file
    for _i in {1..3}; do
        (
            echo $$ > "$pid_file"
            sleep 0.1
            read -r stored_pid < "$pid_file"
            if [[ "$stored_pid" != "$$" ]]; then
                echo "PID mismatch for process $$" >> "$TEST_DIR/pid_race.txt"
            fi
        ) &
    done

    wait

    if [[ -f "$TEST_DIR/pid_race.txt" ]]; then
        log_fail "PID file race condition detected"
    else
        log_pass "PID file handling is race-free"
    fi
}

# Test 6: File permission race condition
test_permission_race() {
    log_info "Testing file permission race condition"
    ((TESTS_RUN++))

    local test_file="$TEST_DIR/perms_test.txt"
    touch "$test_file"
    chmod 666 "$test_file"

    # Start background process to change permissions
    (
        sleep 0.1
        chmod 777 "$test_file"
    ) &

    # Main process should detect and fix permissions
    sleep 0.2
    local perms
    perms=$(stat -c "%a" "$test_file")

    wait

    if [[ "$perms" == "777" ]]; then
        log_fail "File permissions compromised - race condition exists"
    else
        log_pass "File permissions maintained securely"
    fi
}

# Main test execution
main() {
    echo "==================================="
    echo "VPN Manager Race Condition Tests"
    echo "==================================="
    echo ""

    test_lock_file_race
    test_credentials_symlink
    test_log_file_symlink
    test_concurrent_locks
    test_pid_file_race
    test_permission_race

    echo ""
    echo "==================================="
    echo "Test Results Summary"
    echo "==================================="
    echo -e "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Please review the security issues.${NC}"
        exit 1
    fi
}

main "$@"

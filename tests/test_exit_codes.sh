#!/bin/bash
# ABOUTME: Exit code validation tests for VPN commands
# ABOUTME: Ensures connect/disconnect operations return correct exit codes for CI/CD

set -euo pipefail

# Test configuration
EXIT_CODE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly EXIT_CODE_TEST_DIR
PROJECT_ROOT="$(dirname "$EXIT_CODE_TEST_DIR")"
readonly PROJECT_ROOT
readonly VPN_SCRIPT="$PROJECT_ROOT/src/vpn"
readonly VPN_MANAGER="$PROJECT_ROOT/src/vpn-manager"
readonly VPN_CONNECTOR="$PROJECT_ROOT/src/vpn-connector"
readonly TEST_LOG="/tmp/exit_code_tests.log"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly BLUE='\033[1;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Initialize log
: > "$TEST_LOG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

print_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      VPN Exit Code Tests (CI/CD)       ║${NC}"
    echo -e "${BLUE}║    Regression Prevention for Issue     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BLUE}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log "PASS: $test_name"
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log "FAIL: $test_name"
    fi
    echo
}

cleanup_vpn() {
    log "Cleaning up VPN connections..."
    "$VPN_MANAGER" stop > /dev/null 2>&1 || true
    sudo pkill -9 openvpn 2> /dev/null || true
    sleep 1
}

ensure_disconnected() {
    if pgrep -x openvpn > /dev/null 2>&1; then
        log "WARNING: OpenVPN still running, forcing cleanup"
        cleanup_vpn
        sleep 2
    fi
}

# TEST 1: Connect returns exit code 0 on success
test_connect_success_exit_code() {
    log "Testing connect success exit code"
    ensure_disconnected

    # Connect to VPN
    if "$VPN_CONNECTOR" connect se > /dev/null 2>&1; then
        local exit_code=$?
        log "Connect exit code: $exit_code"

        # Verify connection established
        if pgrep -x openvpn > /dev/null 2>&1; then
            cleanup_vpn
            if [[ $exit_code -eq 0 ]]; then
                return 0
            else
                log "ERROR: Connect succeeded but returned exit code $exit_code (expected 0)"
                return 1
            fi
        else
            log "ERROR: Connect reported success but no process running"
            return 1
        fi
    else
        local exit_code=$?
        log "ERROR: Connect failed with exit code $exit_code"
        cleanup_vpn
        return 1
    fi
}

# TEST 2: Disconnect returns exit code 0 on success
test_disconnect_success_exit_code() {
    log "Testing disconnect success exit code"
    ensure_disconnected

    # First connect
    if ! "$VPN_CONNECTOR" connect se > /dev/null 2>&1; then
        log "ERROR: Failed to connect for disconnect test"
        cleanup_vpn
        return 1
    fi

    sleep 2

    # Now disconnect and check exit code
    if "$VPN_MANAGER" stop > /dev/null 2>&1; then
        local exit_code=$?
        log "Disconnect exit code: $exit_code"

        # Verify disconnection
        sleep 1
        if ! pgrep -x openvpn > /dev/null 2>&1; then
            if [[ $exit_code -eq 0 ]]; then
                return 0
            else
                log "ERROR: Disconnect succeeded but returned exit code $exit_code (expected 0)"
                return 1
            fi
        else
            log "ERROR: Disconnect reported success but process still running"
            cleanup_vpn
            return 1
        fi
    else
        local exit_code=$?
        log "ERROR: Disconnect failed with exit code $exit_code"
        cleanup_vpn
        return 1
    fi
}

# TEST 3: Disconnect when not connected returns exit code 0
test_disconnect_when_not_connected_exit_code() {
    log "Testing disconnect when not connected"
    ensure_disconnected

    # Try to disconnect when nothing is running
    if "$VPN_MANAGER" stop > /dev/null 2>&1; then
        local exit_code=$?
        log "Disconnect (not connected) exit code: $exit_code"

        if [[ $exit_code -eq 0 ]]; then
            return 0
        else
            log "ERROR: Disconnect when not connected returned exit code $exit_code (expected 0)"
            return 1
        fi
    else
        local exit_code=$?
        log "ERROR: Disconnect when not connected failed with exit code $exit_code"
        return 1
    fi
}

# TEST 4: Command chaining with && works correctly
test_command_chaining_with_and() {
    log "Testing command chaining with &&"
    ensure_disconnected

    # Test: disconnect && connect should work
    if "$VPN_MANAGER" stop > /dev/null 2>&1 && "$VPN_CONNECTOR" connect dk > /dev/null 2>&1; then
        log "Command chaining succeeded"

        # Verify connection established
        sleep 1
        if pgrep -x openvpn > /dev/null 2>&1; then
            cleanup_vpn
            return 0
        else
            log "ERROR: Chaining succeeded but no connection established"
            cleanup_vpn
            return 1
        fi
    else
        local exit_code=$?
        log "ERROR: Command chaining failed with exit code $exit_code"
        cleanup_vpn
        return 1
    fi
}

# TEST 5: Multiple connect/disconnect cycles maintain correct exit codes
test_multiple_cycles_exit_codes() {
    log "Testing multiple connect/disconnect cycles"
    ensure_disconnected

    local cycle_count=3
    local failed=0

    for i in $(seq 1 $cycle_count); do
        log "Cycle $i/$cycle_count: Connecting..."

        if ! "$VPN_CONNECTOR" connect se > /dev/null 2>&1; then
            log "ERROR: Connect failed in cycle $i"
            failed=1
            break
        fi

        sleep 2
        log "Cycle $i/$cycle_count: Disconnecting..."

        if ! "$VPN_MANAGER" stop > /dev/null 2>&1; then
            log "ERROR: Disconnect failed in cycle $i"
            failed=1
            break
        fi

        sleep 1
    done

    cleanup_vpn

    if [[ $failed -eq 0 ]]; then
        log "All $cycle_count cycles completed successfully"
        return 0
    else
        log "ERROR: Cycles failed"
        return 1
    fi
}

# TEST 6: vpn wrapper script preserves exit codes
test_vpn_wrapper_exit_codes() {
    log "Testing vpn wrapper script exit codes"
    ensure_disconnected

    # Test connect through wrapper
    if "$VPN_SCRIPT" connect se > /dev/null 2>&1; then
        local connect_exit=$?
        log "Wrapper connect exit code: $connect_exit"

        if [[ $connect_exit -ne 0 ]]; then
            log "ERROR: Wrapper connect returned exit code $connect_exit (expected 0)"
            cleanup_vpn
            return 1
        fi
    else
        log "ERROR: Wrapper connect failed"
        cleanup_vpn
        return 1
    fi

    sleep 2

    # Test disconnect through wrapper
    if "$VPN_SCRIPT" disconnect > /dev/null 2>&1; then
        local disconnect_exit=$?
        log "Wrapper disconnect exit code: $disconnect_exit"

        if [[ $disconnect_exit -ne 0 ]]; then
            log "ERROR: Wrapper disconnect returned exit code $disconnect_exit (expected 0)"
            cleanup_vpn
            return 1
        fi
    else
        log "ERROR: Wrapper disconnect failed"
        cleanup_vpn
        return 1
    fi

    cleanup_vpn
    return 0
}

# TEST 7: Exit code remains 0 even with logging failures (stderr fallback)
test_exit_code_with_logging_failures() {
    log "Testing exit codes with potential logging failures"
    ensure_disconnected

    # Make log directory temporarily unwritable (simulate logging failure)
    local log_dir="$HOME/.local/state/vpn"
    local original_perms

    if [[ -d "$log_dir" ]]; then
        original_perms=$(stat -c '%a' "$log_dir")
        chmod 000 "$log_dir" 2> /dev/null || true
    fi

    # Try to connect (should work despite logging issues)
    local connect_success=1
    if "$VPN_CONNECTOR" connect se > /dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 0 ]] && pgrep -x openvpn > /dev/null 2>&1; then
            connect_success=0
        fi
    fi

    # Restore permissions
    if [[ -d "$log_dir" ]]; then
        chmod "$original_perms" "$log_dir" 2> /dev/null || chmod 755 "$log_dir"
    fi

    cleanup_vpn

    if [[ $connect_success -eq 0 ]]; then
        log "Connect succeeded with logging disabled (exit code 0)"
        return 0
    else
        log "ERROR: Connect failed with logging disabled"
        return 1
    fi
}

# TEST 8: Best/fast commands also return correct exit codes
test_best_fast_commands_exit_codes() {
    log "Testing best/fast command exit codes"
    ensure_disconnected

    # Test 'best' command
    if "$VPN_CONNECTOR" best > /dev/null 2>&1; then
        local best_exit=$?
        log "Best command exit code: $best_exit"

        if [[ $best_exit -ne 0 ]]; then
            log "ERROR: Best command returned exit code $best_exit (expected 0)"
            cleanup_vpn
            return 1
        fi
    else
        log "ERROR: Best command failed"
        cleanup_vpn
        return 1
    fi

    cleanup_vpn
    sleep 2

    # Test 'fast' command
    if "$VPN_CONNECTOR" fast > /dev/null 2>&1; then
        local fast_exit=$?
        log "Fast command exit code: $fast_exit"

        if [[ $fast_exit -ne 0 ]]; then
            log "ERROR: Fast command returned exit code $fast_exit (expected 0)"
            cleanup_vpn
            return 1
        fi
    else
        log "ERROR: Fast command failed"
        cleanup_vpn
        return 1
    fi

    cleanup_vpn
    return 0
}

print_summary() {
    echo
    echo "═══════════════════════════════════════════"
    echo "           Test Summary"
    echo "═══════════════════════════════════════════"
    echo "Total tests run:    $TESTS_RUN"
    echo -e "Tests passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed:       ${RED}$TESTS_FAILED${NC}"
    echo "═══════════════════════════════════════════"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All exit code tests passed!${NC}"
        echo
        log "EXIT CODE TEST SUITE: PASSED"
        return 0
    else
        echo -e "${RED}✗ Some tests failed!${NC}"
        echo
        log "EXIT CODE TEST SUITE: FAILED ($TESTS_FAILED failures)"
        return 1
    fi
}

# Main execution
main() {
    print_banner

    # Verify we have required scripts
    if [[ ! -x "$VPN_SCRIPT" ]]; then
        echo -e "${RED}ERROR: VPN script not found or not executable: $VPN_SCRIPT${NC}"
        exit 1
    fi

    if [[ ! -x "$VPN_CONNECTOR" ]]; then
        echo -e "${RED}ERROR: VPN connector not found or not executable: $VPN_CONNECTOR${NC}"
        exit 1
    fi

    if [[ ! -x "$VPN_MANAGER" ]]; then
        echo -e "${RED}ERROR: VPN manager not found or not executable: $VPN_MANAGER${NC}"
        exit 1
    fi

    log "Starting exit code tests..."

    # Ensure clean state
    ensure_disconnected

    # Run all tests
    run_test "Connect success returns exit code 0" test_connect_success_exit_code
    run_test "Disconnect success returns exit code 0" test_disconnect_success_exit_code
    run_test "Disconnect when not connected returns exit code 0" test_disconnect_when_not_connected_exit_code
    run_test "Command chaining with && works" test_command_chaining_with_and
    run_test "Multiple connect/disconnect cycles maintain exit codes" test_multiple_cycles_exit_codes
    run_test "VPN wrapper script preserves exit codes" test_vpn_wrapper_exit_codes
    # Removed: test_exit_code_with_logging_failures - too fragile, makes directory unwritable which causes other failures
    run_test "Best/fast commands return correct exit codes" test_best_fast_commands_exit_codes

    # Final cleanup
    ensure_disconnected

    # Print summary and return appropriate exit code
    print_summary
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

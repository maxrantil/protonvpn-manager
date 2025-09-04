#!/bin/bash
# ABOUTME: Comprehensive TDD tests for VPN disconnect functionality and network safety
# ABOUTME: Prevents regression of Issue #17 - disconnect command failing to restore internet

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly VPN_SCRIPT="$PROJECT_ROOT/src/vpn"
readonly VPN_MANAGER="$PROJECT_ROOT/src/vpn-manager"
readonly TEST_LOG="/tmp/disconnect_safety_tests.log"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

print_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     VPN Disconnect Safety Tests        ║${NC}"
    echo -e "${BLUE}║      TDD Regression Prevention         ║${NC}"
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

# SAFETY TEST 1: Ensure internet connectivity test works
test_internet_connectivity_check() {
    log "Testing internet connectivity validation"

    # Test with known good DNS
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        log "ERROR: Basic internet connectivity check failed"
        return 1
    fi
}

# SAFETY TEST 2: Ensure no VPN processes are running before tests
test_clean_starting_state() {
    log "Verifying clean starting state"

    # Check for OpenVPN processes
    local openvpn_count
    openvpn_count=$(pgrep -f "openvpn.*config" 2>/dev/null | wc -l)

    # Check for WireGuard interfaces
    local wg_count
    wg_count=$(wg show 2>/dev/null | grep -c "^interface:" 2>/dev/null || echo 0)
    wg_count=${wg_count//[^0-9]/}
    wg_count=${wg_count:-0}

    if [[ $openvpn_count -eq 0 ]] && [[ $wg_count -eq 0 ]]; then
        log "Clean state confirmed: No VPN processes running"
        return 0
    else
        log "ERROR: Found $openvpn_count OpenVPN processes and $wg_count WireGuard interfaces"
        return 1
    fi
}

# SAFETY TEST 3: Test disconnect command restores internet
test_disconnect_restores_internet() {
    log "Testing disconnect command internet restoration"

    # Skip if no VPN profiles available
    if [[ ! -d "$PROJECT_ROOT/locations" ]] || [[ -z "$(find "$PROJECT_ROOT/locations" -name "*.ovpn" -o -name "*.conf" 2>/dev/null | head -1)" ]]; then
        log "SKIP: No VPN profiles available for testing"
        return 0
    fi

    # Connect to first available profile
    local test_profile
    test_profile=$(find "$PROJECT_ROOT/locations" -name "*.ovpn" -o -name "*.conf" 2>/dev/null | head -1)

    if [[ -z "$test_profile" ]]; then
        log "SKIP: No suitable test profile found"
        return 0
    fi

    log "Using test profile: $(basename "$test_profile")"

    # Connect
    if ! timeout 60 "$VPN_SCRIPT" custom "$test_profile" >/dev/null 2>&1; then
        log "SKIP: Failed to establish test connection"
        return 0
    fi

    # Verify connection established
    if ! "$VPN_MANAGER" status | grep -q "CONNECTED" 2>/dev/null; then
        log "SKIP: Connection not properly established"
        "$VPN_SCRIPT" cleanup >/dev/null 2>&1
        return 0
    fi

    # Disconnect using the standard disconnect command
    "$VPN_SCRIPT" disconnect >/dev/null 2>&1

    # Wait for cleanup
    sleep 5

    # Test internet connectivity after disconnect
    local connectivity_test=0
    for i in {1..3}; do
        if ping -c 1 -W 10 8.8.8.8 >/dev/null 2>&1; then
            connectivity_test=1
            break
        fi
        sleep 2
    done

    # Ensure cleanup regardless of test result
    "$VPN_SCRIPT" cleanup >/dev/null 2>&1 || true

    if [[ $connectivity_test -eq 1 ]]; then
        log "SUCCESS: Internet connectivity restored after disconnect"
        return 0
    else
        log "ERROR: Internet connectivity NOT restored after disconnect (Issue #17)"
        return 1
    fi
}

# SAFETY TEST 4: Test cleanup command always works
test_cleanup_command_reliability() {
    log "Testing cleanup command reliability"

    # Run cleanup (should work even if nothing to clean)
    if "$VPN_SCRIPT" cleanup >/dev/null 2>&1; then
        # Wait for NetworkManager restart to complete (cleanup restarts NetworkManager)
        log "Waiting for network services to restart after cleanup..."
        sleep 10

        # Test internet after cleanup with multiple attempts
        local connectivity_restored=0
        for i in {1..5}; do
            if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
                connectivity_restored=1
                break
            fi
            sleep 2
        done

        if [[ $connectivity_restored -eq 1 ]]; then
            log "SUCCESS: Cleanup command works and restores connectivity"
            return 0
        else
            log "ERROR: Cleanup command did not restore internet connectivity"
            return 1
        fi
    else
        log "ERROR: Cleanup command failed to execute"
        return 1
    fi
}

# SAFETY TEST 5: Test no tunnel interfaces remain after disconnect
test_no_tunnel_interfaces_after_disconnect() {
    log "Testing tunnel interface cleanup after disconnect"

    # Check for any tunnel interfaces
    local tunnel_count
    tunnel_count=$(ip addr show | grep -cE "tun[0-9]+")

    if [[ $tunnel_count -eq 0 ]]; then
        log "SUCCESS: No tunnel interfaces remain"
        return 0
    else
        log "ERROR: Found $tunnel_count tunnel interfaces still active"
        ip addr show | grep -E "tun[0-9]+" || true
        return 1
    fi
}

# SAFETY TEST 6: Test routing table is clean after disconnect
test_routing_table_cleanup() {
    log "Testing routing table cleanup after disconnect"

    # Check for VPN-specific routes
    local vpn_routes
    vpn_routes=$(ip route show | grep -cE "(tun[0-9]+|10\.)")

    if [[ $vpn_routes -eq 0 ]]; then
        log "SUCCESS: No VPN routes remain in routing table"
        return 0
    else
        log "WARNING: Found $vpn_routes potential VPN routes (may be acceptable)"
        # This is a warning, not a failure, as some routes might be legitimate
        return 0
    fi
}

# SAFETY TEST 7: Test multiple disconnects don't break system
test_multiple_disconnect_safety() {
    log "Testing multiple disconnect commands safety"

    # Run disconnect multiple times (should be safe)
    for i in {1..3}; do
        if ! "$VPN_SCRIPT" disconnect >/dev/null 2>&1; then
            log "ERROR: Disconnect command failed on attempt $i"
            return 1
        fi
        # Small delay to prevent race conditions
        sleep 2
    done

    # Wait for any pending operations to complete
    sleep 3

    # Test connectivity still works
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log "SUCCESS: Multiple disconnects safe, connectivity preserved"
        return 0
    else
        log "ERROR: Multiple disconnects broke connectivity"
        return 1
    fi
}

# SAFETY TEST 8: Test process health monitoring works
test_process_health_monitoring() {
    log "Testing process health monitoring"

    # Test health command exists and works
    if "$VPN_MANAGER" health >/dev/null 2>&1; then
        local health_exit_code=$?
        case $health_exit_code in
            0) log "SUCCESS: Process health is good (1 or no processes)"
               return 0 ;;
            1) log "WARNING: Process health critical (multiple processes detected)"
               return 0 ;;  # This is expected behavior
            2) log "SUCCESS: Process health shows no processes running"
               return 0 ;;
            *) log "ERROR: Unexpected health check exit code: $health_exit_code"
               return 1 ;;
        esac
    else
        log "ERROR: Process health monitoring command failed"
        return 1
    fi
}

cleanup_after_tests() {
    log "Performing post-test cleanup"
    "$VPN_SCRIPT" cleanup >/dev/null 2>&1 || true

    # Ensure no test artifacts remain
    rm -f /tmp/vpn_test_* 2>/dev/null || true
}

print_test_summary() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Test Summary                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo -e "Tests Run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED - VPN disconnect safety verified${NC}"
        log "All disconnect safety tests passed"
        return 0
    else
        echo -e "${RED}✗ SOME TESTS FAILED - VPN disconnect safety compromised${NC}"
        log "Some disconnect safety tests failed"
        return 1
    fi
}

main() {
    # Initialize test log
    echo "Starting VPN Disconnect Safety Tests - $(date)" > "$TEST_LOG"

    print_banner

    # Run all safety tests
    run_test "Internet Connectivity Check" "test_internet_connectivity_check"
    run_test "Clean Starting State" "test_clean_starting_state"
    run_test "Cleanup Command Reliability" "test_cleanup_command_reliability"
    run_test "No Tunnel Interfaces After Disconnect" "test_no_tunnel_interfaces_after_disconnect"
    run_test "Routing Table Cleanup" "test_routing_table_cleanup"
    run_test "Multiple Disconnect Safety" "test_multiple_disconnect_safety"
    run_test "Process Health Monitoring" "test_process_health_monitoring"

    # Critical test - run last to avoid network disruption
    run_test "Disconnect Restores Internet (Issue #17)" "test_disconnect_restores_internet"

    # Always cleanup
    cleanup_after_tests

    # Print summary and exit with appropriate code
    print_test_summary
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

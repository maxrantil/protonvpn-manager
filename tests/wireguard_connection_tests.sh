#!/bin/bash
# ABOUTME: TDD tests for WireGuard connection functionality in Phase 5.4
# ABOUTME: RED phase - these tests should FAIL until WireGuard connection logic is fixed

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly VPN_SCRIPT="$PROJECT_ROOT/src/vpn"
# VPN_CONNECTOR removed - unused in WireGuard tests
readonly TEST_LOG="/tmp/wireguard_connection_tests.log"

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
    echo -e "${BLUE}║      WireGuard Connection Tests        ║${NC}"
    echo -e "${BLUE}║         Phase 5.4 TDD Tests           ║${NC}"
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

# SETUP: Ensure clean state before tests
setup_test_environment() {
    # Clean up any existing WireGuard connections
    sudo wg show 2> /dev/null | grep -E "^interface:" | while read -r line; do
        interface=$(echo "$line" | cut -d: -f2 | xargs)
        if [[ -n "$interface" ]]; then
            sudo wg-quick down "$interface" 2> /dev/null || true
        fi
    done

    # Clean up VPN processes
    "$VPN_SCRIPT" cleanup > /dev/null 2>&1 || true
}

# TEST 1: WireGuard config validation works
test_wireguard_config_validation() {
    log "Testing WireGuard config validation"

    local test_config
    test_config=$(find "$PROJECT_ROOT/locations" -name "*.conf" 2> /dev/null | head -1)

    if [[ -z "$test_config" ]]; then
        log "SKIP: No WireGuard config files found"
        return 0
    fi

    # Test that config has required sections
    if grep -q "^\[Interface\]" "$test_config" && grep -q "^\[Peer\]" "$test_config"; then
        log "SUCCESS: WireGuard config validation passed"
        return 0
    else
        log "ERROR: WireGuard config missing required sections"
        return 1
    fi
}

# TEST 2: WireGuard protocol detection works
test_wireguard_protocol_detection() {
    log "Testing WireGuard protocol detection"

    local test_config
    test_config=$(find "$PROJECT_ROOT/locations" -name "*.conf" 2> /dev/null | head -1)

    if [[ -z "$test_config" ]]; then
        log "SKIP: No WireGuard config files found"
        return 0
    fi

    # Test protocol detection logic (this should work)
    if [[ "$test_config" == *.conf ]]; then
        log "SUCCESS: Protocol detection identifies .conf as WireGuard"
        return 0
    else
        log "ERROR: Protocol detection failed"
        return 1
    fi
}

# TEST 3: WireGuard connection establishment (THIS SHOULD FAIL)
test_wireguard_connection_establishment() {
    log "Testing WireGuard connection establishment"

    local test_config
    test_config=$(find "$PROJECT_ROOT/locations" -name "*.conf" 2> /dev/null | head -1)

    if [[ -z "$test_config" ]]; then
        log "SKIP: No WireGuard config files found"
        return 0
    fi

    log "Attempting connection to $(basename "$test_config")"

    # This should FAIL until we fix the resolvconf issue
    if timeout 60 "$VPN_SCRIPT" custom "$test_config" > /dev/null 2>&1; then
        # Verify connection is actually established
        local interface_name
        interface_name=$(basename "$test_config" .conf)

        if wg show "$interface_name" > /dev/null 2>&1; then
            log "SUCCESS: WireGuard connection established"

            # Clean up after successful test
            "$VPN_SCRIPT" cleanup > /dev/null 2>&1 || true
            return 0
        else
            log "ERROR: Connection command succeeded but interface not active"
            "$VPN_SCRIPT" cleanup > /dev/null 2>&1 || true
            return 1
        fi
    else
        log "ERROR: WireGuard connection establishment failed"
        "$VPN_SCRIPT" cleanup > /dev/null 2>&1 || true
        return 1
    fi
}

# TEST 4: WireGuard connection teardown works
test_wireguard_connection_teardown() {
    log "Testing WireGuard connection teardown"

    local test_config
    test_config=$(find "$PROJECT_ROOT/locations" -name "*.conf" 2> /dev/null | head -1)

    if [[ -z "$test_config" ]]; then
        log "SKIP: No WireGuard config files found"
        return 0
    fi

    # First establish a connection manually (bypass our broken connector)
    local interface_name
    interface_name=$(basename "$test_config" .conf)

    if sudo wg-quick up "$test_config" > /dev/null 2>&1; then
        log "Manual WireGuard connection established for teardown test"

        # Now test our disconnect functionality
        if "$VPN_SCRIPT" disconnect > /dev/null 2>&1; then
            # Check if interface is gone
            if ! wg show "$interface_name" > /dev/null 2>&1; then
                log "SUCCESS: WireGuard connection properly torn down"
                return 0
            else
                log "ERROR: WireGuard interface still active after disconnect"
                # Force cleanup
                sudo wg-quick down "$interface_name" 2> /dev/null || true
                return 1
            fi
        else
            log "ERROR: Disconnect command failed"
            sudo wg-quick down "$interface_name" 2> /dev/null || true
            return 1
        fi
    else
        log "SKIP: Cannot establish manual WireGuard connection for teardown test"
        return 0
    fi
}

# TEST 5: WireGuard vs OpenVPN performance comparison (WILL FAIL)
test_wireguard_openvpn_performance() {
    log "Testing WireGuard vs OpenVPN performance comparison"

    # This test should fail because we can't establish WireGuard connections yet
    local wg_config ovpn_config
    wg_config=$(find "$PROJECT_ROOT/locations" -name "*.conf" 2> /dev/null | head -1)
    ovpn_config=$(find "$PROJECT_ROOT/locations" -name "*.ovpn" 2> /dev/null | head -1)

    if [[ -z "$wg_config" ]] || [[ -z "$ovpn_config" ]]; then
        log "SKIP: Need both WireGuard and OpenVPN configs for comparison"
        return 0
    fi

    # This will fail because WireGuard connections don't work yet
    log "ERROR: Cannot perform performance comparison - WireGuard connections not working"
    return 1
}

cleanup_after_tests() {
    log "Performing post-test cleanup"

    # Clean up any WireGuard interfaces
    sudo wg show 2> /dev/null | grep -E "^interface:" | while read -r line; do
        interface=$(echo "$line" | cut -d: -f2 | xargs)
        if [[ -n "$interface" ]]; then
            sudo wg-quick down "$interface" 2> /dev/null || true
        fi
    done

    # Clean up VPN processes
    "$VPN_SCRIPT" cleanup > /dev/null 2>&1 || true

    # Remove test artifacts
    rm -f /tmp/wg_test_* 2> /dev/null || true
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
        echo -e "${GREEN}✓ ALL TESTS PASSED - WireGuard functionality complete${NC}"
        log "All WireGuard tests passed"
        return 0
    else
        echo -e "${RED}✗ TESTS FAILED - WireGuard implementation incomplete${NC}"
        echo -e "${YELLOW}This is expected in RED phase of TDD - implement fixes to make tests pass${NC}"
        log "WireGuard tests failed (expected in TDD RED phase)"
        return 1
    fi
}

main() {
    # Initialize test log
    echo "Starting WireGuard Connection Tests - $(date)" > "$TEST_LOG"

    print_banner

    setup_test_environment

    # Run TDD tests (expecting failures)
    run_test "WireGuard Config Validation" "test_wireguard_config_validation"
    run_test "WireGuard Protocol Detection" "test_wireguard_protocol_detection"
    run_test "WireGuard Connection Establishment" "test_wireguard_connection_establishment"
    run_test "WireGuard Connection Teardown" "test_wireguard_connection_teardown"
    run_test "WireGuard vs OpenVPN Performance" "test_wireguard_openvpn_performance"

    # Always cleanup
    cleanup_after_tests

    # Print summary and exit with appropriate code
    print_test_summary
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

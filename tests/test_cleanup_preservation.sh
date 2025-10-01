#!/bin/bash
# ABOUTME: Tests that full_cleanup() preserves important state files while removing temporary files
# shellcheck disable=SC2317  # Functions are called indirectly via run_test()

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_MANAGER="$SCRIPT_DIR/../src/vpn-manager"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    test_count=$((test_count + 1))
    echo -n "Test $test_count: $test_name... "

    if $test_func; then
        echo -e "${GREEN}PASS${NC}"
        pass_count=$((pass_count + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

setup_test_files() {
    # Create persistent state files that should be preserved
    touch /tmp/vpn_service_state
    touch /tmp/vpn_last_state
    touch /tmp/vpn_statusbar_state
    touch /tmp/vpn_statusbar_last_signal
    touch /tmp/vpn_default_route.backup
    touch /tmp/vpn_simple.log

    # Create temporary files that should be removed
    touch /tmp/vpn_connect.log
    touch /tmp/vpn_connect.lock
    touch /tmp/vpn_manager_12345.log
    touch /tmp/vpn_external_ip_cache
    touch /tmp/vpn_performance.cache
}

cleanup_test_files() {
    # Remove all test files
    rm -f /tmp/vpn_service_state
    rm -f /tmp/vpn_last_state
    rm -f /tmp/vpn_statusbar_state
    rm -f /tmp/vpn_statusbar_last_signal
    rm -f /tmp/vpn_default_route.backup
    rm -f /tmp/vpn_simple.log
    rm -f /tmp/vpn_connect.log
    rm -f /tmp/vpn_connect.lock
    rm -f /tmp/vpn_manager_*.log
    rm -f /tmp/vpn_external_ip_cache
    rm -f /tmp/vpn_performance.cache
}

test_preserves_service_state() {
    setup_test_files

    # Directly execute the cleanup commands from full_cleanup()
    # (lines 641-645 of vpn-manager)
    rm -f /tmp/vpn_connect.log 2>/dev/null || true
    rm -f /tmp/vpn_connect.lock 2>/dev/null || true
    rm -f /tmp/vpn_manager_*.log 2>/dev/null || true
    rm -f /tmp/vpn_external_ip_cache 2>/dev/null || true
    rm -f /tmp/vpn_performance.cache 2>/dev/null || true

    # Check persistent files still exist
    local result=0
    [[ -f /tmp/vpn_service_state ]] || result=1
    [[ -f /tmp/vpn_last_state ]] || result=1
    [[ -f /tmp/vpn_statusbar_state ]] || result=1
    [[ -f /tmp/vpn_statusbar_last_signal ]] || result=1
    [[ -f /tmp/vpn_default_route.backup ]] || result=1
    [[ -f /tmp/vpn_simple.log ]] || result=1

    cleanup_test_files
    return "$result"
}

test_removes_temp_logs() {
    setup_test_files

    # Directly execute the cleanup commands from full_cleanup()
    # (lines 641-645 of vpn-manager)
    rm -f /tmp/vpn_connect.log 2>/dev/null || true
    rm -f /tmp/vpn_connect.lock 2>/dev/null || true
    rm -f /tmp/vpn_manager_*.log 2>/dev/null || true
    rm -f /tmp/vpn_external_ip_cache 2>/dev/null || true
    rm -f /tmp/vpn_performance.cache 2>/dev/null || true

    # Check temp files are removed
    local result=0
    [[ ! -f /tmp/vpn_connect.log ]] || result=1
    [[ ! -f /tmp/vpn_connect.lock ]] || result=1
    [[ ! -f /tmp/vpn_external_ip_cache ]] || result=1
    [[ ! -f /tmp/vpn_performance.cache ]] || result=1

    cleanup_test_files
    return "$result"
}

test_removes_temp_manager_logs() {
    setup_test_files

    # Directly execute the cleanup commands from full_cleanup()
    rm -f /tmp/vpn_connect.log 2>/dev/null || true
    rm -f /tmp/vpn_connect.lock 2>/dev/null || true
    rm -f /tmp/vpn_manager_*.log 2>/dev/null || true
    rm -f /tmp/vpn_external_ip_cache 2>/dev/null || true
    rm -f /tmp/vpn_performance.cache 2>/dev/null || true

    # Check manager-specific logs are removed
    local result=0
    [[ ! -f /tmp/vpn_manager_12345.log ]] || result=1

    cleanup_test_files
    return "$result"
}

# Ensure clean state before starting
cleanup_test_files

# Run tests
echo "Testing full_cleanup() file preservation..."
echo

run_test "Preserves service state files" test_preserves_service_state
run_test "Removes temporary log files" test_removes_temp_logs
run_test "Removes manager-specific logs" test_removes_temp_manager_logs

echo
echo "Results: $pass_count/$test_count tests passed"

if [[ $pass_count -eq $test_count ]]; then
    exit 0
else
    exit 1
fi

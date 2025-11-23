#!/bin/bash
# ABOUTME: Unit tests for vpn-kill-switch firewall-based leak protection
# ABOUTME: Tests iptables rule management, state tracking, and safety features

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/../test_framework.sh"

# PROJECT_DIR is set by test_framework.sh to project root
KILL_SWITCH_SCRIPT="$PROJECT_DIR/src/vpn-kill-switch"

# Test: vpn-kill-switch script exists
test_kill_switch_script_exists() {
    start_test "vpn-kill-switch script exists in src/ directory"

    if [[ -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "PASS" "$CURRENT_TEST: Script file found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Script not found at src/vpn-kill-switch"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch script is executable
test_kill_switch_script_executable() {
    start_test "vpn-kill-switch script is executable"

    if [[ -x "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "PASS" "$CURRENT_TEST: Script has executable permissions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Script is not executable"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch has ABOUTME header
test_kill_switch_has_aboutme_header() {
    start_test "vpn-kill-switch has ABOUTME header comments"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    local aboutme_count
    aboutme_count=$(grep -c "^# ABOUTME:" "$KILL_SWITCH_SCRIPT" 2>/dev/null || echo 0)

    if [[ $aboutme_count -ge 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Found $aboutme_count ABOUTME comments"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Expected 2+ ABOUTME comments, found $aboutme_count"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch sources required dependencies
test_kill_switch_sources_dependencies() {
    start_test "vpn-kill-switch sources vpn-colors and vpn-error-handler"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    local has_colors
    local has_errors
    has_colors=$(grep -c 'source.*vpn-colors' "$KILL_SWITCH_SCRIPT" 2>/dev/null || echo 0)
    has_errors=$(grep -c 'source.*vpn-error-handler' "$KILL_SWITCH_SCRIPT" 2>/dev/null || echo 0)

    if [[ $has_colors -gt 0 ]] && [[ $has_errors -gt 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Sources both required components"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Missing required source statements (colors=$has_colors, errors=$has_errors)"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch has status command
test_kill_switch_has_status_command() {
    start_test "vpn-kill-switch responds to 'status' command"

    if [[ ! -x "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist or not executable"
        return
    fi

    local output
    output=$("$KILL_SWITCH_SCRIPT" status 2>&1)
    local exit_code=$?

    # Status command should succeed (exit 0) and produce output
    if [[ $exit_code -eq 0 ]] && [[ -n "$output" ]]; then
        log_test "PASS" "$CURRENT_TEST: Status command works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Status command failed (exit=$exit_code, output='$output')"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch has is-enabled function
test_kill_switch_has_is_enabled() {
    start_test "vpn-kill-switch has 'is-enabled' command for scripting"

    if [[ ! -x "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist or not executable"
        return
    fi

    # is-enabled should return exit code only (0=enabled, 1=disabled)
    "$KILL_SWITCH_SCRIPT" is-enabled 2>/dev/null
    local exit_code=$?

    # Should return 0 or 1, not fail with usage error
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        log_test "PASS" "$CURRENT_TEST: is-enabled returns valid exit code ($exit_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: is-enabled returned unexpected code $exit_code"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch has help command
test_kill_switch_has_help() {
    start_test "vpn-kill-switch shows help with 'help' command"

    if [[ ! -x "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist or not executable"
        return
    fi

    local output
    output=$("$KILL_SWITCH_SCRIPT" help 2>&1)

    if [[ "$output" == *"enable"* ]] && [[ "$output" == *"disable"* ]] && [[ "$output" == *"status"* ]]; then
        log_test "PASS" "$CURRENT_TEST: Help shows required commands"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Help output missing expected commands"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch detects iptables availability
test_kill_switch_detects_iptables() {
    start_test "vpn-kill-switch can detect iptables"

    if [[ ! -x "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist or not executable"
        return
    fi

    # The status output should mention iptables if available
    local output
    output=$("$KILL_SWITCH_SCRIPT" status 2>&1)

    # Should not fail with "iptables not found" if iptables is installed
    if command -v iptables &>/dev/null; then
        if [[ "$output" != *"not found"* ]] && [[ "$output" != *"not installed"* ]]; then
            log_test "PASS" "$CURRENT_TEST: iptables detected correctly"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "FAIL" "$CURRENT_TEST: Failed to detect installed iptables"
            FAILED_TESTS+=("$CURRENT_TEST")
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "SKIP" "$CURRENT_TEST: iptables not installed on system"
    fi
}

# Test: vpn-kill-switch uses dedicated chain name
test_kill_switch_uses_dedicated_chain() {
    start_test "vpn-kill-switch uses VPN_KILL_SWITCH chain name"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "VPN_KILL_SWITCH" "$KILL_SWITCH_SCRIPT"; then
        log_test "PASS" "$CURRENT_TEST: Uses dedicated chain name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should use VPN_KILL_SWITCH chain for isolation"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch handles IPv6
test_kill_switch_handles_ipv6() {
    start_test "vpn-kill-switch handles IPv6 leak protection"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    if grep -q "ip6tables" "$KILL_SWITCH_SCRIPT"; then
        log_test "PASS" "$CURRENT_TEST: Handles IPv6 with ip6tables"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should handle IPv6 to prevent leaks"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch preserves loopback
test_kill_switch_preserves_loopback() {
    start_test "vpn-kill-switch allows loopback traffic"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    # Should have a rule allowing loopback (lo interface or 127.0.0.0/8)
    if grep -qE "(127\.0\.0|lo)" "$KILL_SWITCH_SCRIPT"; then
        log_test "PASS" "$CURRENT_TEST: Allows loopback traffic"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should preserve loopback traffic"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: vpn-kill-switch has state file tracking
test_kill_switch_has_state_tracking() {
    start_test "vpn-kill-switch tracks state in a file"

    if [[ ! -f "$KILL_SWITCH_SCRIPT" ]]; then
        log_test "SKIP" "$CURRENT_TEST: Script doesn't exist yet"
        return
    fi

    # Should reference a state file for tracking enable/disable state
    if grep -qE "(STATE_FILE|state_file|\.state|/state/)" "$KILL_SWITCH_SCRIPT"; then
        log_test "PASS" "$CURRENT_TEST: Has state tracking mechanism"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should track state for crash recovery"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all tests
run_tests() {
    echo "=== Kill Switch Unit Tests ==="
    echo ""

    test_kill_switch_script_exists
    test_kill_switch_script_executable
    test_kill_switch_has_aboutme_header
    test_kill_switch_sources_dependencies
    test_kill_switch_has_status_command
    test_kill_switch_has_is_enabled
    test_kill_switch_has_help
    test_kill_switch_detects_iptables
    test_kill_switch_uses_dedicated_chain
    test_kill_switch_handles_ipv6
    test_kill_switch_preserves_loopback
    test_kill_switch_has_state_tracking

    echo ""
    show_test_summary
}

# Main execution
run_tests

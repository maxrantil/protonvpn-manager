#!/bin/bash
# ABOUTME: Unit tests for VPN auto-reconnect security hardening (Issue #227)
# ABOUTME: Tests dispatcher hook, config management, state management, and security checks

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/../test_framework.sh"

# PROJECT_DIR is set by test_framework.sh to project root
DISPATCHER_HOOK="$PROJECT_DIR/etc/NetworkManager/dispatcher.d/50-vpn-reconnect"
VPN_MANAGER="$PROJECT_DIR/src/vpn-manager"
VPN_CONNECTOR="$PROJECT_DIR/src/vpn-connector"
# shellcheck disable=SC2034  # KILL_SWITCH used by test functions for reference
KILL_SWITCH="$PROJECT_DIR/src/vpn-kill-switch"

# Test temp directory
TEST_STATE_DIR=""
TEST_CONFIG_DIR=""

setup_test_dirs() {
    TEST_STATE_DIR=$(mktemp -d)
    TEST_CONFIG_DIR=$(mktemp -d)
    export XDG_STATE_HOME="$TEST_STATE_DIR"
    export XDG_CONFIG_HOME="$TEST_CONFIG_DIR"
    mkdir -p "$TEST_CONFIG_DIR/vpn"
    mkdir -p "$TEST_STATE_DIR/vpn"
}

cleanup_test_dirs() {
    [[ -d "$TEST_STATE_DIR" ]] && rm -rf "$TEST_STATE_DIR"
    [[ -d "$TEST_CONFIG_DIR" ]] && rm -rf "$TEST_CONFIG_DIR"
    unset XDG_STATE_HOME
    unset XDG_CONFIG_HOME
}

# ============================================================================
# DISPATCHER HOOK TESTS
# ============================================================================

test_dispatcher_hook_exists() {
    start_test "Dispatcher hook exists in etc/NetworkManager/dispatcher.d/"

    if [[ -f "$DISPATCHER_HOOK" ]]; then
        log_test "PASS" "$CURRENT_TEST: Hook file found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Hook not found at $DISPATCHER_HOOK"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_executable() {
    start_test "Dispatcher hook is executable"

    if [[ -x "$DISPATCHER_HOOK" ]]; then
        log_test "PASS" "$CURRENT_TEST: Hook has executable permissions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Hook is not executable"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_has_aboutme() {
    start_test "Dispatcher hook has ABOUTME header comments"

    local aboutme_count
    aboutme_count=$(grep -c "^# ABOUTME:" "$DISPATCHER_HOOK" 2>/dev/null || echo 0)

    if [[ $aboutme_count -ge 2 ]]; then
        log_test "PASS" "$CURRENT_TEST: Found $aboutme_count ABOUTME comments"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Expected 2+ ABOUTME comments, found $aboutme_count"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_validates_interface() {
    start_test "Dispatcher hook validates interface name format"

    # Check for interface validation regex
    if grep -q '\[a-zA-Z0-9_-\]' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Interface validation found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Interface validation not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_validates_action() {
    start_test "Dispatcher hook whitelists actions (up|connectivity-change)"

    if grep -q 'up|connectivity-change' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Action whitelist found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Action whitelist not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_checks_kill_switch() {
    start_test "Dispatcher hook requires kill switch enabled"

    if grep -q 'is-enabled' "$DISPATCHER_HOOK" && grep -q 'kill.*switch' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Kill switch check found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Kill switch check not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_uses_flock() {
    start_test "Dispatcher hook uses flock for exclusive locking"

    if grep -q 'flock' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: flock usage found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: flock not used"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_checks_cooldown() {
    start_test "Dispatcher hook implements cooldown between attempts"

    if grep -q 'COOLDOWN' "$DISPATCHER_HOOK" && grep -q 'elapsed' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Cooldown logic found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Cooldown logic not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_checks_max_attempts() {
    start_test "Dispatcher hook enforces max attempts per window"

    if grep -q 'MAX_ATTEMPTS' "$DISPATCHER_HOOK" && grep -q 'recent_attempts' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Max attempts logic found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Max attempts logic not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_rejects_symlinks() {
    start_test "Dispatcher hook rejects symlink profiles (security)"

    if grep -q '\-L.*profile' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Symlink rejection found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Symlink rejection not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_validates_profile_path() {
    start_test "Dispatcher hook validates profile is in allowed directories"

    if grep -q 'allowed.directories\|config_locations\|/etc/openvpn' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Path validation found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Path validation not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dispatcher_hook_checks_integrity_hash() {
    start_test "Dispatcher hook validates profile integrity (SHA256)"

    if grep -q 'sha256sum' "$DISPATCHER_HOOK" && grep -q 'LAST_PROFILE_HASH' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Integrity checking found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Integrity checking not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# CONFIG MANAGEMENT TESTS
# ============================================================================

test_config_command_exists() {
    start_test "vpn-manager config command exists"

    if grep -q '"config"' "$VPN_MANAGER" || grep -q 'config.*cfg' "$VPN_MANAGER"; then
        log_test "PASS" "$CURRENT_TEST: Config command found in vpn-manager"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Config command not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_config_auto_reconnect_on() {
    start_test "vpn config auto-reconnect on enables setting"

    setup_test_dirs

    # Run the config command
    "$VPN_MANAGER" config auto-reconnect on >/dev/null 2>&1

    local config_file="$TEST_CONFIG_DIR/vpn/config"
    if [[ -f "$config_file" ]] && grep -q "AUTO_RECONNECT=true" "$config_file"; then
        log_test "PASS" "$CURRENT_TEST: AUTO_RECONNECT=true set in config"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: AUTO_RECONNECT not set correctly"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_dirs
}

test_config_auto_reconnect_off() {
    start_test "vpn config auto-reconnect off disables setting"

    setup_test_dirs

    # Enable first, then disable
    "$VPN_MANAGER" config auto-reconnect on >/dev/null 2>&1
    "$VPN_MANAGER" config auto-reconnect off >/dev/null 2>&1

    local config_file="$TEST_CONFIG_DIR/vpn/config"
    if [[ -f "$config_file" ]] && grep -q "AUTO_RECONNECT=false" "$config_file"; then
        log_test "PASS" "$CURRENT_TEST: AUTO_RECONNECT=false set in config"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: AUTO_RECONNECT not set correctly"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_dirs
}

test_config_file_has_secure_permissions() {
    start_test "Config file has secure permissions (600)"

    setup_test_dirs

    "$VPN_MANAGER" config auto-reconnect on >/dev/null 2>&1

    local config_file="$TEST_CONFIG_DIR/vpn/config"
    if [[ -f "$config_file" ]]; then
        local perms
        perms=$(stat -c %a "$config_file" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            log_test "PASS" "$CURRENT_TEST: Config file has 600 permissions"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "FAIL" "$CURRENT_TEST: Config file has $perms permissions, expected 600"
            FAILED_TESTS+=("$CURRENT_TEST")
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Config file not created"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_dirs
}

# ============================================================================
# STATE MANAGEMENT TESTS
# ============================================================================

test_save_reconnect_state_function_exists() {
    start_test "save_reconnect_state function exists in vpn-connector"

    if grep -q 'save_reconnect_state()' "$VPN_CONNECTOR"; then
        log_test "PASS" "$CURRENT_TEST: Function found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Function not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_save_reconnect_state_saves_profile() {
    start_test "save_reconnect_state saves profile path"

    if grep -q 'last_profile' "$VPN_CONNECTOR" && grep -q 'state_dir' "$VPN_CONNECTOR"; then
        log_test "PASS" "$CURRENT_TEST: Profile saving logic found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Profile saving logic not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_save_reconnect_state_saves_hash() {
    start_test "save_reconnect_state saves SHA256 hash"

    if grep -q 'sha256sum' "$VPN_CONNECTOR" && grep -q 'last_profile.sha256' "$VPN_CONNECTOR"; then
        log_test "PASS" "$CURRENT_TEST: Hash saving logic found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Hash saving logic not found"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_handle_connection_success_calls_save_state() {
    start_test "handle_connection_success calls save_reconnect_state"

    if grep -A 20 'handle_connection_success()' "$VPN_CONNECTOR" | grep -q 'save_reconnect_state'; then
        log_test "PASS" "$CURRENT_TEST: State saving called on success"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: State saving not called on success"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# SECURITY REQUIREMENTS TESTS
# ============================================================================

test_security_auto_reconnect_disabled_by_default() {
    start_test "Auto-reconnect is disabled by default"

    if grep -q 'AUTO_RECONNECT.*false\|AUTO_RECONNECT="false"' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Default is disabled"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Default should be disabled"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_security_default_cooldown_30s() {
    start_test "Default cooldown is 30 seconds"

    if grep -q 'DEFAULT_COOLDOWN=30' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Default cooldown is 30s"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Default cooldown not 30s"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_security_default_max_attempts_3() {
    start_test "Default max attempts is 3"

    if grep -q 'DEFAULT_MAX_ATTEMPTS=3' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST: Default max attempts is 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Default max attempts not 3"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_security_logs_security_events() {
    start_test "Dispatcher hook logs security events"

    local security_logs
    security_logs=$(grep -c 'SECURITY' "$DISPATCHER_HOOK" 2>/dev/null || echo 0)

    if [[ $security_logs -ge 3 ]]; then
        log_test "PASS" "$CURRENT_TEST: Found $security_logs security log statements"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Expected 3+ security logs, found $security_logs"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run the hook's real check_kill_switch with a stubbed kill switch, VPN health
# check and logger. Prints "rc=<status>" and then every logged event.
# $1: kill switch is-enabled exit status, $2: vpn_is_healthy exit status
run_check_kill_switch() {
    local ks_status="$1" healthy_status="$2"
    local work
    work=$(mktemp -d)
    printf '#!/bin/sh\nexit %s\n' "$ks_status" > "$work/kill-switch"
    chmod +x "$work/kill-switch"

    (
        # shellcheck disable=SC1090  # function extracted from the hook under test
        source <(sed -n '/^check_kill_switch() {$/,/^}$/p' "$DISPATCHER_HOOK")
        # shellcheck disable=SC2034  # read by the sourced check_kill_switch
        KILL_SWITCH="$work/kill-switch"
        # shellcheck disable=SC2034
        REAL_HOME="$work"
        log_event() { printf '%s %s\n' "$1" "$2" >> "$work/events"; }
        vpn_is_healthy() { return "$healthy_status"; }
        local rc=0
        check_kill_switch || rc=$?
        echo "rc=$rc"
        cat "$work/events" 2> /dev/null || true
    )
    rm -rf "$work"
}

assert_check_kill_switch() {
    local name="$1" ks_status="$2" healthy_status="$3" expected="$4"
    start_test "$name"

    local output
    output=$(run_check_kill_switch "$ks_status" "$healthy_status")

    if [[ "$output" == "$expected" ]]; then
        log_test "PASS" "$CURRENT_TEST"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: expected '$expected', got '$output'"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_kill_switch_off_vpn_healthy_is_silent() {
    assert_check_kill_switch "Kill switch off, VPN healthy: no reconnect, nothing logged" \
        1 0 "rc=1"
}

test_kill_switch_off_vpn_down_logs_refusal() {
    assert_check_kill_switch "Kill switch off, VPN down: refusal logged" \
        1 1 $'rc=1\nSECURITY Auto-reconnect blocked: kill switch not enabled'
}

test_kill_switch_on_passes_silently() {
    assert_check_kill_switch "Kill switch on: check passes, nothing logged" \
        0 1 "rc=0"
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Auto-Reconnect Security Tests (Issue #227)"
    echo "=============================================="
    echo ""

    # Dispatcher hook tests
    test_dispatcher_hook_exists
    test_dispatcher_hook_executable
    test_dispatcher_hook_has_aboutme
    test_dispatcher_hook_validates_interface
    test_dispatcher_hook_validates_action
    test_dispatcher_hook_checks_kill_switch
    test_dispatcher_hook_uses_flock
    test_dispatcher_hook_checks_cooldown
    test_dispatcher_hook_checks_max_attempts
    test_dispatcher_hook_rejects_symlinks
    test_dispatcher_hook_validates_profile_path
    test_dispatcher_hook_checks_integrity_hash
    test_kill_switch_off_vpn_healthy_is_silent
    test_kill_switch_off_vpn_down_logs_refusal
    test_kill_switch_on_passes_silently

    # Config management tests
    test_config_command_exists
    test_config_auto_reconnect_on
    test_config_auto_reconnect_off
    test_config_file_has_secure_permissions

    # State management tests
    test_save_reconnect_state_function_exists
    test_save_reconnect_state_saves_profile
    test_save_reconnect_state_saves_hash
    test_handle_connection_success_calls_save_state

    # Security requirements tests
    test_security_auto_reconnect_disabled_by_default
    test_security_default_cooldown_30s
    test_security_default_max_attempts_3
    test_security_logs_security_events

    # Print summary
    show_test_summary

    # Return appropriate exit code
    [[ ${#FAILED_TESTS[@]} -eq 0 ]]
}

main "$@"

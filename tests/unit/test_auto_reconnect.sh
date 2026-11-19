#!/bin/bash
# ABOUTME: Unit tests for VPN auto-reconnect security hardening (Issue #227)
# ABOUTME: Tests dispatcher hook, config management, state management, and security checks

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/../test_framework.sh"

# PROJECT_DIR is set by test_framework.sh to project root
DISPATCHER_HOOK="$PROJECT_DIR/etc/NetworkManager/dispatcher.d/50-vpn-reconnect"
VPN_UTILS="$PROJECT_DIR/src/vpn-utils"
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
# check and logger. Prints "rc=<status>", then every logged event, then
# "health-checked" if vpn_is_healthy was called.
# $1: kill switch is-enabled exit status, $2: vpn_is_healthy exit status
run_check_kill_switch() {
    local ks_status="$1" healthy_status="$2"
    local work
    work=$(mktemp -d)
    printf '#!/bin/sh\nexit %s\n' "$ks_status" > "$work/kill-switch"
    chmod +x "$work/kill-switch"

    if ! grep -q '^check_kill_switch() {$' "$DISPATCHER_HOOK"; then
        echo "check_kill_switch() not found in $DISPATCHER_HOOK"
        rm -rf "$work"
        return
    fi

    (
        # shellcheck disable=SC1090  # function extracted from the hook under test
        source <(sed -n '/^check_kill_switch() {$/,/^}$/p' "$DISPATCHER_HOOK")
        # shellcheck disable=SC2034  # read by the sourced check_kill_switch
        KILL_SWITCH="$work/kill-switch"
        # shellcheck disable=SC2034
        REAL_HOME="$work"
        log_event() { printf '%s %s\n' "$1" "$2" >> "$work/events"; }
        vpn_is_healthy() {
            touch "$work/health-checked"
            return "$healthy_status"
        }
        rc=0
        check_kill_switch || rc=$?
        echo "rc=$rc"
        cat "$work/events" 2> /dev/null || true
        [[ -e "$work/health-checked" ]] && echo "health-checked"
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

test_kill_switch_off_vpn_healthy_logs_info() {
    assert_check_kill_switch "Kill switch off, VPN healthy: no reconnect, INFO not SECURITY" \
        1 0 $'rc=1\nINFO Kill switch not enabled; VPN up, no reconnect needed\nhealth-checked'
}

test_kill_switch_off_vpn_down_logs_refusal() {
    assert_check_kill_switch "Kill switch off, VPN down: refusal logged" \
        1 1 $'rc=1\nSECURITY Auto-reconnect blocked: kill switch not enabled\nhealth-checked'
}

test_kill_switch_on_passes_silently() {
    assert_check_kill_switch "Kill switch on: passes, nothing logged, health not checked" \
        0 1 "rc=0"
}

# Run the real vpn_is_healthy (vpn-utils, shared by the dispatcher hooks)
# against a fake /proc, PID file and
# interface list; prints "rc=<status>". Nothing real is inspected, so the
# result does not depend on a VPN this machine may have up.
# $1: PID file ("trusted", "missing", "user-owned", "symlink")
# $2: the PID's process ("ours", "stale" (none), "other-config", "not-openvpn",
#     "user-run" (ours, but not running as root))
# $3: tun0 ("up", "down", "missing")
# $4: WireGuard ("none", "foreign")
run_vpn_is_healthy() {
    local pidfile_state="$1" process="$2" tun0="$3" wg="$4"
    local work
    work=$(mktemp -d)
    mkdir -p "$work/bin" "$work/proc"

    if ! grep -q '^vpn_is_healthy() {$' "$VPN_UTILS"; then
        echo "vpn_is_healthy() not found in $VPN_UTILS"
        rm -rf "$work"
        return
    fi

    local pid=4242 profile="/run/protonvpn-manager-session/profile.ovpn"
    case "$pidfile_state" in
        trusted | user-owned) echo "$pid" > "$work/openvpn.pid" ;;
        symlink)
            echo "$pid" > "$work/elsewhere.pid"
            ln -s "$work/elsewhere.pid" "$work/openvpn.pid"
            ;;
    esac
    # stat -c %u: the PID file's owner, or the process's (its /proc dir)
    local owner=0 proc_owner=0
    [[ $pidfile_state == user-owned ]] && owner=1000
    [[ $process == user-run ]] && proc_owner=1000
    cat > "$work/bin/stat" << STUB
#!/bin/bash
[[ \$* == *"$work/proc/"* ]] && echo $proc_owner || echo $owner
STUB

    case "$process" in
        ours | other-config | not-openvpn | user-run)
            mkdir -p "$work/proc/$pid"
            local comm=openvpn config="$profile"
            [[ $process == not-openvpn ]] && comm="sleep"
            [[ $process == other-config ]] && config=/etc/openvpn/client/work.conf
            echo "$comm" > "$work/proc/$pid/comm"
            printf '/usr/bin/openvpn\0--config\0%s\0--daemon\0' "$config" > "$work/proc/$pid/cmdline"
            ;;
    esac

    # ip: tun0's state, and any WireGuard interface
    local tun_line="" wg_line=""
    [[ $tun0 == up ]] && tun_line="28: tun0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1500"
    [[ $tun0 == down ]] && tun_line="28: tun0: <POINTOPOINT,NOARP> mtu 1500"
    [[ $wg == foreign ]] && wg_line="9: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420"
    cat > "$work/bin/ip" << STUB
#!/bin/bash
args="\$*"
if [[ \$args == *"type wireguard"* ]]; then
    [[ -n "$wg_line" ]] && echo "$wg_line"
    exit 0
fi
if [[ \$args == *tun0* ]]; then
    [[ -z "$tun_line" ]] && exit 1
    # "up" lists the interface only when it is administratively up
    [[ \$args == *" up"* && "$tun_line" != *",UP,"* ]] && exit 0
    echo "$tun_line"
    exit 0
fi
exit 0
STUB
    # wg and pgrep: a foreign WireGuard tunnel, and an openvpn running somewhere
    printf '#!/bin/sh\n[ "%s" = foreign ] && echo "interface: wg0"\nexit 0\n' "$wg" > "$work/bin/wg"
    printf '#!/bin/sh\necho 999\nexit 0\n' > "$work/bin/pgrep"
    chmod +x "$work/bin/"*

    (
        # The hook's own shell options
        set -euo pipefail
        # As the hooks do: source the library, then set the fixed constants
        # shellcheck source=src/vpn-utils
        source "$VPN_UTILS"
        # shellcheck disable=SC2034  # read by the sourced vpn_is_healthy
        VPN_PID_FILE="$work/openvpn.pid"
        # shellcheck disable=SC2034
        VPN_PROC_DIR="$work/proc"
        # shellcheck disable=SC2034
        VPN_SESSION_PROFILE="$profile"
        # shellcheck disable=SC2034
        VPN_TUNNEL_INTERFACE=tun0
        PATH="$work/bin:$PATH"
        # Called as the hook calls it: as an if condition
        if vpn_is_healthy > /dev/null 2>&1; then
            echo "rc=0"
        else
            echo "rc=1"
        fi
    )
    rm -rf "$work"
}

assert_vpn_is_healthy() {
    local name="$1" expected="$2"
    shift 2
    start_test "$name"

    local output
    output=$(run_vpn_is_healthy "$@")

    if [[ "$output" == "rc=$expected" ]]; then
        log_test "PASS" "$CURRENT_TEST"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: expected 'rc=$expected', got '$output'"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_vpn_is_healthy_only_for_this_tools_vpn() {
    assert_vpn_is_healthy "Healthy: this tool's openvpn (root PID file) and tun0 up" 0 \
        trusted ours up none
    assert_vpn_is_healthy "Not healthy: stale openvpn PID file, no process, no tun0" 1 \
        trusted stale missing none
    assert_vpn_is_healthy "Not healthy: this tool's openvpn alive but no tun0" 1 \
        trusted ours missing none
    assert_vpn_is_healthy "Not healthy: tun0 exists but is down" 1 \
        trusted ours down none
    assert_vpn_is_healthy "Not healthy: a foreign tun0 and some openvpn, no PID file" 1 \
        missing stale up none
    assert_vpn_is_healthy "Not healthy: the PID is an openvpn with another config" 1 \
        trusted other-config up none
    assert_vpn_is_healthy "Not healthy: the PID is not openvpn" 1 \
        trusted not-openvpn up none
    assert_vpn_is_healthy "Not healthy: a PID file not owned by root" 1 \
        user-owned ours up none
    assert_vpn_is_healthy "Not healthy: a symlinked PID file" 1 \
        symlink ours up none
    assert_vpn_is_healthy "Not healthy: only a foreign WireGuard interface" 1 \
        missing stale missing foreign
    assert_vpn_is_healthy "Not healthy: a foreign WireGuard interface and no tun0" 1 \
        trusted ours missing foreign
    assert_vpn_is_healthy "Not healthy: tun0 up but the PID file's process is gone" 1 \
        trusted stale up none
    assert_vpn_is_healthy "Not healthy: the PID is an openvpn a user runs (reused PID)" 1 \
        trusted user-run up none
}

# The health check lives in vpn-utils, shared with 40-vpn-dns-repair; the
# reconnect hook keeps its fixed constants and uses the shared function
test_vpn_is_healthy_shared() {
    start_test "vpn_is_healthy is shared from vpn-utils, not defined in the hook"
    if ! grep -q '^vpn_is_healthy() {$' "$DISPATCHER_HOOK" &&
        grep -q '^vpn_is_healthy() {$' "$VPN_UTILS" &&
        grep -q '^VPN_PID_FILE="/var/run/openvpn.pid"$' "$DISPATCHER_HOOK"; then
        log_test "PASS" "$CURRENT_TEST"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST"
        FAILED_TESTS+=("$CURRENT_TEST")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
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
    test_kill_switch_off_vpn_healthy_logs_info
    test_kill_switch_off_vpn_down_logs_refusal
    test_kill_switch_on_passes_silently
    test_vpn_is_healthy_only_for_this_tools_vpn
    test_vpn_is_healthy_shared

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

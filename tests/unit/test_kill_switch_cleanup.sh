#!/bin/bash
# ABOUTME: Behavioural tests: disconnect/connect never leave a kill switch or VPN DNS behind
# ABOUTME: Covers dead-tunnel disconnect, signals (INT/TERM), stale state on connect, hooks
# shellcheck disable=SC2319  # `report $?` deliberately reports the [[ ]] check above it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

T_GREEN='\033[1;32m'
T_RED='\033[1;31m'
T_BLUE='\033[1;34m'
T_NC='\033[0m'

test_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${T_GREEN}✓${T_NC} $1"
}

test_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
    echo -e "  ${T_RED}✗${T_NC} $1"
    [[ -n "${2:-}" ]] && echo -e "    $2"
}

# report <exit-code> <name> [detail]
report() {
    if [[ $1 -eq 0 ]]; then
        test_pass "$2"
    else
        test_fail "$2" "${3:-}"
    fi
}

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Isolated environment: nothing here may touch the real system. The scripts
# prefer installed copies in /usr/local/bin, so every test points VPN_DIR at
# stubs and replaces sudo, resolvconf, pgrep and ip.
export HOME="$WORK_DIR/home"
export XDG_RUNTIME_DIR="$WORK_DIR/run"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export VPN_SESSION_DIR="$WORK_DIR/session"
export VPN_DNS_HELPER="$WORK_DIR/no-dns-helper"
export VPN_LOG_DIR="$XDG_STATE_HOME/vpn"
mkdir -p "$HOME/.config/vpn/locations" "$XDG_RUNTIME_DIR" "$VPN_LOG_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

STUB_DIR="$WORK_DIR/stub"    # replaces VPN_DIR (vpn-kill-switch, vpn-manager)
PATH_STUBS="$WORK_DIR/path"  # first on PATH (resolvconf, pgrep, ip, sudo)
CALLS="$WORK_DIR/calls.log"  # every stub appends what it was asked to do
KS_ON="$WORK_DIR/ks_enabled" # fake kill switch: enabled while this exists
DNS_ENTRIES="$WORK_DIR/resolvconf.entries"
VPN_UP="$WORK_DIR/openvpn_running"
export CALLS KS_ON DNS_ENTRIES VPN_UP
mkdir -p "$STUB_DIR" "$PATH_STUBS"

cat > "$STUB_DIR/vpn-kill-switch" << 'EOF'
#!/bin/bash
case "$1" in
    is-enabled) [[ -f $KS_ON ]] ;;
    disable | off) echo "kill-switch:disable" >> "$CALLS"; rm -f "$KS_ON" ;;
    enable | on) echo "kill-switch:enable" >> "$CALLS"; touch "$KS_ON" ;;
    *) echo "kill-switch:$*" >> "$CALLS" ;;
esac
EOF
cat > "$STUB_DIR/vpn-manager" << 'EOF'
#!/bin/bash
echo "manager:$*" >> "$CALLS"
EOF
cat > "$PATH_STUBS/resolvconf" << 'EOF'
#!/bin/bash
if [[ $1 == -i ]]; then
    [[ -f $DNS_ENTRIES ]] && tr '\n' ' ' < "$DNS_ENTRIES"
    exit 0
fi
echo "resolvconf:$*" >> "$CALLS"
if [[ $1 == -f && $2 == -d ]]; then
    grep -vxF -- "$3" "$DNS_ENTRIES" > "$DNS_ENTRIES.tmp"
    mv "$DNS_ENTRIES.tmp" "$DNS_ENTRIES"
fi
EOF
cat > "$PATH_STUBS/pgrep" << 'EOF'
#!/bin/bash
[[ $* == *openvpn* && -f $VPN_UP ]] && { echo 4242; exit 0; }
exit 1
EOF
cat > "$PATH_STUBS/ip" << 'EOF'
#!/bin/bash
exit 0
EOF
# Only the (stubbed) resolvconf may run; anything else is recorded, never run
cat > "$PATH_STUBS/sudo" << 'EOF'
#!/bin/bash
[[ $1 == -n ]] && shift
[[ $1 == resolvconf ]] && exec "$@"
echo "sudo:$*" >> "$CALLS"
EOF
chmod +x "$STUB_DIR"/* "$PATH_STUBS"/*

# Fresh state: kill switch on, VPN DNS + an unrelated entry registered, no VPN
reset_state() {
    : > "$CALLS"
    touch "$KS_ON"
    # tun1.inet: left by OpenVPN's update-resolv-conf script (older setups)
    printf '%s\n' tun0.protonvpn tun1.inet wlan0.dhcp > "$DNS_ENTRIES"
    rm -f "$VPN_UP" "$WORK_DIR/stopped"
    : > "$HOME/.config/vpn/config"
}

# Shell code that loads a script with every system access stubbed
# Args: $1 = script in src/ to source
stubbed_source() {
    cat << EOF
source "$SRC_DIR/$1" > /dev/null 2>&1
source "$SRC_DIR/vpn-utils"
set +e
VPN_DIR="$STUB_DIR"
PATH="$PATH_STUBS:\$PATH"
log_vpn_event() { :; }
log_message() { :; }
notify_event() { :; }
pkill() { :; }
EOF
}

dns_cleared() {
    grep -qx "resolvconf:-f -d tun0.protonvpn" "$CALLS" &&
        grep -qx "resolvconf:-f -d tun1.inet" "$CALLS" &&
        ! grep -q "wlan0.dhcp" "$CALLS"
}

# ---------------------------------------------------------------------------
# Disconnect
# ---------------------------------------------------------------------------

# The tunnel died (crash, KILL) but the kill switch and VPN DNS remain:
# `vpn disconnect` used to return early and leave all traffic blocked.
test_disconnect_with_dead_tunnel() {
    reset_state
    local rc=0
    bash -c "$(stubbed_source vpn-manager)
        is_vpn_running() { return 1; }
        cleanup_files() { :; }
        stop_vpn" > /dev/null 2>&1 || rc=$?
    [[ $rc -eq 0 ]]
    report $? "disconnect with a dead tunnel exits 0" "exit $rc"
    [[ ! -f $KS_ON ]]
    report $? "disconnect with a dead tunnel removes the kill switch" "$(cat "$CALLS")"
    dns_cleared
    report $? "disconnect with a dead tunnel removes only the VPN's DNS entry" "$(cat "$CALLS")"
}

# Shell code that makes stop_vpn see a running VPN that stops on TERM
running_vpn_stubs='
is_vpn_running() { [[ ! -f $WORK_DIR/stopped ]]; }
get_vpn_pid() { echo 4242; }
signal_openvpn_process() { touch "$WORK_DIR/stopped"; }
wait_for_pids_exit() { return 0; }
cleanup_files() { :; }
cleanup_routes_light() { :; }'

# A typed `vpn disconnect` means "give me my internet back", also with
# AUTO_RECONNECT=true (that used to keep the kill switch on).
test_disconnect_with_auto_reconnect() {
    reset_state
    echo "AUTO_RECONNECT=true" > "$HOME/.config/vpn/config"
    WORK_DIR="$WORK_DIR" bash -c "$(stubbed_source vpn-manager)
        $running_vpn_stubs
        stop_vpn" > /dev/null 2>&1
    [[ ! -f $KS_ON ]]
    report $? "disconnect removes the kill switch even with AUTO_RECONNECT=true" "$(cat "$CALLS")"
    dns_cleared
    report $? "disconnect removes the VPN DNS entry" "$(cat "$CALLS")"
}

# The sleep hook disconnects before suspend and must keep the protection
test_disconnect_keep_kill_switch() {
    reset_state
    WORK_DIR="$WORK_DIR" VPN_KEEP_KILL_SWITCH=1 bash -c "$(stubbed_source vpn-manager)
        $running_vpn_stubs
        stop_vpn" > /dev/null 2>&1
    [[ -f $KS_ON ]] && ! grep -q "kill-switch:disable" "$CALLS"
    report $? "VPN_KEEP_KILL_SWITCH=1 disconnect keeps the kill switch" "$(cat "$CALLS")"
    dns_cleared
    report $? "VPN_KEEP_KILL_SWITCH=1 disconnect still removes the VPN DNS entry" "$(cat "$CALLS")"
}

# Ctrl+C / SIGTERM during disconnect must not abort the cleanup halfway
# Args: $1 = signal name
test_disconnect_survives_signal() {
    local sig="$1" driver="$WORK_DIR/disconnect_driver.sh"
    reset_state
    {
        stubbed_source vpn-manager
        echo 'is_vpn_running() { return 1; }'
        # The signal arrives while cleanup is still running
        echo 'cleanup_files() { touch "$WORK_DIR/in_cleanup"; sleep 1; }'
        echo 'stop_vpn'
    } > "$driver"
    rm -f "$WORK_DIR/in_cleanup"

    # Job control: the driver gets its own process group and normal signal
    # handling, as `vpn disconnect` in a terminal does
    set -m
    WORK_DIR="$WORK_DIR" bash "$driver" > /dev/null 2>&1 &
    local pid=$!
    set +m
    for _ in $(seq 1 40); do
        [[ -f $WORK_DIR/in_cleanup ]] && break
        sleep 0.05
    done
    # Like a terminal Ctrl+C: the whole process group gets the signal
    kill -"$sig" -- "-$pid" 2> /dev/null
    wait "$pid" 2> /dev/null

    [[ ! -f $KS_ON ]]
    report $? "disconnect interrupted by SIG$sig still removes the kill switch" "$(cat "$CALLS")"
}

# ---------------------------------------------------------------------------
# Connect
# ---------------------------------------------------------------------------

# Runs begin_connect (the start of every connect command) with stubs
run_begin_connect() {
    bash -c "$(stubbed_source vpn-connector)
        check_dependencies() { return 0; }
        begin_connect" > /dev/null 2>&1
}

# A kill switch with no VPN behind it allows only the old server, so the
# latency check and every new server were blocked: connect could never work.
test_connect_clears_stale_state() {
    reset_state
    run_begin_connect
    [[ ! -f $KS_ON ]]
    report $? "connect removes a kill switch left without a VPN" "$(cat "$CALLS")"
    dns_cleared
    report $? "connect removes a stale VPN DNS entry" "$(cat "$CALLS")"
}

test_connect_keeps_live_vpn_state() {
    reset_state
    touch "$VPN_UP"
    run_begin_connect
    [[ -f $KS_ON ]] && ! grep -q "resolvconf:" "$CALLS"
    report $? "connect leaves kill switch and DNS alone while a VPN runs" "$(cat "$CALLS")"
}

# Hooks hold the kill switch across a reconnect on purpose
test_connect_keep_kill_switch() {
    reset_state
    VPN_KEEP_KILL_SWITCH=1 run_begin_connect
    [[ -f $KS_ON ]]
    report $? "VPN_KEEP_KILL_SWITCH=1 connect keeps the kill switch" "$(cat "$CALLS")"
}

test_begin_connect_order() {
    reset_state
    local out
    out=$(bash -c "$(stubbed_source vpn-connector)
        check_dependencies() { echo deps; }
        acquire_lock() { echo lock; }
        clear_stale_vpn_state() { echo stale; }
        begin_connect" 2> /dev/null | tr '\n' ' ')
    [[ $out == "deps lock stale " ]]
    report $? "begin_connect checks deps, takes the lock, then clears stale state" "got: $out"

    out=$(bash -c "$(stubbed_source vpn-connector)
        check_dependencies() { return 0; }
        acquire_lock() { return 1; }
        clear_stale_vpn_state() { echo stale; }
        begin_connect && echo started" 2> /dev/null)
    [[ -z $out ]]
    report $? "begin_connect stops without the lock (no cleanup under another connect)" "got: $out"
}

# All connect commands go through begin_connect
test_all_connect_commands_use_begin_connect() {
    local main bare
    main=$(sed -n '/^if \[\[ \${BASH_SOURCE\[0\]} == "\${0}" \]\]; then/,$p' "$SRC_DIR/vpn-connector")
    bare=$(grep -c "acquire_lock" <<< "$main")
    [[ $bare -eq 0 ]] && [[ $(grep -c "begin_connect" <<< "$main") -ge 6 ]]
    report $? "every connect command starts with begin_connect" "direct acquire_lock calls: $bare"
}

# Ctrl+C / SIGTERM while connecting
# Args: $1 = signal, $2 = state to set before the signal, $3 = expect disconnect (yes/no), $4 = name
run_connect_signal_case() {
    local sig="$1" state="$2" expect="$3" name="$4" driver="$WORK_DIR/connect_driver.sh"
    reset_state
    {
        stubbed_source vpn-connector
        echo "$state"
        echo 'touch "$WORK_DIR/waiting"'
        echo 'sleep 5'
    } > "$driver"
    rm -f "$WORK_DIR/waiting"

    set -m
    WORK_DIR="$WORK_DIR" bash "$driver" > /dev/null 2>&1 &
    local pid=$!
    set +m
    for _ in $(seq 1 40); do
        [[ -f $WORK_DIR/waiting ]] && break
        sleep 0.05
    done
    kill -"$sig" -- "-$pid" 2> /dev/null
    local rc=0
    wait "$pid" 2> /dev/null || rc=$?

    local got=no
    grep -qx "manager:stop" "$CALLS" && got=yes
    [[ $got == "$expect" ]]
    report $? "$name" "disconnect called: $got (expected $expect), exit $rc"
}

test_connect_signals() {
    run_connect_signal_case INT 'VPN_DAEMON_STARTED=1' yes \
        "Ctrl+C while connecting undoes the unfinished connection"
    run_connect_signal_case TERM 'VPN_DAEMON_STARTED=1' yes \
        "SIGTERM while connecting undoes the unfinished connection"
    run_connect_signal_case INT '' no \
        "Ctrl+C before any daemon started leaves an existing VPN alone"
    run_connect_signal_case INT 'VPN_DAEMON_STARTED=1; CONNECTION_ESTABLISHED=1' no \
        "Ctrl+C after the tunnel is up keeps the connection"
}

# The flags the signal handler relies on are set by the real code paths
test_connect_flags_set() {
    local out
    out=$(bash -c "$(stubbed_source vpn-connector)
        save_reconnect_state() { :; }
        handle_connection_success prof 1 1 '' > /dev/null 2>&1
        echo \"established=\${CONNECTION_ESTABLISHED:-}\"" 2> /dev/null)
    [[ $out == "established=1" ]]
    report $? "a successful connect marks the connection established" "got: $out"

    printf 'client\nremote 203.0.113.7 1194\n' > "$HOME/.config/vpn/locations/se-1.ovpn"
    printf 'user\npass\n' > "$HOME/.config/vpn/vpn-credentials.txt"
    out=$(bash -c "$(stubbed_source vpn-connector)
        sudo() { :; }
        prepare_session_dir() { mkdir -p \"$VPN_SESSION_DIR\"; }
        write_session_file() { cat > /dev/null; }
        start_openvpn_daemon \"$HOME/.config/vpn/locations/se-1.ovpn\" > /dev/null 2>&1
        echo \"started=\${VPN_DAEMON_STARTED:-}\"" 2> /dev/null)
    [[ $out == "started=1" ]]
    report $? "starting OpenVPN marks the daemon as started by this run" "got: $out"
}

# ---------------------------------------------------------------------------
# Real iptables in a private network namespace (no effect on the host)
# ---------------------------------------------------------------------------
netns_cmd=""
if command -v iptables > /dev/null && command -v ip6tables > /dev/null; then
    if unshare -n true 2> /dev/null; then
        netns_cmd="unshare -n"
    elif unshare -rn iptables -S > /dev/null 2>&1; then
        netns_cmd="unshare -rn"
    fi
fi

test_kill_switch_netns_leftovers() {
    if [[ -z $netns_cmd ]]; then
        test_pass "kill switch leftovers in netns (skipped: no network namespace/iptables)"
        return
    fi
    mkdir -p "$VPN_SESSION_DIR"
    echo "UDP link remote: [AF_INET]203.0.113.7:1194" > "$VPN_SESSION_DIR/openvpn.log"
    local out
    # shellcheck disable=SC2016  # expanded inside the namespace shell
    out=$($netns_cmd bash -c '
        ip link set lo up
        ip tuntap add dev tun0 mode tun 2>/dev/null && ip link set tun0 up
        bash "$1/vpn-kill-switch" enable > /dev/null 2>&1 || echo "ENABLE_FAILED"
        # duplicate jumps, as left by an interrupted earlier run
        iptables -A OUTPUT -j VPN_KILL_SWITCH
        ip6tables -A OUTPUT -j VPN_KILL_SWITCH_V6
        bash "$1/vpn-kill-switch" disable > /dev/null 2>&1
        echo "left=$(iptables -S | grep -c VPN_KILL)$(ip6tables -S | grep -c VPN_KILL)"

        # only the IPv6 half survived (e.g. the IPv4 jump was removed by hand)
        for t in iptables ip6tables; do
            $t -F OUTPUT
            $t -S | awk "\$1 == \"-N\" {print \$2}" | while read -r c; do $t -F "$c"; $t -X "$c"; done
        done
        ip6tables -N VPN_KILL_SWITCH_V6
        ip6tables -A OUTPUT -j VPN_KILL_SWITCH_V6
        bash "$1/vpn-kill-switch" is-enabled && echo "v6only=enabled" || echo "v6only=disabled"
        bash "$1/vpn-kill-switch" disable > /dev/null 2>&1
        echo "v6left=$(ip6tables -S | grep -c VPN_KILL)"
    ' _ "$SRC_DIR" 2>&1)
    if grep -q "FAILED" <<< "$out"; then
        test_fail "kill switch enable in netns" "$out"
        return
    fi
    grep -q "left=00" <<< "$out"
    report $? "disable removes duplicate OUTPUT jumps (IPv4 and IPv6)" "$out"
    grep -q "v6only=enabled" <<< "$out"
    report $? "is-enabled detects a leftover IPv6-only kill switch" "$out"
    grep -q "v6left=0" <<< "$out"
    report $? "disable removes an IPv6-only leftover" "$out"
}

# ---------------------------------------------------------------------------
# Hooks keep the kill switch on purpose and must say so
# ---------------------------------------------------------------------------
test_hooks_keep_kill_switch() {
    local sleep_hook="$PROJECT_ROOT/etc/elogind/system-sleep/50-vpn-sleep"
    local nm_hook="$PROJECT_ROOT/etc/NetworkManager/dispatcher.d/50-vpn-reconnect"
    local bad=""
    grep -E '/vpn disconnect' "$sleep_hook" | grep -qv 'VPN_KEEP_KILL_SWITCH=1' && bad+=" sleep:disconnect"
    grep -E 'vpn-connector custom' "$sleep_hook" | grep -qv 'VPN_KEEP_KILL_SWITCH=1' && bad+=" sleep:custom"
    grep -E 'VPN_CONNECTOR" custom' "$nm_hook" | grep -qv 'VPN_KEEP_KILL_SWITCH=1' && bad+=" nm:custom"
    [[ -z $bad ]]
    report $? "hooks pass VPN_KEEP_KILL_SWITCH=1 when they disconnect/reconnect" "missing in:$bad"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Kill Switch / DNS Cleanup Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_disconnect_with_dead_tunnel
test_disconnect_with_auto_reconnect
test_disconnect_keep_kill_switch
test_disconnect_survives_signal TERM
test_disconnect_survives_signal INT
test_connect_clears_stale_state
test_connect_keeps_live_vpn_state
test_connect_keep_kill_switch
test_begin_connect_order
test_all_connect_commands_use_begin_connect
test_connect_signals
test_connect_flags_set
test_kill_switch_netns_leftovers
test_hooks_keep_kill_switch

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

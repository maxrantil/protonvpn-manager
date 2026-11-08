#!/bin/bash
# ABOUTME: Behavioural tests: while connected, IPv6 is blocked and DNS bypasses Tailscale
# ABOUTME: Covers the ip6tables guard, pausing/restoring Tailscale DNS, opt-outs and release
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
# stubs and replaces sudo, resolvconf, tailscale, pgrep and ip.
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

STUB_DIR="$WORK_DIR/stub"   # replaces VPN_DIR (vpn-kill-switch)
PATH_STUBS="$WORK_DIR/path" # first on PATH (resolvconf, tailscale, sudo, ...)
CALLS="$WORK_DIR/calls.log" # every stub appends what it was asked to do
TS_CORPDNS="$WORK_DIR/ts_corpdns"
TS_DOWN="$WORK_DIR/ts_down" # tailscaled not running while this exists
PAUSED="$XDG_STATE_HOME/vpn/tailscale-dns-paused"
export CALLS TS_CORPDNS TS_DOWN
mkdir -p "$STUB_DIR" "$PATH_STUBS"

cat > "$STUB_DIR/vpn-kill-switch" << 'EOF'
#!/bin/bash
echo "kill-switch:$*" >> "$CALLS"
[[ $1 == is-enabled ]] && exit 1
exit 0
EOF
cat > "$PATH_STUBS/tailscale" << 'EOF'
#!/bin/bash
if [[ $1 == debug && $2 == prefs ]]; then
    [[ -f $TS_DOWN ]] && { echo "failed to connect to local tailscaled" >&2; exit 1; }
    printf '{\n\t"CorpDNS": %s,\n\t"WantRunning": true\n}\n' "$(cat "$TS_CORPDNS")"
    exit 0
fi
echo "tailscale:$*" >> "$CALLS"
if [[ $1 == set ]]; then
    case "$2" in
        --accept-dns=false) echo false > "$TS_CORPDNS" ;;
        --accept-dns=true) echo true > "$TS_CORPDNS" ;;
    esac
fi
EOF
cat > "$PATH_STUBS/resolvconf" << 'EOF'
#!/bin/bash
[[ $1 == -i ]] && exit 0
echo "resolvconf:$*" >> "$CALLS"
EOF
cat > "$PATH_STUBS/pgrep" << 'EOF'
#!/bin/bash
exit 1
EOF
cat > "$PATH_STUBS/ip" << 'EOF'
#!/bin/bash
exit 0
EOF
# Only the stubbed tools may run; anything else is recorded, never run
cat > "$PATH_STUBS/sudo" << 'EOF'
#!/bin/bash
[[ $1 == -n ]] && shift
case "$1" in resolvconf | tailscale) exec "$@" ;; esac
echo "sudo:$*" >> "$CALLS"
EOF
chmod +x "$STUB_DIR"/* "$PATH_STUBS"/*

# Fresh state: Tailscale running with MagicDNS on, nothing paused, no config
reset_state() {
    : > "$CALLS"
    echo true > "$TS_CORPDNS"
    rm -f "$TS_DOWN" "$PAUSED"
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
save_reconnect_state() { :; }
EOF
}

# A connect that just succeeded (the real success path, stubbed system)
run_connection_success() {
    bash -c "$(stubbed_source vpn-connector)
        handle_connection_success prof 1 1 ''" > /dev/null 2>&1
}

run_release() {
    bash -c "$(stubbed_source vpn-manager)
        release_vpn_network_state" > /dev/null 2>&1
}

called() { grep -qxF -- "$1" "$CALLS"; }

# ---------------------------------------------------------------------------
# On connect
# ---------------------------------------------------------------------------
test_connect_blocks_ipv6() {
    reset_state
    run_connection_success
    called "kill-switch:ipv6-guard on"
    report $? "a successful connect blocks IPv6 outside the tunnel" "$(cat "$CALLS")"

    reset_state
    echo "BLOCK_IPV6=false" > "$HOME/.config/vpn/config"
    run_connection_success
    ! called "kill-switch:ipv6-guard on"
    report $? "BLOCK_IPV6=false leaves IPv6 alone" "$(cat "$CALLS")"
}

test_connect_pauses_tailscale_dns() {
    reset_state
    run_connection_success
    called "tailscale:set --accept-dns=false"
    report $? "a successful connect pauses Tailscale DNS" "$(cat "$CALLS")"
    [[ -f $PAUSED ]]
    report $? "pausing Tailscale DNS is recorded for the restore" "no $PAUSED"
    called "resolvconf:-u"
    report $? "resolv.conf is regenerated from resolvconf (VPN DNS)" "$(cat "$CALLS")"
}

test_tailscale_dns_left_alone() {
    reset_state
    echo "TAILSCALE_DNS=keep" > "$HOME/.config/vpn/config"
    run_connection_success
    ! grep -q "^tailscale:" "$CALLS" && [[ ! -f $PAUSED ]]
    report $? "TAILSCALE_DNS=keep leaves Tailscale DNS alone" "$(cat "$CALLS")"

    reset_state
    echo false > "$TS_CORPDNS"
    run_connection_success
    ! grep -q "^tailscale:" "$CALLS" && [[ ! -f $PAUSED ]]
    report $? "Tailscale DNS already off: nothing changed or recorded" "$(cat "$CALLS")"

    reset_state
    touch "$TS_DOWN"
    run_connection_success
    ! grep -q "^tailscale:" "$CALLS" && [[ ! -f $PAUSED ]]
    report $? "tailscaled not running: nothing changed" "$(cat "$CALLS")"
}

# ---------------------------------------------------------------------------
# On release (disconnect, stale state on connect, interrupted connect)
# ---------------------------------------------------------------------------
test_release_restores() {
    reset_state
    run_connection_success
    : > "$CALLS"
    run_release
    called "tailscale:set --accept-dns=true"
    report $? "release restores Tailscale DNS that was paused" "$(cat "$CALLS")"
    [[ ! -f $PAUSED ]]
    report $? "release clears the pause record" "still there: $PAUSED"
    called "kill-switch:ipv6-guard off"
    report $? "release removes the IPv6 block" "$(cat "$CALLS")"
}

test_release_respects_user_setting() {
    # The user turned Tailscale DNS off themselves: never turn it back on
    reset_state
    echo false > "$TS_CORPDNS"
    run_release
    ! grep -q "^tailscale:" "$CALLS"
    report $? "release never enables Tailscale DNS it did not pause" "$(cat "$CALLS")"
}

test_release_with_keep_kill_switch() {
    reset_state
    run_connection_success
    : > "$CALLS"
    bash -c "VPN_KEEP_KILL_SWITCH=1; $(stubbed_source vpn-manager)
        release_vpn_network_state" > /dev/null 2>&1
    called "tailscale:set --accept-dns=true" && called "kill-switch:ipv6-guard off"
    report $? "VPN_KEEP_KILL_SWITCH=1 still restores DNS and removes the IPv6 block" "$(cat "$CALLS")"
}

# ---------------------------------------------------------------------------
# Real ip6tables in a private network namespace (no effect on the host)
# ---------------------------------------------------------------------------
netns_cmd=""
if command -v ip6tables > /dev/null; then
    if unshare -n true 2> /dev/null; then
        netns_cmd="unshare -n"
    elif unshare -rn ip6tables -S > /dev/null 2>&1; then
        netns_cmd="unshare -rn"
    fi
fi

test_ipv6_guard_netns() {
    if [[ -z $netns_cmd ]]; then
        test_pass "IPv6 guard in netns (skipped: no network namespace/ip6tables)"
        return
    fi
    local out
    # shellcheck disable=SC2016  # expanded inside the namespace shell
    out=$($netns_cmd bash -c '
        bash "$1/vpn-kill-switch" ipv6-guard on > /dev/null 2>&1 || echo "ON_FAILED"
        bash "$1/vpn-kill-switch" ipv6-guard on > /dev/null 2>&1 || echo "ON_FAILED"
        echo "jumps=$(ip6tables -S OUTPUT | grep -c VPN_IPV6_GUARD)"
        echo "v4=$(iptables -S | grep -c VPN_IPV6_GUARD)"
        ip6tables -S VPN_IPV6_GUARD
        bash "$1/vpn-kill-switch" ipv6-guard status > /dev/null 2>&1 && echo "status=on" || echo "status=off"
        ip6tables -A OUTPUT -j VPN_IPV6_GUARD
        bash "$1/vpn-kill-switch" ipv6-guard off > /dev/null 2>&1
        echo "left=$(ip6tables -S | grep -c VPN_IPV6_GUARD)"
        bash "$1/vpn-kill-switch" ipv6-guard status > /dev/null 2>&1 && echo "after=on" || echo "after=off"
    ' _ "$SRC_DIR" 2>&1)
    if grep -q "FAILED" <<< "$out"; then
        test_fail "ipv6-guard on in netns" "$out"
        return
    fi
    grep -q "jumps=1" <<< "$out"
    report $? "ipv6-guard on twice keeps a single OUTPUT jump" "$out"
    grep -q "v4=0" <<< "$out"
    report $? "IPv4 is not touched" "$out"
    local rule bad=""
    for rule in "-o lo -j ACCEPT" "-d fe80::/10 -j ACCEPT" "-d ff00::/8 -j ACCEPT" \
        "-o tun+ -j ACCEPT" "-o tailscale0 -j ACCEPT" "-o virbr+ -j ACCEPT"; do
        grep -q -- "-A VPN_IPV6_GUARD $rule" <<< "$out" || bad+=" [$rule]"
    done
    [[ -z $bad ]]
    report $? "allows loopback, link-local, multicast, tun, tailscale0, virbr" "missing:$bad"
    # REJECT needs a kernel module that cannot load in a user namespace (or
    # after a kernel upgrade without reboot); DROP is the fallback
    local last
    last=$(grep -- "-A VPN_IPV6_GUARD" <<< "$out" | tail -1)
    [[ $last == *"-j REJECT"* || $last == *"-j DROP" ]]
    report $? "everything else is rejected, or dropped without REJECT support" "$out"
    grep -q "status=on" <<< "$out" && grep -q "after=off" <<< "$out"
    report $? "ipv6-guard status reflects on/off" "$out"
    grep -q "left=0" <<< "$out"
    report $? "ipv6-guard off removes the chain and every jump" "$out"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Leak Protection Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_connect_blocks_ipv6
test_connect_pauses_tailscale_dns
test_tailscale_dns_left_alone
test_release_restores
test_release_respects_user_setting
test_release_with_keep_kill_switch
test_ipv6_guard_netns

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

#!/bin/bash
# ABOUTME: Behavioural tests for the kill switch's guard chains (IPv6 guard, DNS guard) on a fake firewall
# ABOUTME: A stateful iptables fake and a fake sudo stand in; the real firewall is never reachable
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

# Sandbox: a PATH made of the fakes plus every system tool except those that
# touch the firewall, DNS, the network or privileges. sudo resets PATH, so the
# fake sudo runs only the fake firewall tools and records anything else.
FW="$WORK_DIR/fw"         # fake firewall state (FAKE_FW_DIR)
FAKES="$WORK_DIR/fakes"   # first on PATH
SYSBIN="$WORK_DIR/sysbin" # system tools minus the denied ones
CALLS="$WORK_DIR/calls.log"
LINKS="$WORK_DIR/links" # interfaces the fake ip reports as present
mkdir -p "$FW" "$FAKES" "$SYSBIN" "$LINKS" "$WORK_DIR/home" "$WORK_DIR/session"
ln -s /usr/bin/* "$SYSBIN"/ 2> /dev/null
DENIED=(iptables ip6tables iptables-restore ip6tables-restore iptables-save ip6tables-save
    iptables-nft ip6tables-nft iptables-legacy ip6tables-legacy xtables-nft-multi
    xtables-legacy-multi nft ip sudo doas su pkexec resolvconf nmcli tailscale openvpn
    wg wg-quick systemctl rc-service)
for tool in "${DENIED[@]}"; do
    rm -f "$SYSBIN/$tool"
done
for tool in iptables ip6tables iptables-restore ip6tables-restore; do
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/$tool"
done
cat > "$FAKES/sudo" << 'EOF'
#!/bin/bash
[[ $1 == -n ]] && shift
case "$1" in
    true | iptables | ip6tables | iptables-restore | ip6tables-restore) exec "$@" ;;
esac
echo "sudo:$*" >> "$CALLS"
exit 1
EOF
cat > "$FAKES/ip" << 'EOF'
#!/bin/bash
if [[ $1 == link && $2 == show ]]; then
    [[ -e $LINKS/$3 ]]
    exit
fi
exit 0
EOF
chmod +x "$FAKES/sudo" "$FAKES/ip"
SANDBOX_PATH="$FAKES:$SYSBIN"

reset_fw() {
    rm -rf "$FW" "$LINKS"
    mkdir -p "$FW" "$LINKS"
    : > "$CALLS"
    touch "$LINKS/tun0"
}

# Run vpn-kill-switch in the sandbox, unprivileged (through the fake sudo)
# Args: kill switch arguments; extra environment via KS_ENV (array)
KS_ENV=()
ks() {
    env -i HOME="$WORK_DIR/home" PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" CALLS="$CALLS" \
        LINKS="$LINKS" XDG_STATE_HOME="$WORK_DIR/home/.local/state" \
        XDG_RUNTIME_DIR="$WORK_DIR/run" VPN_SESSION_DIR="$WORK_DIR/session" \
        VPN_CONFIG_DIR="$WORK_DIR/home/.config/vpn" "${KS_ENV[@]}" \
        "$BASH" "$SRC_DIR/vpn-kill-switch" "$@"
}

# The fake table, as iptables -S prints it. Args: $1 = v4|v6, $2 = chain (optional)
fw_rules() {
    local tool=iptables
    [[ $1 == v6 ]] && tool=ip6tables
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/$tool" -S ${2:+"$2"} 2> /dev/null
}

# Jumps from OUTPUT to $2 in family $1
jumps() { fw_rules "$1" OUTPUT | grep -cxF -- "-A OUTPUT -j $2"; }

# ---------------------------------------------------------------------------
# The sandbox itself
# ---------------------------------------------------------------------------
test_sandbox_has_no_real_firewall() {
    local tool found bad=""
    for tool in iptables ip6tables iptables-restore ip6tables-restore sudo; do
        found=$(env PATH="$SANDBOX_PATH" bash -c "command -v $tool")
        [[ $found == "$FAKES/$tool" ]] || bad+=" $tool=$found"
    done
    for tool in resolvconf nmcli nft; do
        found=$(env PATH="$SANDBOX_PATH" bash -c "command -v $tool")
        [[ -z $found ]] || bad+=" $tool=$found"
    done
    [[ -z $bad ]]
    report $? "only the fakes are reachable for the firewall and sudo" "$bad"
    ! grep -nE '(/usr)?/s?bin/(ip6?tables|nft)' "$SRC_DIR/vpn-kill-switch"
    report $? "vpn-kill-switch never calls a firewall tool by absolute path"
}

# ---------------------------------------------------------------------------
# IPv6 guard (unchanged behaviour after the shared-helper refactor)
# ---------------------------------------------------------------------------
test_ipv6_guard_on() {
    reset_fw
    ks ipv6-guard on > /dev/null 2>&1
    report $? "ipv6-guard on succeeds"
    ks ipv6-guard on > /dev/null 2>&1
    [[ $(jumps v6 VPN_IPV6_GUARD) -eq 1 ]]
    report $? "ipv6-guard on twice keeps a single OUTPUT jump" "$(fw_rules v6 OUTPUT)"
    ! fw_rules v4 | grep -q VPN_IPV6_GUARD
    report $? "the IPv6 guard leaves IPv4 alone" "$(fw_rules v4)"
    local expected
    expected="-N VPN_IPV6_GUARD
-A VPN_IPV6_GUARD -o lo -j ACCEPT
-A VPN_IPV6_GUARD -d fe80::/10 -j ACCEPT
-A VPN_IPV6_GUARD -d ff00::/8 -j ACCEPT
-A VPN_IPV6_GUARD -o tun+ -j ACCEPT
-A VPN_IPV6_GUARD -o tailscale0 -j ACCEPT
-A VPN_IPV6_GUARD -o virbr+ -j ACCEPT
-A VPN_IPV6_GUARD -j REJECT --reject-with icmp6-adm-prohibited"
    [[ $(fw_rules v6 VPN_IPV6_GUARD) == "$expected" ]]
    report $? "the IPv6 guard's rules are unchanged" "$(fw_rules v6 VPN_IPV6_GUARD)"
    fw_rules v6 OUTPUT | sed -n 2p | grep -qxF -- "-A OUTPUT -j VPN_IPV6_GUARD"
    report $? "the IPv6 guard's jump is inserted first in OUTPUT" "$(fw_rules v6 OUTPUT)"
}

test_ipv6_guard_drop_fallback() {
    reset_fw
    touch "$FW/no_reject"
    ks ipv6-guard on > /dev/null 2>&1
    report $? "ipv6-guard on succeeds without REJECT support"
    [[ $(fw_rules v6 VPN_IPV6_GUARD | tail -1) == "-A VPN_IPV6_GUARD -j DROP" ]]
    report $? "without REJECT the IPv6 guard drops" "$(fw_rules v6 VPN_IPV6_GUARD)"
}

test_ipv6_guard_restore_fails() {
    reset_fw
    touch "$FW/no_restore_v6"
    ! ks ipv6-guard on > /dev/null 2>&1
    report $? "ipv6-guard on fails when ip6tables-restore fails"
    ! fw_rules v6 | grep -q VPN_IPV6_GUARD
    report $? "a failed ipv6-guard on leaves no chain or jump" "$(fw_rules v6)"
}

test_ipv6_guard_status_and_off() {
    reset_fw
    ! ks ipv6-guard status > /dev/null 2>&1
    report $? "ipv6-guard status is off before on"
    ks ipv6-guard on > /dev/null 2>&1
    ks ipv6-guard status > /dev/null 2>&1
    report $? "ipv6-guard status is on after on"
    # An interrupted run can leave duplicate jumps
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/ip6tables" -A OUTPUT -j VPN_IPV6_GUARD
    ks ipv6-guard off > /dev/null 2>&1
    report $? "ipv6-guard off succeeds"
    ! fw_rules v6 | grep -q VPN_IPV6_GUARD
    report $? "ipv6-guard off removes the chain and every jump" "$(fw_rules v6)"
    ! ks ipv6-guard status > /dev/null 2>&1
    report $? "ipv6-guard status is off after off"
    ks ipv6-guard off > /dev/null 2>&1
    report $? "ipv6-guard off is a no-op when the guard is absent"
}

test_ipv6_guard_without_ip6tables() {
    reset_fw
    local out rc=0
    rm -f "$FAKES/ip6tables" "$FAKES/ip6tables-restore"
    out=$(ks ipv6-guard on 2>&1) || rc=$?
    [[ $rc -ne 0 && $out == *"ip6tables not found"* ]]
    report $? "ipv6-guard on warns and fails without ip6tables" "rc=$rc $out"
    ks ipv6-guard off > /dev/null 2>&1
    report $? "ipv6-guard off is a no-op without ip6tables"
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/ip6tables"
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/ip6tables-restore"
}

test_emergency_removes_guards() {
    reset_fw
    ks ipv6-guard on > /dev/null 2>&1
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    ks emergency > /dev/null 2>&1
    ! fw_rules v6 | grep -q VPN_IPV6_GUARD
    report $? "emergency removes the IPv6 guard" "$(fw_rules v6)"
}

# ---------------------------------------------------------------------------
# Kill switch on the fake (the refactor must not change it)
# ---------------------------------------------------------------------------
test_kill_switch_enable_disable() {
    reset_fw
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    report $? "kill switch enable succeeds on the fake firewall"
    [[ $(jumps v4 VPN_KILL_SWITCH) -eq 1 && $(jumps v6 VPN_KILL_SWITCH_V6) -eq 1 ]]
    report $? "kill switch jumps exist in both families" "$(fw_rules v4 OUTPUT; fw_rules v6 OUTPUT)"
    ks disable > /dev/null 2>&1
    ! fw_rules v4 | grep -q VPN_KILL && ! fw_rules v6 | grep -q VPN_KILL
    report $? "kill switch disable removes both chains" "$(fw_rules v4; fw_rules v6)"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Guard Chain Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_sandbox_has_no_real_firewall
test_ipv6_guard_on
test_ipv6_guard_drop_fallback
test_ipv6_guard_restore_fails
test_ipv6_guard_status_and_off
test_ipv6_guard_without_ip6tables
test_emergency_removes_guards
test_kill_switch_enable_disable

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf '  failed: %s\n' "${FAILED_TESTS[@]}"
    exit 1
fi
exit 0

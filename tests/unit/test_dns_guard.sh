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

# ---------------------------------------------------------------------------
# DNS guard (FR6): no port 53 outside lo, the tunnel and Tailscale
# ---------------------------------------------------------------------------
dns_rules_expected() { # $1 = icmp-port-unreachable | icmp6-port-unreachable | drop
    local udp_end="REJECT --reject-with $1" tcp_end="REJECT --reject-with tcp-reset"
    if [[ $1 == drop ]]; then
        udp_end=DROP
        tcp_end=DROP
    fi
    printf '%s\n' "-N VPN_DNS_GUARD" \
        "-A VPN_DNS_GUARD -o lo -j RETURN" \
        "-A VPN_DNS_GUARD -o tun+ -j RETURN" \
        "-A VPN_DNS_GUARD -o tailscale0 -j RETURN" \
        "-A VPN_DNS_GUARD -p udp -m udp --dport 53 -j $udp_end" \
        "-A VPN_DNS_GUARD -p tcp -m tcp --dport 53 -j $tcp_end"
}

test_dns_guard_rules() {
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    report $? "dns-guard on succeeds"
    [[ $(fw_rules v4 VPN_DNS_GUARD) == "$(dns_rules_expected icmp-port-unreachable)" ]]
    report $? "IPv4: RETURN for lo, tun+, tailscale0; udp and tcp 53 rejected" "$(fw_rules v4 VPN_DNS_GUARD)"
    [[ $(fw_rules v6 VPN_DNS_GUARD) == "$(dns_rules_expected icmp6-port-unreachable)" ]]
    report $? "IPv6: the same rules, with icmp6-port-unreachable" "$(fw_rules v6 VPN_DNS_GUARD)"
    ! fw_rules v4 | grep -q -- multiport && ! fw_rules v6 | grep -q -- multiport
    report $? "the DNS guard uses no multiport match (#291)"
    ! fw_rules v4 VPN_DNS_GUARD | grep -q -- "wg" && ! fw_rules v6 VPN_DNS_GUARD | grep -q -- "wg"
    report $? "WireGuard interfaces are not exempt (left to #223)"
    ks dns-guard on > /dev/null 2>&1
    [[ $(jumps v4 VPN_DNS_GUARD) -eq 1 && $(jumps v6 VPN_DNS_GUARD) -eq 1 ]]
    report $? "dns-guard on twice keeps a single jump per family" "$(fw_rules v4 OUTPUT; fw_rules v6 OUTPUT)"
}

test_dns_guard_drop_fallback() {
    reset_fw
    touch "$FW/no_reject"
    local out
    out=$(ks dns-guard on 2>&1)
    report $? "dns-guard on succeeds without REJECT support" "$out"
    [[ $(fw_rules v4 VPN_DNS_GUARD) == "$(dns_rules_expected drop)" &&
        $(fw_rules v6 VPN_DNS_GUARD) == "$(dns_rules_expected drop)" ]]
    report $? "without REJECT the DNS guard drops port 53" "$(fw_rules v4 VPN_DNS_GUARD)"
    [[ $out == *"DROP"* ]]
    report $? "the DROP fallback is noted" "$out"
}

test_dns_guard_restore_fails() {
    reset_fw
    touch "$FW/no_restore_v6"
    ! ks dns-guard on > /dev/null 2>&1
    report $? "dns-guard on fails when one family cannot be loaded"
    ! fw_rules v6 | grep -q VPN_DNS_GUARD
    report $? "the failed family has no half-applied chain or jump" "$(fw_rules v6)"
    [[ $(fw_rules v4 VPN_DNS_GUARD) == "$(dns_rules_expected icmp-port-unreachable)" ]]
    report $? "the other family is still guarded" "$(fw_rules v4)"
}

# The guard must reject before the kill switch's ESTABLISHED and gateway:53
# ACCEPTs and the IPv6 guard's link-local ACCEPT, whatever loads first
test_dns_guard_first_in_every_order() {
    local -a steps=("enable --force 192.0.2.1" "ipv6-guard on" "dns-guard on")
    local -a orders=("0 1 2" "0 2 1" "1 0 2" "1 2 0" "2 0 1" "2 1 0")
    local order i bad=""
    for order in "${orders[@]}"; do
        reset_fw
        for i in $order; do
            # shellcheck disable=SC2086  # each step is a command and its arguments
            ks ${steps[$i]} > /dev/null 2>&1
        done
        [[ $(fw_rules v4 OUTPUT | sed -n 2p) == "-A OUTPUT -j VPN_DNS_GUARD" &&
            $(fw_rules v6 OUTPUT | sed -n 2p) == "-A OUTPUT -j VPN_DNS_GUARD" ]] || bad+=" [$order]"
        [[ $(jumps v4 VPN_KILL_SWITCH) -eq 1 && $(jumps v6 VPN_IPV6_GUARD) -eq 1 ]] || bad+=" [$order: other jump lost]"
    done
    [[ -z $bad ]]
    report $? "the DNS guard is first in OUTPUT for every order of kill switch, IPv6 and DNS guard" "bad:$bad"
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    ks refresh > /dev/null 2>&1
    [[ $(fw_rules v4 OUTPUT | sed -n 2p) == "-A OUTPUT -j VPN_DNS_GUARD" ]]
    report $? "the DNS guard stays first after a kill switch refresh" "$(fw_rules v4 OUTPUT)"
}

test_dns_guard_status() {
    reset_fw
    local out rc
    out=$(ks dns-guard status 2> /dev/null) && rc=0 || rc=$?
    [[ $rc -eq 1 && $out == off ]]
    report $? "dns-guard status: off" "rc=$rc out=$out"
    ks dns-guard on > /dev/null 2>&1
    out=$(ks dns-guard status 2> /dev/null) && rc=0 || rc=$?
    [[ $rc -eq 0 && $out == on ]]
    report $? "dns-guard status: on" "rc=$rc out=$out"
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/iptables" -I OUTPUT 1 -j ACCEPT
    out=$(ks dns-guard status 2> /dev/null) && rc=0 || rc=$?
    [[ $rc -ne 0 && $out == "on (not first in OUTPUT)" ]]
    report $? "dns-guard status: on but not first in OUTPUT is not healthy" "rc=$rc out=$out"
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/ip6tables" -D OUTPUT -j VPN_DNS_GUARD
    out=$(ks dns-guard status 2> /dev/null) && rc=0 || rc=$?
    [[ $rc -ne 0 && $out == "on (IPv4 only)" ]]
    report $? "dns-guard status: one family missing is not healthy" "rc=$rc out=$out"
}

test_dns_guard_off() {
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/iptables" -A OUTPUT -j VPN_DNS_GUARD
    ks dns-guard off > /dev/null 2>&1
    report $? "dns-guard off succeeds"
    ! fw_rules v4 | grep -q VPN_DNS_GUARD && ! fw_rules v6 | grep -q VPN_DNS_GUARD
    report $? "dns-guard off removes every jump and both chains" "$(fw_rules v4; fw_rules v6)"
    [[ $(jumps v4 VPN_KILL_SWITCH) -eq 1 ]]
    report $? "dns-guard off leaves the kill switch alone" "$(fw_rules v4 OUTPUT)"
    : > "$FW/calls"
    ks dns-guard off > /dev/null 2>&1
    report $? "dns-guard off is a no-op when the guard is absent"
    ! grep -qE -- ' -(F|X|D) ' "$FW/calls"
    report $? "an absent guard is not flushed or deleted" "$(cat "$FW/calls")"
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    ks disable > /dev/null 2>&1
    [[ $(jumps v4 VPN_DNS_GUARD) -eq 1 ]]
    report $? "kill switch disable leaves the DNS guard (it belongs to the connection)" "$(fw_rules v4 OUTPUT)"
    ks emergency > /dev/null 2>&1
    ! fw_rules v4 | grep -q VPN_DNS_GUARD && ! fw_rules v6 | grep -q VPN_DNS_GUARD
    report $? "emergency removes the DNS guard" "$(fw_rules v4; fw_rules v6)"
}

test_dns_guard_without_ip6tables() {
    reset_fw
    local out rc=0
    rm -f "$FAKES/ip6tables" "$FAKES/ip6tables-restore"
    out=$(ks dns-guard on 2>&1) || rc=$?
    [[ $rc -eq 0 && $out == *"ip6tables not found"* ]]
    report $? "dns-guard on warns but succeeds without ip6tables (no IPv6 firewall to guard)" "rc=$rc $out"
    [[ $(fw_rules v4 VPN_DNS_GUARD) == "$(dns_rules_expected icmp-port-unreachable)" ]]
    report $? "without ip6tables the IPv4 DNS guard still loads" "$(fw_rules v4)"
    out=$(ks dns-guard status 2> /dev/null)
    report $? "dns-guard status is on with IPv4 only when ip6tables is missing" "$out"
    ks dns-guard off > /dev/null 2>&1 && ! fw_rules v4 | grep -q VPN_DNS_GUARD
    report $? "dns-guard off works without ip6tables" "$(fw_rules v4)"
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/ip6tables"
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/ip6tables-restore"
}

fake() { # $1 = tool, rest = arguments: call the fake directly
    local tool=$1
    shift
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/$tool" "$@"
}

test_dns_guard_family_specific_rejects() {
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    ! fw_rules v4 VPN_DNS_GUARD | grep -q icmp6 && ! fw_rules v6 VPN_DNS_GUARD | grep -q -- '-with icmp-'
    report $? "each family rejects with its own ICMP type" "$(fw_rules v4 VPN_DNS_GUARD; fw_rules v6 VPN_DNS_GUARD)"
    ! fw_rules v4 VPN_DNS_GUARD | grep -- tcp-reset | grep -vq -- '-p tcp '
    report $? "tcp-reset only on the tcp rule"
}

test_dns_guard_existing_chain_without_jump() {
    reset_fw
    fake iptables -N VPN_DNS_GUARD
    fake iptables -A VPN_DNS_GUARD -j RETURN
    ks dns-guard on > /dev/null 2>&1
    [[ $(fw_rules v4 VPN_DNS_GUARD) == "$(dns_rules_expected icmp-port-unreachable)" &&
        $(jumps v4 VPN_DNS_GUARD) -eq 1 ]]
    report $? "a leftover chain without its jump is refilled and jumped to" "$(fw_rules v4)"
}

test_pin_collapses_duplicate_jumps() {
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    fake iptables -A OUTPUT -j VPN_DNS_GUARD
    fake iptables -D OUTPUT -j VPN_DNS_GUARD
    fake iptables -A OUTPUT -j VPN_DNS_GUARD
    # OUTPUT is now: kill switch, guard, guard
    ks dns-guard on > /dev/null 2>&1
    [[ $(fw_rules v4 OUTPUT | sed -n 2p) == "-A OUTPUT -j VPN_DNS_GUARD" && $(jumps v4 VPN_DNS_GUARD) -eq 1 ]]
    report $? "re-pinning leaves a single DNS guard jump, first" "$(fw_rules v4 OUTPUT)"
}

test_pin_failure() {
    local out rc
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    echo "-D OUTPUT -j VPN_DNS_GUARD" > "$FW/restore_fails_on"
    out=$(ks enable --force 192.0.2.1 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 && $out == *"Kill switch enabled"* ]]
    report $? "a failed re-pin does not abort enabling the kill switch" "rc=$rc $out"
    grep -q '^status=enabled' "$WORK_DIR/home/.local/state/vpn/kill_switch.state" 2> /dev/null
    report $? "the kill switch state is saved despite a failed re-pin"
    [[ $out == *"DNS guard"* ]]
    report $? "a failed re-pin is warned about" "$out"
    out=$(ks dns-guard on 2>&1) && rc=0 || rc=$?
    [[ $rc -ne 0 && $out != *"DNS blocked outside the tunnel"* ]]
    report $? "dns-guard on fails when the guard cannot be put first" "rc=$rc $out"
}

test_kill_switch_partial_load_keeps_guard_first() {
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    touch "$FW/no_restore_v6"
    ks enable --force 192.0.2.1 > /dev/null 2>&1
    [[ $(fw_rules v4 OUTPUT | sed -n 2p) == "-A OUTPUT -j VPN_DNS_GUARD" ]]
    report $? "the DNS guard stays first in IPv4 when the IPv6 kill switch fails to load" "$(fw_rules v4 OUTPUT)"
}

test_dns_guard_off_failures() {
    local rc
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    touch "$FW/fail_X_v4"
    ks dns-guard off > /dev/null 2>&1 && rc=0 || rc=$?
    [[ $rc -ne 0 ]]
    report $? "dns-guard off reports a chain it could not delete"
    ! fw_rules v6 | grep -q VPN_DNS_GUARD
    report $? "a failure in IPv4 still removes the IPv6 guard" "$(fw_rules v6)"
    [[ $(jumps v4 VPN_DNS_GUARD) -eq 0 ]]
    report $? "the IPv4 jump is gone even when its chain could not be deleted" "$(fw_rules v4 OUTPUT)"
}

test_dns_guard_status_unreadable() {
    local out rc
    reset_fw
    ks dns-guard on > /dev/null 2>&1
    touch "$FW/fail_S_v4"
    out=$(ks dns-guard status 2> /dev/null) && rc=0 || rc=$?
    [[ $rc -eq 2 && $out == unknown ]]
    report $? "dns-guard status is unknown, not off, when the firewall cannot be read" "rc=$rc out=$out"
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
test_dns_guard_rules
test_dns_guard_drop_fallback
test_dns_guard_restore_fails
test_dns_guard_first_in_every_order
test_dns_guard_status
test_dns_guard_off
test_dns_guard_without_ip6tables
test_dns_guard_family_specific_rejects
test_dns_guard_existing_chain_without_jump
test_pin_collapses_duplicate_jumps
test_pin_failure
test_kill_switch_partial_load_keeps_guard_first
test_dns_guard_off_failures
test_dns_guard_status_unreadable

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf '  failed: %s\n' "${FAILED_TESTS[@]}"
    exit 1
fi
exit 0

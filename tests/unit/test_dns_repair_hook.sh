#!/bin/bash
# ABOUTME: Tests for the 40-vpn-dns-repair dispatcher hook: repair on dns-change, lock, rate limit, leftover guard
# ABOUTME: The hook's functions run against fake resolvconf, logger, pgrep and a stateful fake firewall

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PROJECT_ROOT/etc/NetworkManager/dispatcher.d/40-vpn-dns-repair"

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

# check <name> <detail> <command...>: passes when the command succeeds
check() {
    local name=$1 detail=$2
    shift 2
    if "$@"; then
        test_pass "$name"
    else
        test_fail "$name" "$detail"
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Sandbox: the fakes plus every system tool except those that touch DNS,
# the firewall, the network or privileges
FAKES="$WORK/fakes"
SYSBIN="$WORK/sysbin"
STATE="$WORK/state" # fake resolvconf/pgrep/logger state
FW="$WORK/fw"       # fake firewall (FAKE_FW_DIR)
mkdir -p "$FAKES" "$SYSBIN"
ln -s /usr/bin/* "$SYSBIN"/ 2> /dev/null
for tool in iptables ip6tables iptables-restore ip6tables-restore iptables-save ip6tables-save \
    iptables-nft ip6tables-nft iptables-legacy ip6tables-legacy xtables-nft-multi \
    xtables-legacy-multi nft ip sudo doas su pkexec resolvconf nmcli tailscale openvpn \
    systemctl rc-service logger pgrep runuser setpriv; do
    rm -f "$SYSBIN/$tool"
done
for tool in iptables ip6tables; do
    ln -s "$PROJECT_ROOT/tests/fakes/fake-firewall" "$FAKES/$tool"
done

# resolvconf: -l <entry> prints $STATE/entry when present; -u is recorded
# (with "fd9-open" when the hook's lock fd leaked into it) and fails when
# $STATE/u_fails exists
cat > "$FAKES/resolvconf" << 'EOF'
#!/bin/bash
case "$1" in
    -l) [[ $2 == tun0.protonvpn && -f $STATE/entry ]] && cat "$STATE/entry"; exit 0 ;;
    -u)
        line="resolvconf -u"
        [[ -e /proc/self/fd/9 ]] && line+=" fd9-open"
        echo "$line" >> "$STATE/calls"
        [[ ! -e $STATE/u_fails ]]
        exit
        ;;
esac
echo "resolvconf $*" >> "$STATE/calls"
exit 1
EOF
# logger: appends the message to $STATE/log; fails when $STATE/logger_fails
cat > "$FAKES/logger" << 'EOF'
#!/bin/bash
[[ -e $STATE/logger_fails ]] && exit 1
[[ $1 == -t ]] && shift 2
[[ $1 == -- ]] && shift
echo "$*" >> "$STATE/log"
EOF
# pgrep -x openvpn: exit code from $STATE/pgrep_rc (default 1: none runs)
cat > "$FAKES/pgrep" << 'EOF'
#!/bin/bash
echo "pgrep $*" >> "$STATE/calls"
rc=$(cat "$STATE/pgrep_rc" 2> /dev/null || echo 1)
[[ $rc -eq 0 ]] && echo 4242
exit "$rc"
EOF
chmod +x "$FAKES/resolvconf" "$FAKES/logger" "$FAKES/pgrep"
SANDBOX_PATH="$FAKES:$SYSBIN"

# Fresh state: VPN healthy, its entry registered, resolv.conf a plain file
reset_state() {
    rm -rf "$STATE" "$FW" "$WORK/run"
    mkdir -p "$STATE" "$FW"
    printf 'nameserver 10.96.0.1\n' > "$STATE/entry"
    printf 'nameserver 10.96.0.1\n' > "$WORK/resolv.conf"
    touch "$STATE/healthy" "$STATE/calls" "$STATE/log"
}

# Run the hook's repair_vpn_dns as the hook does (set -euo pipefail), with
# its top-level constants pointed into the sandbox and vpn_is_healthy
# stubbed by $STATE/healthy. $1 (optional): a command run first in the same
# shell (e.g. holding the lock). Prints "rc=<status>".
run_repair() {
    env -i PATH="$SANDBOX_PATH" STATE="$STATE" FAKE_FW_DIR="$FW" WORK="$WORK" HOOK="$HOOK" \
        RESOLV_OVERRIDE="${RESOLV_OVERRIDE:-}" RUN_DIR_OVERRIDE="${RUN_DIR_OVERRIDE:-}" \
        PRE="${1:-:}" "$BASH" -c '
        set -euo pipefail
        # shellcheck disable=SC1090
        source <(sed -n "/^[a-z_]*() {\$/,/^}\$/p" "$HOOK")
        # The hook'"'"'s own rate-limit policy
        source <(grep -E "^RATE_(MAX|WINDOW)=[0-9]+\$" "$HOOK")
        RESOLV_CONF=${RESOLV_OVERRIDE:-$WORK/resolv.conf}
        RUN_DIR=${RUN_DIR_OVERRIDE:-$WORK/run}
        LOCK_FILE=$RUN_DIR/dns-repair.lock
        TIMES_FILE=$RUN_DIR/dns-repair.times
        vpn_is_healthy() { [[ -e $STATE/healthy ]]; }
        eval "$PRE"
        rc=0
        repair_vpn_dns || rc=$?
        echo "rc=$rc"
    ' 2>&1
}

repairs() { grep -c '^resolvconf -u' "$STATE/calls"; }
fw() { # $1 = iptables | ip6tables, rest = args
    local tool=$1
    shift
    env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/$tool" "$@"
}
# A leftover DNS guard in both families (with a duplicate v4 jump)
plant_guard() {
    local tool
    for tool in iptables ip6tables; do
        fw "$tool" -N VPN_DNS_GUARD
        fw "$tool" -A VPN_DNS_GUARD -p udp -m udp --dport 53 -j DROP
        fw "$tool" -I OUTPUT 1 -j VPN_DNS_GUARD
    done
    fw iptables -A OUTPUT -j VPN_DNS_GUARD
}
guard_left() { fw iptables -S | grep -q VPN_DNS_GUARD || fw ip6tables -S | grep -q VPN_DNS_GUARD; }
guard_gone() { ! guard_left; }

# ---------------------------------------------------------------------------
# The hook file and the actions it ignores
# ---------------------------------------------------------------------------
test_hook_file() {
    check "the hook exists and is executable" "$HOOK" test -x "$HOOK"
    check "the hook starts with two ABOUTME lines" "" \
        test "$(sed -n '2,3p' "$HOOK" | grep -c '^# ABOUTME:')" -eq 2
    check "the hook runs with set -euo pipefail and a fixed PATH" "" \
        grep -q '^set -euo pipefail$' "$HOOK"
    check "the hook sets a fixed PATH" "" \
        grep -q '^PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin$' "$HOOK"
    check "the hook sources vpn-utils only from /usr/local/bin" "" \
        grep -q '^VPN_DIR=/usr/local/bin$' "$HOOK"
}

# Never sources user-writable code or touches a user's home
test_hook_static() {
    local hits
    hits=$(grep -nE 'detect_real_user|REAL_USER|REAL_HOME|\$\{?HOME|as_user|realpath|dirname|vpn-kill-switch|src/' "$HOOK" | grep -v '^[0-9]*:#')
    check "no user context, no development-mode fallback, no kill switch script" "$hits" test -z "$hits"
    # The action is checked before anything is sourced
    local action_line source_line
    action_line=$(grep -n 'dns-change' "$HOOK" | grep -v '^[0-9]*:#' | head -1 | cut -d: -f1)
    source_line=$(grep -n '^source ' "$HOOK" | head -1 | cut -d: -f1)
    check "the action is checked before vpn-utils is sourced" "action=$action_line source=$source_line" \
        test -n "$action_line" -a -n "$source_line" -a "${action_line:-0}" -lt "${source_line:-0}"
    # Fixed constants, assigned after sourcing (vpn-utils must not override them)
    local name value line
    for name in RESOLV_CONF=/etc/resolv.conf RUN_DIR=/run/protonvpn-manager \
        VPN_PID_FILE=/var/run/openvpn.pid VPN_SESSION_PROFILE=/run/protonvpn-manager-session/profile.ovpn \
        VPN_TUNNEL_INTERFACE=tun0 VPN_PROC_DIR=/proc; do
        value=${name#*=}
        line=$(grep -nxF "${name%%=*}=$value" "$HOOK" | head -1 | cut -d: -f1)
        check "the hook sets ${name%%=*}=$value after sourcing vpn-utils" "line=$line source=$source_line" \
            test -n "$line" -a "${line:-0}" -gt "${source_line:-0}"
    done
    check "vpn-utils is sourced only when root-owned and not writable by others" "" \
        grep -q 'root_owned_safe "$VPN_DIR/vpn-utils"' "$HOOK"
}

# root_owned_safe: what the hook trusts enough to source or lock in
test_root_owned_safe() {
    local out
    out=$(env -i PATH="$SANDBOX_PATH" HOOK="$HOOK" WORK="$WORK" "$BASH" -c '
        source <(sed -n "/^root_owned_safe() {\$/,/^}\$/p" "$HOOK")
        mkdir -p "$WORK/mine"
        ln -sfn /usr "$WORK/usr-link"
        for p in /usr /tmp "$WORK/mine" "$WORK/usr-link"; do
            root_owned_safe "$p" && echo "$p=yes" || echo "$p=no"
        done' 2>&1)
    if [[ $EUID -ne 0 ]]; then
        check "root_owned_safe: a root-owned 755 directory is trusted" "$out" grep -qx "/usr=yes" <<< "$out"
        check "root_owned_safe: a user-owned directory is refused" "$out" grep -qx "$WORK/mine=no" <<< "$out"
    else
        echo "  (skipped: running as root, a user-owned path cannot be made here)"
    fi
    check "root_owned_safe: a world-writable directory is refused" "$out" grep -qx "/tmp=no" <<< "$out"
    check "root_owned_safe: a symlink is refused" "$out" grep -qx "$WORK/usr-link=no" <<< "$out"
    rm -rf "$WORK/mine" "$WORK/usr-link"
}

test_other_actions() {
    local action out rc
    for action in up down connectivity-change vpn-up pre-up ""; do
        out=$(env -i PATH="$SANDBOX_PATH" "$BASH" "$HOOK" wlan0 "$action" 2>&1) && rc=0 || rc=$?
        check "action '${action:-<empty>}': exits 0 at once" "rc=$rc out=$out" test "$rc" -eq 0 -a -z "$out"
    done
}

# ---------------------------------------------------------------------------
# Repair
# ---------------------------------------------------------------------------
test_repair() {
    local out
    reset_state
    out=$(run_repair)
    check "healthy VPN with its entry: resolvconf -u once" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 1
    check "the lock fd is closed for resolvconf" "$(cat "$STATE/calls")" \
        bash -c '! grep -q fd9-open "$1"' _ "$STATE/calls"

    reset_state
    rm "$STATE/healthy"
    out=$(run_repair)
    check "VPN not healthy: no repair" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0

    reset_state
    rm "$STATE/entry"
    out=$(run_repair)
    check "no tun0.protonvpn entry: no repair" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0

    reset_state
    mv "$WORK/resolv.conf" "$WORK/resolv.real"
    ln -s "$WORK/resolv.real" "$WORK/resolv.conf"
    out=$(run_repair)
    check "symlinked resolv.conf: refused" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0
    check "symlinked resolv.conf: logged" "$(cat "$STATE/log")" grep -q 'symlink' "$STATE/log"
    rm -f "$WORK/resolv.conf" "$WORK/resolv.real"
}

test_lock_dir() {
    local out
    reset_state
    mkdir -p "$WORK/elsewhere"
    ln -s "$WORK/elsewhere" "$WORK/run"
    out=$(run_repair)
    check "symlinked lock directory: refused" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0
    check "symlinked lock directory: nothing written through it" "$(ls -A "$WORK/elsewhere")" \
        test -z "$(ls -A "$WORK/elsewhere")"
    rm -f "$WORK/run"

    if [[ $EUID -ne 0 ]]; then
        reset_state
        out=$(RUN_DIR_OVERRIDE=/usr run_repair)
        check "lock directory owned by someone else: refused" "$out; $(cat "$STATE/calls")" \
            test "$out" == "rc=0" -a "$(repairs)" -eq 0
    else
        echo "  (skipped: lock directory owned by someone else; running as root)"
    fi

    reset_state
    mkdir -p "$WORK/run"
    chmod 770 "$WORK/run"
    out=$(run_repair)
    check "lock directory writable by its group: refused" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0

    reset_state
    : > "$WORK/notadir"
    out=$(RUN_DIR_OVERRIDE="$WORK/notadir/run" run_repair)
    check "lock directory cannot be created: returns 0, no repair" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0
    rm -f "$WORK/notadir"

    reset_state
    mkdir -p "$WORK/run/dns-repair.lock"
    out=$(run_repair)
    check "lock file cannot be opened: returns 0, no repair" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0
    check "lock file cannot be opened: logged" "$(cat "$STATE/log")" grep -q 'lock' "$STATE/log"

    reset_state
    out=$(run_repair 'mkdir -p "$RUN_DIR"; exec 8> "$LOCK_FILE"; flock -n 8')
    check "lock held by another repair: skipped" "$out; $(cat "$STATE/calls")" \
        test "$out" == "rc=0" -a "$(repairs)" -eq 0
    check "lock held by another repair: the skipped run is not recorded" "$(ls -A "$WORK/run")" \
        test ! -e "$WORK/run/dns-repair.times"
    out=$(run_repair)
    check "after the lock is released, the next run repairs" "$out; $(cat "$STATE/calls")" test "$(repairs)" -eq 1
}

test_rate_limit() {
    local out now
    reset_state
    for _ in 1 2 3; do
        out=$(run_repair)
    done
    cp "$WORK/run/dns-repair.times" "$WORK/times.before"
    out=$(run_repair)
    check "4 runs in a row: the 4th is rate limited" "$(cat "$STATE/calls")" test "$(repairs)" -eq 3
    check "a limited run logs a suspected loop" "$(cat "$STATE/log")" grep -q 'dns-change loop suspected' "$STATE/log"
    check "a limited run is not recorded (times file unchanged)" "$(cat "$WORK/run/dns-repair.times")" \
        cmp -s "$WORK/times.before" "$WORK/run/dns-repair.times"
    rm -f "$WORK/times.before"

    reset_state
    now=$(date +%s)
    mkdir -p "$WORK/run"
    printf '%s\n' $((now - 30)) $((now - 20)) $((now - 11)) > "$WORK/run/dns-repair.times"
    out=$(run_repair)
    check "runs older than 10 s do not count" "$out; $(cat "$STATE/calls")" test "$(repairs)" -eq 1

    reset_state
    mkdir -p "$WORK/run"
    printf '%s\n' $((now - 500)) $((now - 400)) $((now - 300)) $((now - 200)) $((now - 100)) > "$WORK/run/dns-repair.times"
    out=$(run_repair)
    check "the times file is pruned to the last 3 entries" "$(cat "$WORK/run/dns-repair.times")" \
        test "$(wc -l < "$WORK/run/dns-repair.times")" -eq 3 -a "$(tail -1 "$WORK/run/dns-repair.times")" -ge "$now"

    reset_state
    mkdir -p "$WORK/run"
    printf '%s\n' abc '1;id' '$(id)' '' ' 12' 0012 -5 > "$WORK/run/dns-repair.times"
    out=$(run_repair)
    check "a corrupt times file: bad lines dropped, repair runs" "$out; $(cat "$WORK/run/dns-repair.times")" \
        test "$(repairs)" -eq 1 -a -s "$WORK/run/dns-repair.times" -a "$(grep -cvE '^[1-9][0-9]*$' "$WORK/run/dns-repair.times")" -eq 0

    reset_state
    mkdir -p "$WORK/run"
    printf '%s\n' $((now + 100)) $((now + 200)) $((now + 300)) > "$WORK/run/dns-repair.times"
    out=$(run_repair)
    check "clock moved back: future timestamps dropped, repair runs" "$out; $(cat "$WORK/run/dns-repair.times")" \
        test "$(repairs)" -eq 1 -a "$(wc -l < "$WORK/run/dns-repair.times")" -eq 1
}

test_failures() {
    local out
    reset_state
    touch "$STATE/u_fails"
    out=$(run_repair)
    check "resolvconf -u failing: returns 0" "$out" test "$out" == "rc=0"
    check "resolvconf -u failing: logged as an error" "$(cat "$STATE/log")" grep -q 'ERROR' "$STATE/log"

    reset_state
    rm "$FAKES/resolvconf"
    out=$(run_repair)
    cp "$WORK/resolvconf.keep" "$FAKES/resolvconf"
    check "resolvconf missing: returns 0" "$out" test "$out" == "rc=0"

    reset_state
    touch "$STATE/logger_fails"
    rm "$STATE/healthy"
    out=$(run_repair)
    check "logger failing under set -e: returns 0" "$out" test "$out" == "rc=0"
    touch "$STATE/healthy"
    ln -sf "$WORK/resolv.conf" "$WORK/resolv.link"
    out=$(RESOLV_OVERRIDE="$WORK/resolv.link" run_repair)
    check "logger failing while logging a refusal: returns 0" "$out" test "$out" == "rc=0"
    rm -f "$WORK/resolv.link"
}

# ---------------------------------------------------------------------------
# Q4: a guard left behind with no VPN, no entry and the kill switch off
# ---------------------------------------------------------------------------
test_leftover_guard() {
    local out
    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    out=$(run_repair)
    check "leftover guard (no VPN, no entry, kill switch off): removed" "$out; $(fw iptables -S; fw ip6tables -S)" \
        guard_gone
    check "leftover guard removal is logged" "$(cat "$STATE/log")" grep -q 'leftover DNS guard' "$STATE/log"
    check "leftover guard removal never repairs resolv.conf" "$(cat "$STATE/calls")" test "$(repairs)" -eq 0

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    fw iptables -N VPN_KILL_SWITCH
    fw iptables -A OUTPUT -j VPN_KILL_SWITCH
    out=$(run_repair)
    check "kill switch on (IPv4): the guard stays (fail closed)" "$out" guard_left

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    fw ip6tables -N VPN_KILL_SWITCH_V6
    fw ip6tables -A OUTPUT -j VPN_KILL_SWITCH_V6
    out=$(run_repair)
    check "kill switch on (IPv6 only): the guard stays" "$out" guard_left

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    echo 0 > "$STATE/pgrep_rc"
    out=$(run_repair)
    check "an openvpn runs: the guard stays" "$out" guard_left

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    echo 2 > "$STATE/pgrep_rc"
    out=$(run_repair)
    check "pgrep fails: the guard stays" "$out" guard_left

    reset_state
    rm "$STATE/healthy"
    plant_guard
    out=$(run_repair)
    check "the VPN's entry is still registered: the guard stays" "$out" guard_left

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    touch "$FW/fail_S_v6"
    out=$(run_repair)
    check "firewall unreadable: the guard stays" "$out" guard_left

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    out=$(run_repair)
    check "no guard: nothing changed or logged" "$out; $(cat "$FW/calls" 2> /dev/null); $(cat "$STATE/log")" \
        bash -c '! grep -qE " -(D|F|X) " "$1" 2> /dev/null && [[ ! -s $2 ]]' _ "$FW/calls" "$STATE/log"

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    touch "$FW/fail_X_v4"
    out=$(run_repair)
    check "a chain that cannot be removed: returns 0" "$out" test "$out" == "rc=0"
    check "a chain that cannot be removed: warned with the fix" "$(cat "$STATE/log")" grep -q 'vpn cleanup' "$STATE/log"

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    plant_guard
    touch "$FW/fail_D_v4"
    out=$(run_repair)
    check "a jump that cannot be removed: its chain is left whole" "$out; $(fw iptables -S)" \
        bash -c '[[ $("$@" -S VPN_DNS_GUARD 2> /dev/null | wc -l) -eq 2 ]]' _ env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/iptables"
    check "a jump that cannot be removed: warned with the fix" "$(cat "$STATE/log")" grep -q 'vpn cleanup' "$STATE/log"

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    fw iptables -N VPN_DNS_GUARD
    fw ip6tables -N VPN_DNS_GUARD
    out=$(run_repair)
    check "a leftover chain without a jump: removed" "$out; $(fw iptables -S; fw ip6tables -S)" guard_gone

    reset_state
    rm "$STATE/entry" "$STATE/healthy"
    fw iptables -N VPN_DNS_GUARD
    fw iptables -I OUTPUT 1 -j VPN_DNS_GUARD
    mv "$FAKES/ip6tables" "$WORK/ip6tables.off"
    out=$(run_repair)
    mv "$WORK/ip6tables.off" "$FAKES/ip6tables"
    check "no ip6tables, IPv4 guard left over: removed" "$out; $(fw iptables -S)" \
        bash -c '! "$@" -S | grep -q VPN_DNS_GUARD' _ env PATH="$SANDBOX_PATH" FAKE_FW_DIR="$FW" "$FAKES/iptables"
}

cp "$FAKES/resolvconf" "$WORK/resolvconf.keep"

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}DNS Repair Hook Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_hook_file
test_hook_static
test_root_owned_safe
test_other_actions
if [[ -f $HOOK ]]; then
    test_repair
    test_lock_dir
    test_rate_limit
    test_failures
    test_leftover_guard
fi

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf '  failed: %s\n' "${FAILED_TESTS[@]}"
    exit 1
fi
exit 0

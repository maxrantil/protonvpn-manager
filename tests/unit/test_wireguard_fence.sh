#!/bin/bash
# ABOUTME: WireGuard profiles are refused until WireGuard support is complete (#265, #223)
# ABOUTME: Stub sudo/wg-quick record any call; no tunnel is ever brought up
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

export HOME="$WORK_DIR/home"
export XDG_RUNTIME_DIR="$WORK_DIR/run"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export VPN_LOG_DIR="$XDG_STATE_HOME/vpn"
export VPN_SESSION_DIR="$WORK_DIR/session"
export LOCATIONS_DIR="$HOME/.config/vpn/locations"
mkdir -p "$LOCATIONS_DIR" "$XDG_RUNTIME_DIR" "$VPN_LOG_DIR" "$WORK_DIR/bin"
chmod 700 "$XDG_RUNTIME_DIR"

# Any call to these is recorded and fails: nothing may reach the real system
CALLS="$WORK_DIR/calls"
for cmd in sudo wg-quick wg; do
    printf '#!/bin/bash\necho "%s $*" >> "%s"\nexit 1\n' "$cmd" "$CALLS" > "$WORK_DIR/bin/$cmd"
    chmod +x "$WORK_DIR/bin/$cmd"
done
# Every server answers ping, so only the WireGuard filter can keep one out
printf '#!/bin/sh\necho "rtt min/avg/max/mdev = 1.0/5.0/9.0/0.1 ms"\n' > "$WORK_DIR/bin/ping"
chmod +x "$WORK_DIR/bin/ping"
export PATH="$WORK_DIR/bin:$PATH"

WG="$LOCATIONS_DIR/wg-SE-374.conf"
cat > "$WG" << 'EOF'
[Interface]
PrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
Address = 10.2.0.2/32

[Peer]
PublicKey = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 203.0.113.9:51820
EOF
for name in se-1.ovpn se-2.protonvpn.udp.ovpn dk-3.ovpn; do
    printf 'client\nremote 203.0.113.7 1194\n' > "$LOCATIONS_DIR/$name"
done

# Run a connector function in a fresh shell; prints its output, returns its status
# Args: $1 = shell code run after sourcing the connector
connector() {
    bash -c "source '$SRC_DIR/vpn-connector' > /dev/null 2>&1; set +e; $1" 2>&1
}

test_refused_connect() {
    local fn="$1" out rc
    : > "$CALLS"
    out=$(connector "$fn '$WG'")
    rc=$?

    [[ $rc -ne 0 ]]
    report $? "$fn refuses a WireGuard profile" "exit $rc; output: $out"
    # 2 means "server did not answer", which would make failover try the next one
    [[ $rc -ne 2 ]]
    report $? "$fn: the refusal is not a 'server did not answer' failure (exit $rc)"
    [[ $out == *WireGuard* && $out == *"#223"* ]]
    report $? "$fn: tells why and points to #223" "output: $out"
    [[ ! -s $CALLS ]]
    report $? "$fn: never runs sudo, wg-quick or wg" "calls: $(tr '\n' ';' < "$CALLS")"
    [[ ! -e "$VPN_SESSION_DIR/wg-SE-374.conf" ]]
    report $? "$fn: writes no root config for wg-quick"
}

test_not_selected() {
    local got
    got=$(connector "find_profiles_by_country se" | xargs -r -n1 basename | sort | tr '\n' ' ')
    [[ $got == "se-1.ovpn se-2.protonvpn.udp.ovpn " ]]
    report $? "'vpn connect se' candidates leave out WireGuard profiles" "got: $got"

    got=$(connector "find_profiles_by_country ''" | xargs -r -n1 basename | sort | tr '\n' ' ')
    [[ $got == "dk-3.ovpn se-1.ovpn se-2.protonvpn.udp.ovpn " ]]
    report $? "'vpn connect' (any country) candidates leave out WireGuard profiles" "got: $got"
}

# Every profile listing (secure core, interactive, vpn list/countries) reads the cache
test_not_listed() {
    local got
    got=$(connector "type find_profiles_by_country > /dev/null && echo sourced")
    [[ $got == sourced ]]
    report $? "the connector sources cleanly" "output: $got"

    got=$(connector "get_cached_profiles" | xargs -r -n1 basename | sort | tr '\n' ' ')
    [[ $got == "dk-3.ovpn se-1.ovpn se-2.protonvpn.udp.ovpn " ]]
    report $? "the profile list (secure core, interactive, list) leaves out WireGuard profiles" "got: $got"

    got=$(bash "$SRC_DIR/vpn" list 2>&1)
    [[ $got != *wg-SE-374* && $got == *se-1* ]]
    report $? "'vpn list' leaves out WireGuard profiles" "output: $got"

    # Only a WireGuard profile for this country: nothing to pick
    local only="$WORK_DIR/wgonly/locations"
    mkdir -p "$only" && cp "$WG" "$only/"
    got=$(LOCATIONS_DIR="$only" connector "find_profiles_by_country se")
    [[ -z $got ]]
    report $? "a country with only WireGuard profiles has no candidates" "got: $got"

    # best-vpn-profile measures nothing for a WireGuard profile
    : > "$CALLS"
    got=$(printf '%s\n' "$WG" "$LOCATIONS_DIR/se-1.ovpn" | bash "$SRC_DIR/best-vpn-profile" rank 2>&1)
    [[ $got != *wg-SE-374* && $got == *se-1.ovpn* ]]
    report $? "best-vpn-profile does not rank WireGuard profiles" "output: $got"
    got=$(bash "$SRC_DIR/best-vpn-profile" test 2>&1)
    [[ $got != *wg-SE-374* && $got == *se-1* ]]
    report $? "best-vpn-profile test (all countries) leaves out WireGuard profiles" "output: $got"
}

# A refused profile stops failover (exit 1), it is not "did not answer" (exit 2)
test_failover_stops() {
    local out rc
    : > "$CALLS"
    out=$(connector "connect_openvpn_profile() { echo \"tried \$(basename \"\$1\")\"; return 2; }
        printf '%s\n' '$WG' '$LOCATIONS_DIR/se-1.ovpn' | connect_with_failover")
    rc=$?
    [[ $rc -eq 1 && $out != *"tried se-1"* && ! -s $CALLS ]]
    report $? "failover stops at a refused WireGuard profile" "exit $rc; output: $out"
}

# The file name is user-controlled: no terminal escapes or forged log lines
test_refusal_sanitized() {
    local evil out
    evil="$LOCATIONS_DIR/$(printf 'x\033[2Jy\nz.conf')"
    cp "$WG" "$evil"
    out=$(bash -c "source '$SRC_DIR/vpn-connector' > /dev/null 2>&1; set +e; refuse_wireguard \"\$1\"" _ "$evil" 2>&1)
    [[ $out != *$'\033[2J'* && $out != *$'y\nz'* ]]
    report $? "the refusal strips control characters from the file name" "output: $(printf '%q' "$out")"
    ! grep -q $'\033\[2J' "$VPN_LOG_DIR"/*.log 2> /dev/null && ! grep -qx 'z.conf' "$VPN_LOG_DIR"/*.log 2> /dev/null
    report $? "the refusal log line has no control characters"
    rm -f "$evil"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}WireGuard Fence Test Suite (#265)${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_not_selected
test_not_listed
test_failover_stops
test_refusal_sanitized
test_refused_connect connect_to_profile
test_refused_connect connect_custom_profile

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

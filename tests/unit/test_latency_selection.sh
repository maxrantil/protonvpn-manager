#!/bin/bash
# ABOUTME: Tests for latency-based server selection (best-vpn-profile + connector)
# ABOUTME: Uses a stub ping and a local TCP listener; no real network access needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
EVALUATOR="$SRC_DIR/best-vpn-profile"

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

# check <name> <expected> <actual>
check() {
	if [[ "$2" == "$3" ]]; then
		test_pass "$1"
	else
		test_fail "$1" "expected: '$2' got: '$3'"
	fi
}

WORK_DIR=$(mktemp -d)
LISTENER_PID=""
cleanup() {
	[[ -n $LISTENER_PID ]] && kill "$LISTENER_PID" 2> /dev/null
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

export HOME="$WORK_DIR/home"
export XDG_RUNTIME_DIR="$WORK_DIR/run"
export XDG_CONFIG_HOME="$HOME/.config"
export VPN_LATENCY_TCP_TIMEOUT=1
LOC="$HOME/.config/vpn/locations"
mkdir -p "$LOC" "$XDG_RUNTIME_DIR" "$WORK_DIR/bin" "$WORK_DIR/deadbin"
chmod 700 "$XDG_RUNTIME_DIR"

# Stub ping: fixed latencies per host; logs every host it is asked about
export PING_LOG="$WORK_DIR/ping.log"
cat > "$WORK_DIR/bin/ping" << 'EOF'
#!/bin/bash
host="${*: -1}"
echo "$host" >> "$PING_LOG"
case "$host" in
	10.0.0.1) avg=40.5 ;;
	10.0.0.2) avg=12.25 ;;
	10.0.0.3) avg=88 ;;
	10.0.0.4) avg=5.1 ;;
	*) exit 1 ;;
esac
echo "rtt min/avg/max/mdev = 1.0/$avg/2.0/0.1 ms"
EOF
# Stub ping that never gets an answer (ICMP filtered)
printf '#!/bin/sh\nexit 1\n' > "$WORK_DIR/deadbin/ping"
chmod +x "$WORK_DIR/bin/ping" "$WORK_DIR/deadbin/ping"
export PATH="$WORK_DIR/bin:$PATH"

ovpn() { printf 'client\nproto %s\nremote %s %s\n' "${4:-udp}" "$2" "${3:-1194}" > "$LOC/$1.ovpn"; }
ovpn se-1 10.0.0.1
ovpn se-2 10.0.0.2
ovpn se-3 10.0.0.3
ovpn dk-1 10.0.0.4
ovpn se-9 127.0.0.1 # no ping reply; TCP probe to 127.0.0.1:443 is refused

# Fresh state directory per scenario
state() { export XDG_STATE_HOME="$WORK_DIR/state-$1"; }

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Latency-based Server Selection Tests${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

# 1. Ranking: fastest first, unreachable servers omitted
state rank
ranked=$(printf '%s\n' "$LOC"/se-*.ovpn | bash "$EVALUATOR" rank 2> /dev/null | cut -f2 | xargs -n1 basename | tr '\n' ' ')
check "rank orders by latency and omits unreachable servers" "se-2.ovpn se-1.ovpn se-3.ovpn " "$ranked"

# 2. Country filter and CLI best
check "best se returns the fastest Swedish server" "se-2" "$(bash "$EVALUATOR" best se 2> /dev/null)"
check "best without country considers all servers" "dk-1" "$(bash "$EVALUATOR" best 2> /dev/null)"

# 3. Cache: reused within max-age, re-measured when max-age is 0
: > "$PING_LOG"
bash "$EVALUATOR" best se > /dev/null 2>&1
check "best reuses fresh measurements (no pings)" "0" "$(wc -l < "$PING_LOG")"
: > "$PING_LOG"
bash "$EVALUATOR" fresh se > /dev/null 2>&1
check "fresh re-measures every candidate" "4" "$(wc -l < "$PING_LOG")"
cache="$XDG_STATE_HOME/vpn/vpn_performance.cache"
check "cache file is private (600)" "600" "$(stat -c %a "$cache" 2> /dev/null)"
check "cache lines have 4 tab-separated fields" "0" "$(awk -F '\t' 'NF != 4' "$cache" | wc -l)"

# 4. ICMP is preferred over TCP: a TCP-only answer must not win
LISTEN_PORT=""
if command -v python3 > /dev/null 2>&1; then
	LISTEN_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
	python3 -c "
import socket
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $LISTEN_PORT)); s.listen(64)
while True:
    c, _ = s.accept(); c.close()
" &
	LISTENER_PID=$!
	sleep 0.5
fi
if [[ -n $LISTEN_PORT ]]; then
	ovpn tcp-1 127.0.0.1 "$LISTEN_PORT" tcp
	state prefer
	best=$(printf '%s\n' "$LOC/se-3.ovpn" "$LOC/tcp-1.ovpn" | bash "$EVALUATOR" rank 2> /dev/null | head -1 | cut -f2)
	check "ICMP result wins over a (faster) TCP-only answer" "$LOC/se-3.ovpn" "$best"

	# 5. TCP fallback when no server answers ping at all
	state tcpfallback
	# se-9 (127.0.0.1:443) refuses, so only the listener can answer, on any network
	out=$(printf '%s\n' "$LOC/se-9.ovpn" "$LOC/tcp-1.ovpn" | PATH="$WORK_DIR/deadbin:$PATH" bash "$EVALUATOR" rank 2>&1)
	check "TCP handshake time is used when ICMP is filtered everywhere" "$LOC/tcp-1.ovpn" "$(grep -v '^Note' <<< "$out" | head -1 | cut -f2)"
	if grep -q "no server answered ping" <<< "$out"; then
		test_pass "TCP fallback is announced"
	else
		test_fail "TCP fallback is announced"
	fi
else
	test_pass "ICMP/TCP preference tests (skipped: python3 unavailable)"
fi

# 6. Nothing answers -> rank fails
state none
if printf '%s\n' "$LOC/se-9.ovpn" | PATH="$WORK_DIR/deadbin:$PATH" bash "$EVALUATOR" rank > /dev/null 2>&1; then
	test_fail "rank fails when no server answers"
else
	test_pass "rank fails when no server answers"
fi

# 7. Malicious remote hosts are never passed to ping/bash
cat > "$LOC/evil-1.ovpn" << 'EOF'
client
remote -oProxyCommand=touch 1194
EOF
cat > "$LOC/evil-2.ovpn" << EOF
client
remote \$(touch $WORK_DIR/pwned) 1194
EOF
state evil
: > "$PING_LOG"
best=$(printf '%s\n' "$LOC/evil-1.ovpn" "$LOC/evil-2.ovpn" "$LOC/se-1.ovpn" | bash "$EVALUATOR" rank 2> /dev/null | cut -f2)
check "only the valid host in the batch is probed" "10.0.0.1" "$(tr '\n' ' ' < "$PING_LOG" | xargs)"
check "invalid hosts are left out of the ranking" "$LOC/se-1.ovpn" "$best"
if [[ ! -e $WORK_DIR/pwned ]]; then
	test_pass "remote host is not shell-evaluated"
else
	test_fail "remote host is not shell-evaluated"
fi
rm -f "$LOC/evil-1.ovpn" "$LOC/evil-2.ovpn"

# 8. Connector: connect picks the fastest server for the country
connector() {
	bash -c '
		source "$1/vpn-connector" > /dev/null 2>&1
		set +e
		connect_to_profile() { echo "CONNECT $(basename "$1")"; }
		shift
		"$@"
	' _ "$SRC_DIR" "$@" 2> /dev/null | grep '^CONNECT' | tail -1
}
state c1
check "vpn connect se uses the fastest Swedish server" "CONNECT se-2.ovpn" "$(connector connect_by_country se)"
state c2
check "vpn best dk re-measures and connects" "CONNECT dk-1.ovpn" "$(connector best_server_connect full dk)"

# 9. SERVER_SELECTION=random skips measuring entirely
state c3
echo "SERVER_SELECTION=random" > "$HOME/.config/vpn/config"
: > "$PING_LOG"
picked=$(connector connect_by_country se)
if [[ $picked == CONNECT\ se-*.ovpn ]]; then
	test_pass "random selection still connects"
else
	test_fail "random selection still connects" "$picked"
fi
check "random selection sends no pings" "0" "$(wc -l < "$PING_LOG")"
: > "$HOME/.config/vpn/config"

# 10. Nothing answers: connect falls back to random, best fails
mkdir -p "$WORK_DIR/only9/locations"
cp "$LOC/se-9.ovpn" "$WORK_DIR/only9/locations/se-9.ovpn"
cp "$LOC/se-9.ovpn" "$WORK_DIR/only9/locations/se-8.ovpn"
state c4
picked=$(LOCATIONS_DIR="$WORK_DIR/only9/locations" PATH="$WORK_DIR/deadbin:$PATH" connector connect_by_country se)
if [[ $picked == CONNECT\ se-[89].ovpn ]]; then
	test_pass "connect falls back to a random server when nothing answers"
else
	test_fail "connect falls back to a random server when nothing answers" "$picked"
fi
state c5
if LOCATIONS_DIR="$WORK_DIR/only9/locations" PATH="$WORK_DIR/deadbin:$PATH" bash -c '
	source "$1/vpn-connector" > /dev/null 2>&1
	set +e
	connect_to_profile() { return 0; }
	best_server_connect full se
' _ "$SRC_DIR" > /dev/null 2>&1; then
	test_fail "vpn best fails when no server answers"
else
	test_pass "vpn best fails when no server answers"
fi

# 11. secure: never silently falls back to a regular server
state s1
picked=$(connector secure_core_connect)
if [[ -z $picked ]]; then
	test_pass "secure fails instead of using a regular server when no Secure Core profile exists"
else
	test_fail "secure fails instead of using a regular server when no Secure Core profile exists" "$picked"
fi
ovpn ch-se-1 10.0.0.3
ovpn is-se-1 10.0.0.2
state s2
check "secure picks the fastest Secure Core server" "CONNECT is-se-1.ovpn" "$(connector secure_core_connect)"
rm -f "$LOC/ch-se-1.ovpn" "$LOC/is-se-1.ovpn"

# 12. Failover: a server that does not answer is skipped; other failures stop
failover() {
	# $1 = per-profile results "name=rc ..." for the stubbed connect_to_profile
	bash -c '
		source "$1/vpn-connector" > /dev/null 2>&1
		set +e
		results="$2"
		connect_to_profile() {
			local name rc
			name=$(basename "$1" .ovpn)
			echo "TRY $name attempts=$2"
			rc=$(tr " " "\n" <<< "$results" | sed -n "s/^$name=//p")
			return "${rc:-1}"
		}
		printf "%s\n" "$3/se-2.ovpn" "$3/se-1.ovpn" "$3/se-3.ovpn" | connect_with_failover
		echo "rc=$?"
	' _ "$SRC_DIR" "$1" "$LOC" 2> /dev/null | grep -E "^(TRY|rc=)" | tr '\n' ' '
}
check "failover moves on when the fastest server does not answer" \
	"TRY se-2 attempts=1 TRY se-1 attempts=1 rc=0 " "$(failover "se-2=2 se-1=0")"
check "failover stops on a non-timeout failure (e.g. bad credentials)" \
	"TRY se-2 attempts=1 rc=1 " "$(failover "se-2=1 se-1=0")"
check "failover reports a timeout when no server answers" \
	"TRY se-2 attempts=1 TRY se-1 attempts=1 TRY se-3 attempts=1 rc=2 " "$(failover "se-2=2 se-1=2 se-3=2")"
single=$(bash -c '
	source "$1/vpn-connector" > /dev/null 2>&1
	set +e
	connect_to_profile() { echo "TRY attempts=$2"; return 0; }
	echo "$2/se-1.ovpn" | connect_with_failover
' _ "$SRC_DIR" "$LOC" 2> /dev/null | grep '^TRY')
check "a single candidate keeps the usual 3 attempts" "TRY attempts=3" "$single"

# 13. Connecting only needs openvpn, ip and flock
mkdir -p "$WORK_DIR/depbin"
for c in openvpn ip flock; do printf '#!/bin/sh\n' > "$WORK_DIR/depbin/$c"; chmod +x "$WORK_DIR/depbin/$c"; done
if bash -c '
	source "$1/vpn-connector" > /dev/null 2>&1
	set +e
	PATH="$2"
	check_dependencies
' _ "$SRC_DIR" "$WORK_DIR/depbin" > /dev/null 2>&1; then
	test_pass "dependency check needs only openvpn, ip and flock (no curl/bc/notify-send/wg-quick)"
else
	test_fail "dependency check needs only openvpn, ip and flock (no curl/bc/notify-send/wg-quick)"
fi

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
	for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
	exit 1
fi
exit 0

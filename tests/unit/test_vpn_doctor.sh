#!/bin/bash
# ABOUTME: Unit tests for vpn-doctor: every run reaches all checks and the summary
# ABOUTME: Covers no/one/two OpenVPN processes and a first-check WARN (issue #259)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCTOR="$PROJECT_ROOT/src/vpn-doctor"

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

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

# Isolated HOME with a valid configuration; fake pgrep reports
# FAKE_OPENVPN_PIDS (space-separated) for the OpenVPN pattern, with real
# pgrep semantics: -c prints the count, exit 1 when nothing matches.
# FAKE_PGREP_BROKEN=1 makes it print garbage and exit 2 (pgrep error).
# Stub openvpn/curl/ip make the dependency check PASS on any host (CI has no
# openvpn), so exit codes depend only on the case under test.
setup_env() {
	rm -rf "${WORK:?}/home" "${WORK:?}/bin"
	mkdir -p "$WORK/home/.config/vpn/locations" "$WORK/bin"
	chmod 700 "$WORK/home/.config/vpn"
	chmod 750 "$WORK/home/.config/vpn/locations"
	printf 'user\npass\n' > "$WORK/home/.config/vpn/vpn-credentials.txt"
	chmod 600 "$WORK/home/.config/vpn/vpn-credentials.txt"
	printf 'client\nremote 192.0.2.1 1194\n' > "$WORK/home/.config/vpn/locations/se-01.ovpn"
	cat > "$WORK/bin/pgrep" << 'EOF'
#!/bin/bash
count=0
if [[ -n ${FAKE_PGREP_BROKEN:-} ]]; then
	echo "pgrep: garbage"
	exit 2
fi
for a in "$@"; do
	if [[ $a == -c ]] || [[ $a == -*c* && $a != --* ]]; then count=1; fi
done
read -ra pids <<< "${FAKE_OPENVPN_PIDS:-}"
if [[ $count -eq 1 ]]; then
	echo "${#pids[@]}"
else
	[[ ${#pids[@]} -gt 0 ]] && printf '%s\n' "${pids[@]}"
fi
[[ ${#pids[@]} -gt 0 ]]
EOF
	chmod 755 "$WORK/bin/pgrep"
	local cmd
	for cmd in openvpn curl ip; do
		printf '#!/bin/bash\necho "%s 2.6.0 stub"\n' "$cmd" > "$WORK/bin/$cmd"
		chmod 755 "$WORK/bin/$cmd"
	done
}

# Run the doctor; sets OUT and RC
run_doctor() {
	local pids="$1"
	shift
	OUT=$(env -u VPN_CONFIG_DIR -u LOCATIONS_DIR HOME="$WORK/home" \
		XDG_STATE_HOME="$WORK/home/.local/state" PATH="$WORK/bin:$PATH" \
		FAKE_OPENVPN_PIDS="$pids" FAKE_PGREP_BROKEN="${FAKE_PGREP_BROKEN:-}" NO_COLOR=1 \
		bash "$DOCTOR" --no-network "$@" 2>&1 < /dev/null)
	RC=$?
}

expect_complete_run() {
	local name="$1"
	if [[ $OUT == *"[5/5]"* && $OUT == *"Diagnostic Summary"* ]]; then
		test_pass "$name: all 5 checks and the summary are printed"
	else
		test_fail "$name: all 5 checks and the summary are printed" "rc=$RC; last lines:\n$(tail -5 <<< "$OUT")"
	fi
}

expect_rc() {
	local name="$1" want="$2"
	if [[ $RC -eq $want ]]; then
		test_pass "$name: exit code $want"
	else
		test_fail "$name: exit code $want" "got rc=$RC; last lines:\n$(tail -5 <<< "$OUT")"
	fi
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}VPN Doctor Unit Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

echo ""
echo -e "${T_BLUE}No OpenVPN running (VPN disconnected)${T_NC}"
setup_env
run_doctor ""
expect_complete_run "disconnected"
expect_rc "disconnected" 0
if [[ $OUT != *"Multiple VPN processes"* ]]; then
	test_pass "disconnected: not reported as multiple VPN processes"
else
	test_fail "disconnected: not reported as multiple VPN processes" "$(grep -A2 'Process Health' <<< "$OUT")"
fi
run_doctor "" --verbose
if [[ $OUT == *"No VPN processes running"* ]]; then
	test_pass "disconnected: process check reports no VPN processes (INFO)"
else
	test_fail "disconnected: process check reports no VPN processes (INFO)" "$(grep -A3 'Process Health' <<< "$OUT")"
fi
run_doctor "" --json
if [[ $OUT == *'"exit_code"'* && $OUT == *'"process_health"'* ]]; then
	test_pass "disconnected: --json output is complete"
else
	test_fail "disconnected: --json output is complete" "rc=$RC; $(tail -3 <<< "$OUT")"
fi

echo ""
echo -e "${T_BLUE}One OpenVPN process${T_NC}"
run_doctor "4242" --verbose
expect_complete_run "connected"
expect_rc "connected" 0
if [[ $OUT == *"Single VPN process running"* ]]; then
	test_pass "connected: process check reports a single process"
else
	test_fail "connected: process check reports a single process" "$(grep -A3 'Process Health' <<< "$OUT")"
fi

echo ""
echo -e "${T_BLUE}Two OpenVPN processes${T_NC}"
run_doctor "4242 4343"
expect_complete_run "two processes"
if [[ $OUT == *"Multiple VPN processes detected (2)"* && $RC -eq 1 ]]; then
	test_pass "two processes: FAIL with count 2, exit code 1"
else
	test_fail "two processes: FAIL with count 2, exit code 1" "rc=$RC; $(grep -A3 'Process Health' <<< "$OUT")"
fi

run_doctor "1 2 3"
if [[ $OUT == *"Multiple VPN processes detected (3)"* && $RC -eq 1 ]]; then
	test_pass "three processes: FAIL with count 3, exit code 1"
else
	test_fail "three processes: FAIL with count 3, exit code 1" "rc=$RC; $(grep -A3 'Process Health' <<< "$OUT")"
fi

echo ""
echo -e "${T_BLUE}pgrep fails (prints garbage, exit 2)${T_NC}"
FAKE_PGREP_BROKEN=1 run_doctor "" --verbose
expect_complete_run "broken pgrep"
expect_rc "broken pgrep" 0
if [[ $OUT == *"No VPN processes running"* ]]; then
	test_pass "broken pgrep: treated as no VPN processes"
else
	test_fail "broken pgrep: treated as no VPN processes" "$(grep -A3 'Process Health' <<< "$OUT")"
fi

echo ""
echo -e "${T_BLUE}First counted result is a WARN${T_NC}"
setup_env
chmod 755 "$WORK/home/.config/vpn"
run_doctor "4242"
expect_complete_run "insecure config dir"
expect_rc "insecure config dir" 2
if [[ $OUT == *"insecure permissions (755"* && $OUT == *"Warnings: 1 checks"* ]]; then
	test_pass "insecure config dir: warning is shown and counted once"
else
	test_fail "insecure config dir: warning is shown and counted once" "$(grep -A3 'File Permissions' <<< "$OUT")"
fi
run_doctor "4242" --fix
expect_complete_run "insecure config dir, --fix"
expect_rc "insecure config dir, --fix" 2

echo ""
echo -e "${T_BLUE}First counted result is a FAIL${T_NC}"
setup_env
rm "$WORK/home/.config/vpn/vpn-credentials.txt"
run_doctor "4242"
expect_complete_run "missing credentials"
expect_rc "missing credentials" 1
if [[ $OUT == *"Failed: 1 checks"* ]]; then
	test_pass "missing credentials: failure counted once"
else
	test_fail "missing credentials: failure counted once" "$(tail -8 <<< "$OUT")"
fi

echo ""
echo -e "${T_BLUE}========================================${T_NC}"
echo "Tests run: $TESTS_RUN, passed: $TESTS_PASSED, failed: $TESTS_FAILED"
if [[ $TESTS_FAILED -gt 0 ]]; then
	printf '  - %s\n' "${FAILED_TESTS[@]}"
	exit 1
fi
exit 0

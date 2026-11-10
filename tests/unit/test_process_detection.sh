#!/bin/bash
# ABOUTME: Unit tests for VPN process detection functions
# ABOUTME: Ensures get_vpn_pid works with full paths and monitors return clean exit codes

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPN_DIR="$PROJECT_ROOT/src"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes for test output
T_GREEN='\033[1;32m'
T_RED='\033[1;31m'
T_BLUE='\033[1;34m'
T_NC='\033[0m'

declare -a FAILED_TESTS=()

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

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}VPN Process Detection Unit Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

#############################################
# Test Suite 1: pgrep Pattern Matching
#############################################
echo ""
echo -e "${T_BLUE}Test Suite 1: pgrep Pattern Matching${T_NC}"

# Test: Pattern matches full path /usr/bin/openvpn
test_pgrep_full_path() {
	local pattern="/openvpn.*--config|^openvpn.*--config"

	# Simulate command line with full path
	local test_cmd="/usr/bin/openvpn --config /path/to/config.ovpn --daemon"

	if echo "$test_cmd" | grep -qE "$pattern"; then
		test_pass "pgrep pattern matches full path (/usr/bin/openvpn)"
	else
		test_fail "pgrep pattern matches full path (/usr/bin/openvpn)" "Pattern: $pattern"
	fi
}

# Test: Pattern matches bare openvpn command
test_pgrep_bare_command() {
	local pattern="/openvpn.*--config|^openvpn.*--config"

	# Simulate command line without full path
	local test_cmd="openvpn --config /path/to/config.ovpn --daemon"

	if echo "$test_cmd" | grep -qE "$pattern"; then
		test_pass "pgrep pattern matches bare command (openvpn)"
	else
		test_fail "pgrep pattern matches bare command (openvpn)" "Pattern: $pattern"
	fi
}

# Test: Pattern matches /usr/local/bin/openvpn
test_pgrep_usr_local() {
	local pattern="/openvpn.*--config|^openvpn.*--config"

	local test_cmd="/usr/local/bin/openvpn --config /path/to/config.ovpn"

	if echo "$test_cmd" | grep -qE "$pattern"; then
		test_pass "pgrep pattern matches /usr/local/bin/openvpn"
	else
		test_fail "pgrep pattern matches /usr/local/bin/openvpn" "Pattern: $pattern"
	fi
}

# Test: Pattern does NOT match random processes containing 'openvpn' string
test_pgrep_no_false_positives() {
	local pattern="/openvpn.*--config|^openvpn.*--config"

	# Should NOT match: editor viewing openvpn config
	local test_cmd="vim /etc/openvpn/server.conf"

	if echo "$test_cmd" | grep -qE "$pattern"; then
		test_fail "pgrep pattern rejects non-openvpn process" "Matched: $test_cmd"
	else
		test_pass "pgrep pattern rejects non-openvpn process"
	fi
}

# Test: Pattern requires --config flag
test_pgrep_requires_config_flag() {
	local pattern="/openvpn.*--config|^openvpn.*--config"

	# Should NOT match openvpn without --config
	local test_cmd="/usr/bin/openvpn --help"

	if echo "$test_cmd" | grep -qE "$pattern"; then
		test_fail "pgrep pattern requires --config flag" "Matched: $test_cmd"
	else
		test_pass "pgrep pattern requires --config flag"
	fi
}

test_pgrep_full_path
test_pgrep_bare_command
test_pgrep_usr_local
test_pgrep_no_false_positives
test_pgrep_requires_config_flag

#############################################
# Test Suite 2: Verify Pattern in Source Code
#############################################
echo ""
echo -e "${T_BLUE}Test Suite 2: Source Code Pattern Verification${T_NC}"

# Test: vpn-manager uses correct pgrep pattern
test_vpn_manager_pattern() {
	local src_file="$PROJECT_ROOT/src/vpn-manager"

	if [[ ! -f "$src_file" ]]; then
		test_fail "vpn-manager source exists" "File not found: $src_file"
		return
	fi

	# Check that the pattern handles full paths (contains /openvpn).
	# The shared pattern lives in vpn-validators (OPENVPN_PGREP_PATTERN).
	if grep -q '/openvpn.*--config' "$src_file" ||
		{ grep -q 'OPENVPN_PGREP_PATTERN' "$src_file" &&
			grep -qF "OPENVPN_PGREP_PATTERN='(^|/)openvpn" "$PROJECT_ROOT/src/vpn-validators"; }; then
		test_pass "vpn-manager pgrep pattern handles full paths"
	else
		test_fail "vpn-manager pgrep pattern handles full paths" \
			"Pattern should include '/openvpn' to match /usr/bin/openvpn"
	fi
}

test_vpn_manager_pattern

#############################################
# Test Suite 3: Monitor Result Capture
#############################################
echo ""
echo -e "${T_BLUE}Test Suite 3: Monitor Result Capture${T_NC}"

# Test: vpn-connector captures exit code correctly (not stdout)
test_monitor_result_is_exit_code() {
	local src_file="$PROJECT_ROOT/src/vpn-connector"

	if [[ ! -f "$src_file" ]]; then
		test_fail "vpn-connector source exists" "File not found: $src_file"
		return
	fi

	# The bug was: monitor_result=$(func; echo $?) which captures stdout + exit code
	# The fix is: func; monitor_result=$?

	# Check for the buggy pattern (subshell capturing stdout)
	if grep -q 'monitor_result=\$(' "$src_file"; then
		# Found subshell assignment - check if it's the buggy pattern
		if grep -q 'monitor_connection_establishment_with_backoff.*echo \$?' "$src_file"; then
			test_fail "monitor_result captures only exit code" \
				"Found buggy pattern: capturing stdout with exit code causes arithmetic errors"
		else
			test_pass "monitor_result captures only exit code"
		fi
	else
		# No subshell - check for correct pattern
		if grep -q 'monitor_connection_establishment_with_backoff' "$src_file" && \
		   grep -q 'monitor_result=\$?' "$src_file"; then
			test_pass "monitor_result captures only exit code"
		else
			test_fail "monitor_result captures only exit code" \
				"Could not verify correct exit code capture pattern"
		fi
	fi
}

# Test: Arithmetic comparison uses clean integer
test_monitor_result_arithmetic_safe() {
	local src_file="$PROJECT_ROOT/src/vpn-connector"

	if [[ ! -f "$src_file" ]]; then
		test_fail "vpn-connector source exists" "File not found: $src_file"
		return
	fi

	# The monitor_result should be used in arithmetic comparison
	# This would fail if monitor_result contains non-numeric content
	if grep -qE '\[\[ \$monitor_result -eq [0-9]+ \]\]' "$src_file"; then
		test_pass "monitor_result used in arithmetic comparison"
	else
		test_fail "monitor_result used in arithmetic comparison" \
			"Expected pattern: [[ \$monitor_result -eq N ]]"
	fi
}

test_monitor_result_is_exit_code
test_monitor_result_arithmetic_safe

#############################################
# Test Suite 4: Integration Pattern Tests
#############################################
echo ""
echo -e "${T_BLUE}Test Suite 4: Integration Pattern Tests${T_NC}"

# Test: get_vpn_pid function exists and is callable
test_get_vpn_pid_exists() {
	local result
	result=$(bash -c "
		set +e
		export VPN_DIR='$VPN_DIR'
		source '$VPN_DIR/vpn-manager' 2>/dev/null
		type get_vpn_pid 2>&1
	")

	if echo "$result" | grep -q "function"; then
		test_pass "get_vpn_pid function exists"
	else
		test_fail "get_vpn_pid function exists" "Result: $result"
	fi
}

# Test: is_vpn_running function exists and is callable
test_is_vpn_running_exists() {
	local result
	result=$(bash -c "
		set +e
		export VPN_DIR='$VPN_DIR'
		source '$VPN_DIR/vpn-manager' 2>/dev/null
		type is_vpn_running 2>&1
	")

	if echo "$result" | grep -q "function"; then
		test_pass "is_vpn_running function exists"
	else
		test_fail "is_vpn_running function exists" "Result: $result"
	fi
}

test_get_vpn_pid_exists
test_is_vpn_running_exists

#############################################
# Test Suite 4: Status report with and without a tunnel
#############################################
echo ""
echo -e "${T_BLUE}Test Suite 4: Status report with and without a tunnel${T_NC}"

# The real `vpn-manager status` next to a fake OpenVPN (argv[0] .../openvpn,
# --config in the command line), with `ip` stubbed: $STATUS_NET/tunnel makes
# tun0 exist, $STATUS_NET/address gives it an address. HOME, the runtime dir
# and every privileged or network command are stand-ins.
STATUS_WORK=$(mktemp -d)
STATUS_NET="$STATUS_WORK/net"
STATUS_FAKE_PID=""
trap '[[ -n $STATUS_FAKE_PID ]] && kill "$STATUS_FAKE_PID" 2> /dev/null; rm -rf "$STATUS_WORK"' EXIT
mkdir -p "$STATUS_NET" "$STATUS_WORK/stubs" "$STATUS_WORK/home" "$STATUS_WORK/run" "$STATUS_WORK/fake"
chmod 700 "$STATUS_WORK/run"
cat > "$STATUS_WORK/stubs/ip" << EOF
#!/bin/bash
net="$STATUS_NET"
EOF
cat >> "$STATUS_WORK/stubs/ip" << 'EOF'
case "$*" in
	"link show"*tun0* | "-o link show"*) [[ -f $net/tunnel ]] && echo "5: tun0: <POINTOPOINT,UP> mtu 1500" ;;
	"link show"*)
		echo "1: lo: <LOOPBACK,UP> mtu 65536"
		[[ -f $net/tunnel ]] && echo "5: tun0: <POINTOPOINT,UP> mtu 1500"
		;;
	"addr show"*) [[ -f $net/address ]] && echo "    inet 10.2.0.2/32 scope global tun0" ;;
	route*) [[ -f $net/address ]] && echo "0.0.0.0/1 via 10.2.0.1 dev tun0" ;;
esac
exit 0
EOF
printf '#!/bin/bash\necho 203.0.113.7\n' > "$STATUS_WORK/stubs/curl"
printf '#!/bin/bash\nexit 0\n' > "$STATUS_WORK/stubs/notify-send"
printf '#!/bin/bash\nexit 1\n' > "$STATUS_WORK/stubs/sudo"
# Only the fake counts as a running OpenVPN, also on a machine with a real session
cat > "$STATUS_WORK/stubs/pgrep" << EOF
#!/bin/bash
if [[ \$* == *openvpn* ]]; then
	pid=\$(cat "$STATUS_WORK/fake.pid" 2> /dev/null)
	[[ -n \$pid ]] && { echo "\$pid"; exit 0; }
	exit 1
fi
exec /usr/bin/pgrep "\$@"
EOF
chmod +x "$STATUS_WORK/stubs"/*
: > "$STATUS_WORK/fake/profile.ovpn"

start_status_fake_openvpn() {
	bash -c 'exec -a "$0 --config $1" sleep 60' "$STATUS_WORK/fake/openvpn" "$STATUS_WORK/fake/profile.ovpn" &
	STATUS_FAKE_PID=$!
	local i
	for ((i = 0; i < 50; i++)); do
		if pgrep -f '(^|/)openvpn .*--config' | grep -qx "$STATUS_FAKE_PID"; then
			echo "$STATUS_FAKE_PID" > "$STATUS_WORK/fake.pid"
			return 0
		fi
		sleep 0.1
	done
	return 1
}

STATUS_OUT=""
STATUS_RC=0
run_status() { # extra env assignments as arguments
	STATUS_RC=0
	STATUS_OUT=$(env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME "$@" \
		HOME="$STATUS_WORK/home" XDG_RUNTIME_DIR="$STATUS_WORK/run" NO_COLOR=1 \
		PATH="$STATUS_WORK/stubs:$PATH" timeout 20 bash "$VPN_DIR/vpn-manager" status 2>&1 < /dev/null) || STATUS_RC=$?
}

test_status_reports_process_without_tunnel() {
	rm -f "$STATUS_NET"/*
	run_status
	# (the PID may be a real session's: /var/run/openvpn.pid is read first)
	if [[ $STATUS_RC -eq 0 ]] && grep -qE "Process ID: [0-9]+" <<< "$STATUS_OUT" &&
		grep -qi "no tunnel" <<< "$STATUS_OUT" && ! grep -q "Status: CONNECTED" <<< "$STATUS_OUT"; then
		test_pass "status: OpenVPN running without a tunnel is reported as such (exit 0)"
	else
		test_fail "status: OpenVPN running without a tunnel is reported as such (exit 0)" "exit $STATUS_RC: $STATUS_OUT"
	fi
	run_status VPN_ACCESSIBLE_MODE=1
	if [[ $STATUS_RC -eq 0 ]] && grep -qi "no tunnel" <<< "$STATUS_OUT" && grep -q "Active Network Tunnels: 0" <<< "$STATUS_OUT"; then
		test_pass "status (accessible mode): no tunnel reported (exit 0)"
	else
		test_fail "status (accessible mode): no tunnel reported (exit 0)" "exit $STATUS_RC: $STATUS_OUT"
	fi
}

# While a connection comes up, tun0 exists before it has an address or route
test_status_tunnel_without_address() {
	rm -f "$STATUS_NET"/* && touch "$STATUS_NET/tunnel"
	run_status
	if [[ $STATUS_RC -eq 0 ]] && grep -q "Status: CONNECTED" <<< "$STATUS_OUT" && grep -q "Interface: tun0" <<< "$STATUS_OUT"; then
		test_pass "status: tunnel without address or route yet (exit 0)"
	else
		test_fail "status: tunnel without address or route yet (exit 0)" "exit $STATUS_RC: $STATUS_OUT"
	fi
	touch "$STATUS_NET/address"
	run_status
	if [[ $STATUS_RC -eq 0 ]] && grep -q "VPN IP: 10.2.0.2" <<< "$STATUS_OUT" && grep -q "Gateway: 10.2.0.1" <<< "$STATUS_OUT"; then
		test_pass "status: connected tunnel shows its address and gateway"
	else
		test_fail "status: connected tunnel shows its address and gateway" "exit $STATUS_RC: $STATUS_OUT"
	fi
}

# `grep -c` prints 0 and exits 1 when nothing matches: the count must appear once
test_status_counts_tunnels_once() {
	rm -f "$STATUS_NET"/*
	run_status
	if grep -qx "  Active tunnels: 0" <<< "$STATUS_OUT" && ! grep -qx "0" <<< "$STATUS_OUT"; then
		test_pass "status: 'Active tunnels: 0' printed once, no stray 0 line"
	else
		test_fail "status: 'Active tunnels: 0' printed once, no stray 0 line" "$(grep -n -A1 'Active tunnels' <<< "$STATUS_OUT")"
	fi
}

if start_status_fake_openvpn; then
	test_status_reports_process_without_tunnel
	test_status_tunnel_without_address
	test_status_counts_tunnels_once
	kill "$STATUS_FAKE_PID" 2> /dev/null
	STATUS_FAKE_PID=""
else
	test_fail "status tests: fake OpenVPN did not start"
fi

#############################################
# Summary
#############################################
echo ""
echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Test Summary${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"
echo -e "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${T_GREEN}$TESTS_PASSED${T_NC}"
echo -e "Tests failed: ${T_RED}$TESTS_FAILED${T_NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
	echo ""
	echo -e "${T_RED}Failed tests:${T_NC}"
	for test in "${FAILED_TESTS[@]}"; do
		echo -e "  ${T_RED}✗${T_NC} $test"
	done
	exit 1
fi

echo ""
echo -e "${T_GREEN}All tests passed!${T_NC}"
exit 0

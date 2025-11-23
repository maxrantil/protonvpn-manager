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

	# Check that the pattern handles full paths (contains /openvpn)
	if grep -q '/openvpn.*--config' "$src_file"; then
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

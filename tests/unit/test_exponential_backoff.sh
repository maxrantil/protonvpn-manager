#!/bin/bash
# ABOUTME: Unit tests for exponential backoff connection optimization (Issue #62)
# ABOUTME: Checks backoff shape/budget and that the monitor loop breaks early on success

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$(cd "$SCRIPT_DIR/../../src" && pwd)"
CONNECTOR="$VPN_DIR/vpn-connector"
MONITOR_FN="monitor_connection_establishment_with_backoff"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Upper bound for the whole wait per attempt (seconds). The intervals were
# deliberately extended for post-wake network instability; keep a ceiling so
# a single attempt cannot silently grow unbounded.
MAX_TOTAL_WAIT=40

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helpers (plain arithmetic: ((x++)) returns 1 when x is 0)
assert_equals() {
	local expected="$1"
	local actual="$2"
	local test_name="$3"

	TEST_COUNT=$((TEST_COUNT + 1))
	if [[ "$expected" == "$actual" ]]; then
		echo -e "${GREEN}  ✓ $test_name${NC}"
		PASS_COUNT=$((PASS_COUNT + 1))
		return 0
	fi
	echo -e "${RED}  ✗ $test_name${NC}"
	echo -e "${RED}    Expected: $expected${NC}"
	echo -e "${RED}    Got: $actual${NC}"
	FAIL_COUNT=$((FAIL_COUNT + 1))
	return 1
}

assert_true() {
	local condition="$1"
	local test_name="$2"
	local detail="${3:-}"

	TEST_COUNT=$((TEST_COUNT + 1))
	if [[ "$condition" == "true" ]]; then
		echo -e "${GREEN}  ✓ $test_name${NC}"
		PASS_COUNT=$((PASS_COUNT + 1))
		return 0
	fi
	echo -e "${RED}  ✗ $test_name${NC}"
	[[ -n "$detail" ]] && echo -e "${RED}    $detail${NC}"
	FAIL_COUNT=$((FAIL_COUNT + 1))
	return 1
}

# Print the body of a top-level function from the connector
function_body() {
	sed -n "/^$1() {/,/^}/p" "$CONNECTOR"
}

# Extract the BACKOFF_INTERVALS values from the monitor function
backoff_intervals() {
	function_body "$MONITOR_FN" | sed -n 's/.*BACKOFF_INTERVALS=(\([0-9 ]*\)).*/\1/p' | head -1
}

echo "========================================"
echo "Exponential Backoff Optimization Tests"
echo "Issue #62: faster connection establishment"
echo "========================================"

# Test 1: intervals are defined, start fast and never decrease
echo -e "\n${YELLOW}Testing Exponential Backoff Configuration${NC}"

test_backoff_shape() {
	local intervals
	intervals=$(backoff_intervals)
	if [[ -z "$intervals" ]]; then
		assert_true "false" "Backoff intervals defined in $MONITOR_FN"
		return
	fi
	assert_true "true" "Backoff intervals defined in $MONITOR_FN ($intervals)"

	local -a values
	read -ra values <<< "$intervals"
	local prev=0 ok="true" v
	for v in "${values[@]}"; do
		[[ $v -ge $prev ]] || ok="false"
		prev=$v
	done
	assert_true "$ok" "Intervals never decrease (backoff, not fixed polling)" "got: $intervals"
	assert_true "$([[ ${values[0]} -le 1 ]] && echo true || echo false)" \
		"First check happens within 1s (fast connects are detected quickly)" "first interval: ${values[0]}"
}

test_backoff_shape

# Test 2: total wait per attempt stays within budget
echo -e "\n${YELLOW}Testing Total Wait Time Budget${NC}"

test_total_backoff_time() {
	local intervals total=0 v
	intervals=$(backoff_intervals)
	for v in $intervals; do
		total=$((total + v))
	done
	assert_true "$([[ $total -gt 0 && $total -le $MAX_TOTAL_WAIT ]] && echo true || echo false)" \
		"Total wait per attempt is ${total}s (budget: ${MAX_TOTAL_WAIT}s)" "total: ${total}s"
}

test_total_backoff_time

# Test 3: the monitor loop sleeps through the intervals and is used by connect
echo -e "\n${YELLOW}Testing Backoff Integration in Connection Loop${NC}"

test_backoff_in_connection_loop() {
	local body
	body=$(function_body "$MONITOR_FN")
	assert_true "$(grep -q 'for interval in "\${BACKOFF_INTERVALS\[@\]}"' <<< "$body" && echo true || echo false)" \
		"Monitor loop iterates over BACKOFF_INTERVALS"
	assert_true "$(grep -q 'sleep "\$interval"' <<< "$body" && echo true || echo false)" \
		"Monitor loop sleeps for the current interval"
	assert_true "$(function_body connect_openvpn_profile | grep -q "$MONITOR_FN" && echo true || echo false)" \
		"connect_openvpn_profile uses $MONITOR_FN"
}

test_backoff_in_connection_loop

# Test 4: success/progress markers from the OpenVPN log are still checked
echo -e "\n${YELLOW}Testing Early Break Markers${NC}"

test_early_break_markers() {
	local body
	body=$(function_body check_connection_progress)
	assert_true "$(grep -q 'Initialization Sequence Completed' <<< "$body" && echo true || echo false)" \
		"Connected marker (Initialization Sequence Completed) checked"
	assert_true "$(grep -q 'Peer Connection Initiated' <<< "$body" && echo true || echo false)" \
		"Peer connection marker checked"
}

test_early_break_markers

# Test 5: behavioural - loop returns as soon as the connection is established
echo -e "\n${YELLOW}Testing Early Break Behaviour${NC}"

test_early_break_behaviour() {
	local work result
	work=$(mktemp -d)
	mkdir -p "$work/run" && chmod 700 "$work/run"
	result=$(
		export HOME="$work" XDG_RUNTIME_DIR="$work/run" XDG_STATE_HOME="$work/state" VPN_LOG_DIR="$work/state/vpn"
		# shellcheck disable=SC1090
		source "$CONNECTOR" > /dev/null 2>&1
		set +e
		sleeps=0
		sleep() { sleeps=$((sleeps + 1)); }
		check_authentication_failure() { return 0; }
		announce_connection_status() { :; }
		detect_accessibility_mode() { return 0; }
		# Report "connected" on the 3rd check
		check_connection_progress() {
			if [[ $sleeps -ge 3 ]]; then echo connected; else echo in_progress; fi
		}
		"$MONITOR_FN" "test-profile" > /dev/null 2>&1
		echo "rc=$? sleeps=$sleeps"
	)
	rm -rf "$work"
	assert_equals "rc=0 sleeps=3" "$result" "Returns success right after the connection is up (no full wait)"
}

test_early_break_behaviour

# Test 6: no fixed sleep in the monitor loop
echo -e "\n${YELLOW}Testing Removal of Fixed Sleep Intervals${NC}"

test_no_fixed_sleep() {
	local fixed
	fixed=$(function_body "$MONITOR_FN" | grep -cE '^[[:space:]]*sleep [0-9]+' || true)
	assert_equals "0" "${fixed:-0}" "No fixed 'sleep N' in $MONITOR_FN"
}

test_no_fixed_sleep

# Test 7: documentation
echo -e "\n${YELLOW}Testing Documentation${NC}"

test_optimization_documented() {
	assert_true "$(grep -qi 'exponential.*backoff\|backoff.*exponential' "$CONNECTOR" && echo true || echo false)" \
		"Exponential backoff optimization is documented in code"
}

test_optimization_documented

# Test Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total tests run:    $TEST_COUNT"
echo "Tests passed:       $PASS_COUNT"
echo "Tests failed:       $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
	echo -e "${GREEN}All tests passed!${NC}"
	exit 0
else
	echo -e "${RED}Some tests failed.${NC}"
	exit 1
fi

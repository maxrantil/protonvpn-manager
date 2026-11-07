#!/bin/bash
# ABOUTME: Unit tests for the connection monitor (originally Issue #62 backoff)
# ABOUTME: Checks fast log polling, the timeout budget and early return on success

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$(cd "$SCRIPT_DIR/../../src" && pwd)"
CONNECTOR="$VPN_DIR/vpn-connector"
MONITOR_FN="monitor_connection_establishment_with_backoff"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# A single connection attempt must not wait longer than this by default
MAX_DEFAULT_TIMEOUT=40

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_equals() {
	local expected="$1" actual="$2" test_name="$3"
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
	local condition="$1" test_name="$2" detail="${3:-}"
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

function_body() {
	sed -n "/^$1() {/,/^}/p" "$CONNECTOR"
}

# Run the monitor with stubbed sleep/progress; prints "rc=<n> sleeps=<n>"
# Args: $1 = poll number at which the tunnel reports connected (0 = never),
#       $2 = CONNECT_TIMEOUT config value (optional)
run_monitor() {
	local connect_at="$1" timeout_value="${2:-}" work result
	work=$(mktemp -d)
	mkdir -p "$work/run" "$work/home/.config/vpn" && chmod 700 "$work/run"
	[[ -n $timeout_value ]] && echo "CONNECT_TIMEOUT=$timeout_value" > "$work/home/.config/vpn/config"
	result=$(
		export HOME="$work/home" XDG_RUNTIME_DIR="$work/run" XDG_STATE_HOME="$work/state" VPN_LOG_DIR="$work/state/vpn"
		# shellcheck disable=SC1090
		source "$CONNECTOR" > /dev/null 2>&1
		set +e
		sleeps=0
		sleep() { sleeps=$((sleeps + 1)); }
		check_authentication_failure() { return 0; }
		announce_connection_status() { :; }
		detect_accessibility_mode() { return 0; }
		check_connection_progress() {
			if [[ $connect_at -gt 0 && $sleeps -ge $connect_at ]]; then echo connected; else echo in_progress; fi
		}
		"$MONITOR_FN" "test-profile" > /dev/null 2>&1
		echo "rc=$? sleeps=$sleeps"
	)
	rm -rf "$work"
	echo "$result"
}

echo "========================================"
echo "Connection Monitor Tests"
echo "Fast log polling within a fixed time budget"
echo "========================================"

echo -e "\n${YELLOW}Testing Poll Interval${NC}"
test_poll_interval() {
	local body interval
	body=$(function_body "$MONITOR_FN")
	interval=$(sed -n 's/.*local poll_interval=\([0-9.]*\).*/\1/p' <<< "$body" | head -1)
	assert_true "$([[ -n $interval ]] && awk -v i="$interval" 'BEGIN { exit !(i > 0 && i <= 0.5) }' && echo true || echo false)" \
		"Log is polled at least twice per second (poll_interval=${interval:-unset})"
	assert_true "$(grep -q 'sleep "\$poll_interval"' <<< "$body" && echo true || echo false)" \
		"Monitor sleeps for the poll interval"
	assert_true "$(function_body connect_openvpn_profile | grep -q "$MONITOR_FN" && echo true || echo false)" \
		"connect_openvpn_profile uses $MONITOR_FN"
}
test_poll_interval

echo -e "\n${YELLOW}Testing Timeout Budget${NC}"
test_timeout_budget() {
	local default
	default=$(function_body "$MONITOR_FN" | sed -n 's/.*connector_config_value CONNECT_TIMEOUT \([0-9]*\).*/\1/p' | head -1)
	assert_true "$([[ -n $default && $default -le $MAX_DEFAULT_TIMEOUT ]] && echo true || echo false)" \
		"Default timeout ${default:-unset}s is within ${MAX_DEFAULT_TIMEOUT}s"

	# 5s at 4 polls/second = 20 polls, then timeout (rc 2)
	assert_equals "rc=2 sleeps=20" "$(run_monitor 0 5)" "CONNECT_TIMEOUT=5 gives up after 5s with a timeout"
	# Invalid values fall back to the default (35s = 140 polls)
	assert_equals "rc=2 sleeps=140" "$(run_monitor 0 abc)" "Invalid CONNECT_TIMEOUT falls back to the default"
	assert_equals "rc=2 sleeps=140" "$(run_monitor 0 0)" "CONNECT_TIMEOUT=0 falls back to the default"
}
test_timeout_budget

echo -e "\n${YELLOW}Testing Early Return${NC}"
test_early_return() {
	assert_equals "rc=0 sleeps=3" "$(run_monitor 3)" "Returns success right after the tunnel is up (no full wait)"
}
test_early_return

echo -e "\n${YELLOW}Testing Log Markers${NC}"
test_log_markers() {
	local body
	body=$(function_body check_connection_progress)
	assert_true "$(grep -q 'Initialization Sequence Completed' <<< "$body" && echo true || echo false)" \
		"Connected marker (Initialization Sequence Completed) checked"
	assert_true "$(grep -q 'Peer Connection Initiated' <<< "$body" && echo true || echo false)" \
		"Peer connection marker checked"
}
test_log_markers

echo -e "\n${YELLOW}Testing Removal of Fixed Sleep Intervals${NC}"
test_no_fixed_sleep() {
	local fixed
	fixed=$(function_body "$MONITOR_FN" | grep -cE '^[[:space:]]*sleep [0-9]+' || true)
	assert_equals "0" "${fixed:-0}" "No fixed 'sleep N' in $MONITOR_FN"
}
test_no_fixed_sleep

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

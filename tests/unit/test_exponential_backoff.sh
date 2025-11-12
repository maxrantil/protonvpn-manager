#!/bin/bash
# ABOUTME: Unit tests for exponential backoff connection optimization (Issue #62)

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$(cd "$SCRIPT_DIR/../../src" && pwd)"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helpers
assert_equals() {
	local expected="$1"
	local actual="$2"
	local test_name="$3"

	((TEST_COUNT++))
	if [[ "$expected" == "$actual" ]]; then
		echo -e "${GREEN}  ✓ $test_name${NC}"
		((PASS_COUNT++))
		return 0
	else
		echo -e "${RED}  ✗ $test_name${NC}"
		echo -e "${RED}    Expected: $expected${NC}"
		echo -e "${RED}    Got: $actual${NC}"
		((FAIL_COUNT++))
		return 1
	fi
}

assert_true() {
	local condition="$1"
	local test_name="$2"

	((TEST_COUNT++))
	if [[ "$condition" == "true" ]]; then
		echo -e "${GREEN}  ✓ $test_name${NC}"
		((PASS_COUNT++))
		return 0
	else
		echo -e "${RED}  ✗ $test_name${NC}"
		((FAIL_COUNT++))
		return 1
	fi
}

echo "========================================"
echo "Exponential Backoff Optimization Tests"
echo "Issue #62: 40% faster connection establishment"
echo "========================================"

# Test 1: Verify exponential backoff intervals are defined
echo -e "\n${YELLOW}Testing Exponential Backoff Configuration${NC}"

test_backoff_intervals_defined() {
	# Source the vpn-connector to check if backoff array exists
	# This test will fail initially (TDD RED phase)
	if grep -q "BACKOFF_INTERVALS" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		local intervals
		intervals=$(grep "BACKOFF_INTERVALS=" "$VPN_DIR/vpn-connector" | head -1)

		if [[ "$intervals" == *"1 1 2 2 3 4 5 6"* ]] || [[ "$intervals" == *"1,1,2,2,3,4,5,6"* ]]; then
			assert_true "true" "Backoff intervals array defined with correct values [1,1,2,2,3,4,5,6]"
		else
			assert_true "false" "Backoff intervals array defined with correct values [1,1,2,2,3,4,5,6]"
		fi
	else
		assert_true "false" "Backoff intervals array defined"
	fi
}

test_backoff_intervals_defined || true

# Test 2: Verify total backoff time is reduced
echo -e "\n${YELLOW}Testing Total Wait Time Reduction${NC}"

test_total_backoff_time() {
	# Expected: 1+1+2+2+3+4+5+6 = 24 seconds (vs old: 3×4 + 8×4 = 44 seconds)
	# Reduction: (44-24)/44 = 45% improvement

	# Check if code uses the new backoff timing by looking for the backoff loop
	if grep -A 20 "Establishing connection" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q 'for interval in.*BACKOFF_INTERVALS'; then
		# Using new intervals with exponential backoff
		assert_true "true" "Connection loop uses exponential backoff instead of fixed sleep 4"
	else
		# Still using old approach
		assert_true "false" "Connection loop uses exponential backoff instead of fixed sleep 4"
	fi
}

test_total_backoff_time || true

# Test 3: Verify backoff is used in connection establishment
echo -e "\n${YELLOW}Testing Backoff Integration in Connection Loop${NC}"

test_backoff_in_connection_loop() {
	# Check if the connection loop uses the backoff intervals
	local uses_backoff="false"

	if grep "connect_openvpn_profile" "$VPN_DIR/vpn-connector" -A 80 2>/dev/null | grep -q "BACKOFF_INTERVALS"; then
		uses_backoff="true"
	fi

	assert_equals "true" "$uses_backoff" "Connection establishment uses exponential backoff"
}

test_backoff_in_connection_loop || true

# Test 4: Verify early break logic is preserved
echo -e "\n${YELLOW}Testing Early Break Optimization${NC}"

test_early_break_preserved() {
	# Ensure the optimization doesn't remove early-break logic
	local has_peer_connection_check="false"
	local has_connected_check="false"

	if grep -q "Peer Connection Initiated" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		has_peer_connection_check="true"
	fi

	if grep -q "CONNECTED" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		has_connected_check="true"
	fi

	assert_equals "true" "$has_peer_connection_check" "Peer connection check preserved (early break)" || true
	assert_equals "true" "$has_connected_check" "Connected status check preserved (early break)" || true
}

test_early_break_preserved

# Test 5: Verify no fixed sleep 4 in connection loops
echo -e "\n${YELLOW}Testing Removal of Fixed Sleep Intervals${NC}"

test_no_fixed_sleep_4() {
	# Count occurrences of 'sleep 4' in connection establishment section
	local conn_section_start
	local conn_section_end

	conn_section_start=$(grep -n "Establishing connection" "$VPN_DIR/vpn-connector" 2>/dev/null | head -1 | cut -d: -f1)
	conn_section_end=$(grep -n "connection_established=1" "$VPN_DIR/vpn-connector" 2>/dev/null | head -1 | cut -d: -f1)

	if [[ -n "$conn_section_start" ]] && [[ -n "$conn_section_end" ]]; then
		local sleep_4_count
		sleep_4_count=$(sed -n "${conn_section_start},${conn_section_end}p" "$VPN_DIR/vpn-connector" | grep -c "sleep 4" 2>/dev/null || true)
		[[ -z "$sleep_4_count" ]] && sleep_4_count=0

		# Should be 0 after optimization (using sleep "$interval" instead)
		assert_equals "0" "$sleep_4_count" "No fixed 'sleep 4' in connection establishment section"
	else
		assert_true "false" "Could not locate connection establishment section"
	fi
}

test_no_fixed_sleep_4 || true

# Test 6: Verify documentation/comments explain the optimization
echo -e "\n${YELLOW}Testing Documentation${NC}"

test_optimization_documented() {
	# Check if there's a comment explaining the exponential backoff
	if grep -i "exponential.*backoff\|backoff.*exponential" "$VPN_DIR/vpn-connector" >/dev/null 2>&1; then
		assert_true "true" "Exponential backoff optimization is documented in code"
	else
		assert_true "false" "Exponential backoff optimization is documented in code"
	fi
}

test_optimization_documented || true

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

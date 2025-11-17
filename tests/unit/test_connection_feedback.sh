#!/bin/bash
# ABOUTME: Unit tests for progressive connection feedback (Issue #69)

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
echo "Progressive Connection Feedback Tests"
echo "Issue #69: Improve connection feedback"
echo "========================================"

# Test 1: Verify "Initializing" stage exists
echo -e "\n${YELLOW}Testing Progressive Feedback Stages${NC}"

test_initializing_stage() {
	# Check if vpn-connector shows "Initializing" message
	if grep -q "Initializing" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		assert_true "true" "Shows 'Initializing' stage during connection setup"
	else
		assert_true "false" "Shows 'Initializing' stage during connection setup"
	fi
}

test_initializing_stage || true

# Test 2: Verify "Establishing" stage exists
test_establishing_stage() {
	# Check if vpn-connector shows "Establishing" message
	if grep -q "Establishing" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		assert_true "true" "Shows 'Establishing' stage during TLS handshake"
	else
		assert_true "false" "Shows 'Establishing' stage during TLS handshake"
	fi
}

test_establishing_stage || true

# Test 3: Verify "Configuring" stage exists
test_configuring_stage() {
	# Check if vpn-connector shows "Configuring" message
	if grep -q "Configuring" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		assert_true "true" "Shows 'Configuring' stage when peer connection initiated"
	else
		assert_true "false" "Shows 'Configuring' stage when peer connection initiated"
	fi
}

test_configuring_stage || true

# Test 4: Verify "Verifying" stage exists
test_verifying_stage() {
	# Check if vpn-connector shows "Verifying" message
	if grep -q "Verifying" "$VPN_DIR/vpn-connector" 2>/dev/null; then
		assert_true "true" "Shows 'Verifying' stage during status check"
	else
		assert_true "false" "Shows 'Verifying' stage during status check"
	fi
}

test_verifying_stage || true

# Test 5: Verify stages appear in correct order
test_stage_ordering() {
	# Extract all stage messages and verify ordering
	local stages
	stages=$(grep -E "(Initializing|Establishing|Configuring|Verifying)" "$VPN_DIR/vpn-connector" 2>/dev/null || echo "")

	if [[ -z "$stages" ]]; then
		assert_true "false" "Progressive stages appear in logical order"
		return 1
	fi

	# Check if stages appear in logical order (line numbers should increase)
	local init_line establish_line config_line verify_line
	init_line=$(grep -n "Initializing" "$VPN_DIR/vpn-connector" 2>/dev/null | head -1 | cut -d: -f1)
	establish_line=$(grep -n "Establishing" "$VPN_DIR/vpn-connector" 2>/dev/null | head -1 | cut -d: -f1)

	if [[ -n "$init_line" && -n "$establish_line" ]]; then
		if [[ $init_line -lt $establish_line ]]; then
			assert_true "true" "Progressive stages appear in logical order"
		else
			assert_true "false" "Progressive stages appear in logical order"
		fi
	else
		assert_true "false" "Progressive stages appear in logical order"
	fi
}

test_stage_ordering || true

# Test 6: Verify visual indicators (spinner or progress)
test_visual_indicators() {
	# Check if code uses visual feedback during stages
	local code_section
	code_section=$(grep -A 50 "Establishing connection" "$VPN_DIR/vpn-connector" 2>/dev/null || echo "")

	# Should have some form of progress indicator (dots, spinner, etc.)
	if [[ "$code_section" == *"echo -n"* ]] || [[ "$code_section" == *"\r"* ]]; then
		assert_true "true" "Uses visual progress indicators during connection stages"
	else
		# No visual indicators found - test will fail initially
		assert_true "false" "Uses visual progress indicators during connection stages"
	fi
}

test_visual_indicators || true

# Test 7: Verify minimal feedback is replaced
test_minimal_feedback_replaced() {
	# Old implementation just showed dots "."
	# New should show stage names instead
	local connection_loop
	connection_loop=$(grep -A 30 "for interval in" "$VPN_DIR/vpn-connector" 2>/dev/null || echo "")

	# Check if we're using stage-based feedback instead of just dots
	if [[ "$connection_loop" == *"Establishing"* ]] || [[ "$connection_loop" == *"Configuring"* ]]; then
		assert_true "true" "Replaces minimal dot feedback with stage descriptions"
	else
		assert_true "false" "Replaces minimal dot feedback with stage descriptions"
	fi
}

test_minimal_feedback_replaced || true

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total tests: $TEST_COUNT"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo "========================================"

# Exit with failure if any tests failed
if [[ $FAIL_COUNT -gt 0 ]]; then
	exit 1
else
	exit 0
fi

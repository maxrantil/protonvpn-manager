#!/bin/bash
# ABOUTME: Phase 4.3 Intelligent Server Selection Integration - TDD Tests
# ABOUTME: Tests for integration between vpn-connector and performance testing

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"
readonly BEST_VPN_PROFILE_PATH="$PROJECT_DIR/src/best-vpn-profile"

test_vpn_connector_has_best_command() {
	start_test "vpn-connector has best command in help"

	if [[ ! -f "$VPN_CONNECTOR_PATH" ]]; then
		log_test "SKIP" "$CURRENT_TEST: vpn-connector not found"
		return
	fi

	local help_output
	help_output=$("$VPN_CONNECTOR_PATH" help 2>/dev/null || true)

	if echo "$help_output" | grep -q "best.*Find and connect to best"; then
		log_test "PASS" "$CURRENT_TEST"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: 'best' command not found in help"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_vpn_connector_calls_best_vpn_profile() {
	start_test "vpn-connector integrates with best-vpn-profile script"

	if [[ ! -f "$VPN_CONNECTOR_PATH" ]]; then
		log_test "SKIP" "$CURRENT_TEST: vpn-connector not found"
		return
	fi

	if [[ ! -f "$BEST_VPN_PROFILE_PATH" ]]; then
		log_test "SKIP" "$CURRENT_TEST: best-vpn-profile not found"
		return
	fi

	# Check that vpn-connector references best-vpn-profile
	if grep -q "best-vpn-profile" "$VPN_CONNECTOR_PATH"; then
		log_test "PASS" "$CURRENT_TEST"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: vpn-connector should reference best-vpn-profile script"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_country_prioritization_exists() {
	start_test "best-vpn-profile supports country prioritization"

	if [[ ! -f "$BEST_VPN_PROFILE_PATH" ]]; then
		log_test "SKIP" "$CURRENT_TEST: best-vpn-profile not found"
		return
	fi

	# Test that best command accepts country parameter
	local result1 result2
	result1=$("$BEST_VPN_PROFILE_PATH" best 2>/dev/null || echo "failed")
	result2=$("$BEST_VPN_PROFILE_PATH" best SE 2>/dev/null || echo "failed")

	if [[ "$result1" != "failed" ]] && [[ "$result2" != "failed" ]]; then
		log_test "PASS" "$CURRENT_TEST: accepts country parameter"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: should accept country parameter"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

# Run Phase 4.3 tests
main() {
	log_test "INFO" "Starting Phase 4.3 Intelligent Server Selection Tests (TDD RED phase)"

	# These tests should FAIL initially (RED phase)
	test_vpn_connector_has_best_command
	test_vpn_connector_calls_best_vpn_profile
	test_country_prioritization_exists

	show_test_summary

	# Exit with failure if any tests failed (expected in RED phase)
	if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
		exit 1
	else
		exit 0
	fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main
fi

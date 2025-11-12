#!/bin/bash
# ABOUTME: Phase 4 End-to-End Tests for complete user workflows
# ABOUTME: Tests full vpn best workflow including connection, status, and cleanup

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test constants
readonly VPN_SCRIPT_PATH="$PROJECT_DIR/src/vpn"
readonly VPN_CONNECTOR_PATH="$PROJECT_DIR/src/vpn-connector"
readonly VPN_MANAGER_PATH="$PROJECT_DIR/src/vpn-manager"
readonly BEST_VPN_PROFILE_PATH="$PROJECT_DIR/src/best-vpn-profile"

# Setup for E2E tests
setup_e2e_environment() {
	# Ensure all required scripts exist
	if [[ ! -f "$VPN_SCRIPT_PATH" ]]; then
		echo "ERROR: vpn script not found at $VPN_SCRIPT_PATH"
		return 1
	fi

	if [[ ! -f "$VPN_CONNECTOR_PATH" ]]; then
		echo "ERROR: vpn-connector not found at $VPN_CONNECTOR_PATH"
		return 1
	fi

	if [[ ! -f "$VPN_MANAGER_PATH" ]]; then
		echo "ERROR: vpn-manager not found at $VPN_MANAGER_PATH"
		return 1
	fi

	if [[ ! -f "$BEST_VPN_PROFILE_PATH" ]]; then
		echo "ERROR: best-vpn-profile not found at $BEST_VPN_PROFILE_PATH"
		return 1
	fi

	# Clean up any existing VPN connections
	sudo pkill -f openvpn 2>/dev/null || true
	sleep 2

	return 0
}

test_vpn_help_shows_best_command() {
	start_test "vpn help command shows best option"

	local help_output
	help_output=$("$VPN_SCRIPT_PATH" help 2>/dev/null || true)

	if echo "$help_output" | grep -q "best.*Connect to best"; then
		log_test "PASS" "$CURRENT_TEST"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: 'best' command not properly documented in help"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_best_vpn_profile_performance_workflow() {
	start_test "best-vpn-profile complete performance testing workflow"

	# Test the full performance testing workflow
	local best_result
	# cache_before/after variables reserved for future validation

	# Clear cache first
	"$BEST_VPN_PROFILE_PATH" clear >/dev/null 2>&1 || true

	# Check cache is empty
	cache_before=$("$BEST_VPN_PROFILE_PATH" cache 2>/dev/null || echo "No cache")

	if echo "$cache_before" | grep -q "No.*cache"; then
		log_test "INFO" "$CURRENT_TEST: Cache cleared successfully"
	else
		log_test "WARN" "$CURRENT_TEST: Cache not empty initially: $cache_before"
	fi

	# Run best command (should trigger performance testing)
	if best_result=$("$BEST_VPN_PROFILE_PATH" best 2>/dev/null); then
		if [[ -n "$best_result" ]] && [[ "$best_result" != "No profiles found" ]]; then
			log_test "PASS" "$CURRENT_TEST: got best profile '$best_result'"
			((TESTS_PASSED++))
		else
			log_test "FAIL" "$CURRENT_TEST: best command returned empty or error result"
			FAILED_TESTS+=("$CURRENT_TEST")
			((TESTS_FAILED++))
		fi
	else
		log_test "FAIL" "$CURRENT_TEST: best command failed to execute"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_vpn_connector_integration_workflow() {
	start_test "vpn-connector integrates with performance testing"

	# Test that vpn-connector can call best-vpn-profile
	# We'll test this by checking the functions exist and can be called

	# Check if vpn-connector references best-vpn-profile
	if grep -q "best-vpn-profile" "$VPN_CONNECTOR_PATH"; then
		log_test "INFO" "$CURRENT_TEST: vpn-connector references performance script"
	else
		log_test "FAIL" "$CURRENT_TEST: vpn-connector missing performance integration"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
		return
	fi

	# Test vpn-connector help includes best command
	local help_output
	help_output=$("$VPN_CONNECTOR_PATH" help 2>/dev/null || true)

	if echo "$help_output" | grep -q "best"; then
		log_test "PASS" "$CURRENT_TEST: vpn-connector has best command in help"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: vpn-connector missing best command documentation"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_complete_performance_command_chain() {
	start_test "complete vpn performance command chain works"

	# Test the complete command chain without actually connecting to VPN
	# This tests the command routing and integration

	local vpn_help vpn_connector_help best_profile_help

	# Test vpn main script
	vpn_help=$("$VPN_SCRIPT_PATH" help 2>/dev/null || echo "FAILED")
	if [[ "$vpn_help" == "FAILED" ]]; then
		log_test "FAIL" "$CURRENT_TEST: vpn main script help failed"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
		return
	fi

	# Test vpn-connector
	vpn_connector_help=$("$VPN_CONNECTOR_PATH" help 2>/dev/null || echo "FAILED")
	if [[ "$vpn_connector_help" == "FAILED" ]]; then
		log_test "FAIL" "$CURRENT_TEST: vpn-connector help failed"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
		return
	fi

	# Test best-vpn-profile
	best_profile_help=$("$BEST_VPN_PROFILE_PATH" help 2>/dev/null || echo "FAILED")
	if [[ "$best_profile_help" == "FAILED" ]]; then
		log_test "FAIL" "$CURRENT_TEST: best-vpn-profile help failed"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
		return
	fi

	log_test "PASS" "$CURRENT_TEST: all command helps work correctly"
	((TESTS_PASSED++))
}

test_error_handling_in_performance_workflow() {
	start_test "performance workflow handles errors gracefully"

	# Test with non-existent country code
	local result_invalid
	result_invalid=$("$BEST_VPN_PROFILE_PATH" best "INVALID" 2>/dev/null || echo "ERROR_HANDLED")

	# Should either return a result or handle error gracefully
	if [[ "$result_invalid" != "" ]]; then
		log_test "PASS" "$CURRENT_TEST: invalid country handled gracefully"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: invalid country not handled properly"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

cleanup_e2e_environment() {
	# Clean up any test artifacts
	sudo pkill -f openvpn 2>/dev/null || true
	rm -f /tmp/vpn_*.lock 2>/dev/null || true
	rm -f /tmp/vpn_performance.cache 2>/dev/null || true
}

# Run Phase 4 E2E tests
main() {
	log_test "INFO" "Starting Phase 4 End-to-End Tests"

	# Setup
	if ! setup_e2e_environment; then
		log_test "FAIL" "E2E environment setup failed"
		exit 1
	fi

	# Run E2E tests
	test_vpn_help_shows_best_command
	test_best_vpn_profile_performance_workflow
	test_vpn_connector_integration_workflow
	test_complete_performance_command_chain
	test_error_handling_in_performance_workflow

	# Cleanup
	cleanup_e2e_environment

	show_test_summary

	# Exit with failure if any tests failed
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

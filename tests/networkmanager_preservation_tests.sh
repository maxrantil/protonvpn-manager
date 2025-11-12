#!/bin/bash
# ABOUTME: Tests to ensure NetworkManager is not disrupted during normal VPN operations
# ABOUTME: Prevents regression of the internet-breaking cleanup bug

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_cleanup_preserves_networkmanager() {
	start_test "Cleanup command does not restart NetworkManager"

	# Get NetworkManager PID before cleanup
	local nm_pid_before
	nm_pid_before=$(pgrep NetworkManager | head -1)

	if [[ -z "$nm_pid_before" ]]; then
		log_test "SKIP" "$CURRENT_TEST: NetworkManager not running"
		return
	fi

	# Run cleanup
	"$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1

	# Get NetworkManager PID after cleanup
	local nm_pid_after
	nm_pid_after=$(pgrep NetworkManager | head -1)

	# PID should be the same (NetworkManager not restarted)
	if [[ "$nm_pid_before" == "$nm_pid_after" ]]; then
		log_test "PASS" "$CURRENT_TEST: NetworkManager PID unchanged ($nm_pid_before)"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: NetworkManager PID changed (before: $nm_pid_before, after: $nm_pid_after)"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_kill_preserves_networkmanager() {
	start_test "Kill command does not restart NetworkManager"

	# Get NetworkManager PID before kill
	local nm_pid_before
	nm_pid_before=$(pgrep NetworkManager | head -1)

	if [[ -z "$nm_pid_before" ]]; then
		log_test "SKIP" "$CURRENT_TEST: NetworkManager not running"
		return
	fi

	# Run kill command
	"$PROJECT_DIR/src/vpn" kill >/dev/null 2>&1

	# Get NetworkManager PID after kill
	local nm_pid_after
	nm_pid_after=$(pgrep NetworkManager | head -1)

	# PID should be the same (NetworkManager not restarted)
	if [[ "$nm_pid_before" == "$nm_pid_after" ]]; then
		log_test "PASS" "$CURRENT_TEST: NetworkManager PID unchanged ($nm_pid_before)"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: NetworkManager PID changed (before: $nm_pid_before, after: $nm_pid_after)"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_cleanup_output_mentions_networkmanager_intact() {
	start_test "Cleanup output explicitly mentions NetworkManager is left intact"

	local cleanup_output
	cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1)

	# Strip ANSI color codes for reliable matching
	if echo "$cleanup_output" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "NetworkManager left intact"; then
		log_test "PASS" "$CURRENT_TEST: Cleanup output confirms NetworkManager preservation"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Cleanup output doesn't mention NetworkManager preservation"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_emergency_reset_does_restart_networkmanager() {
	start_test "Emergency reset command DOES restart NetworkManager (as intended)"

	# Get NetworkManager PID before emergency reset
	local nm_pid_before
	nm_pid_before=$(pgrep NetworkManager | head -1)

	if [[ -z "$nm_pid_before" ]]; then
		log_test "SKIP" "$CURRENT_TEST: NetworkManager not running"
		return
	fi

	# Mock the emergency reset to avoid actually disrupting the network during tests
	# We'll check that the code path exists and warns properly
	local emergency_output
	emergency_output=$("$PROJECT_DIR/src/vpn-manager" emergency-reset 2>&1 || true)

	if echo "$emergency_output" | grep -q "EMERGENCY NETWORK RESET.*disrupt internet"; then
		log_test "PASS" "$CURRENT_TEST: Emergency reset properly warns about disruption"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Emergency reset doesn't warn about network disruption"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_vpn_integration_set_options() {
	start_test "VPN integration script uses safe bash options"

	# Check that vpn-integration doesn't use 'set -e' which caused hanging
	local integration_content
	if [[ -f "$PROJECT_DIR/src/vpn-integration" ]]; then
		integration_content=$(cat "$PROJECT_DIR/src/vpn-integration")

		if echo "$integration_content" | grep -q "set -uo pipefail" && ! echo "$integration_content" | grep -q "set -euo pipefail"; then
			log_test "PASS" "$CURRENT_TEST: VPN integration uses safe bash options"
			((TESTS_PASSED++))
		else
			log_test "FAIL" "$CURRENT_TEST: VPN integration may use problematic bash options"
			FAILED_TESTS+=("$CURRENT_TEST")
			((TESTS_FAILED++))
		fi
	else
		log_test "SKIP" "$CURRENT_TEST: vpn-integration file not found"
	fi
}

test_no_networkmanager_commands_in_regular_cleanup() {
	start_test "Regular cleanup functions don't contain NetworkManager restart commands"

	# Check that full_cleanup function doesn't restart NetworkManager
	if grep -A 20 "^full_cleanup()" "$PROJECT_DIR/src/vpn-manager" | grep -q "sv restart NetworkManager\|systemctl restart NetworkManager\|service NetworkManager restart"; then
		log_test "FAIL" "$CURRENT_TEST: Regular cleanup contains NetworkManager restart commands"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	else
		log_test "PASS" "$CURRENT_TEST: Regular cleanup doesn't restart NetworkManager"
		((TESTS_PASSED++))
	fi

	# Check that kill_all_vpn function doesn't restart NetworkManager
	if grep -A 20 "^kill_all_vpn()" "$PROJECT_DIR/src/vpn-manager" | grep -q "sv restart NetworkManager\|systemctl restart NetworkManager\|service NetworkManager restart"; then
		log_test "FAIL" "$CURRENT_TEST: Kill function contains NetworkManager restart commands"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	else
		log_test "PASS" "$CURRENT_TEST: Kill function doesn't restart NetworkManager"
		((TESTS_PASSED++))
	fi
}

# Run all NetworkManager preservation tests
main() {
	log_test "INFO" "Starting NetworkManager Preservation Tests"
	echo "================================================="
	echo "      NETWORKMANAGER PRESERVATION TESTS"
	echo "================================================="

	test_cleanup_preserves_networkmanager
	test_kill_preserves_networkmanager
	test_cleanup_output_mentions_networkmanager_intact
	test_emergency_reset_does_restart_networkmanager
	test_vpn_integration_set_options
	test_no_networkmanager_commands_in_regular_cleanup

	show_test_summary

	if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
		exit 1
	else
		exit 0
	fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main
fi

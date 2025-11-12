#!/bin/bash
# ABOUTME: Simple regression tests to prevent the specific issues we fixed
# ABOUTME: Focuses on the critical fixes without complex test interference

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_cleanup_preserves_networkmanager() {
	start_test "Cleanup does not restart NetworkManager"

	# Get NetworkManager PID before
	local nm_pid_before
	nm_pid_before=$(pgrep NetworkManager | head -1)

	if [[ -z "$nm_pid_before" ]]; then
		log_test "SKIP" "$CURRENT_TEST: NetworkManager not running"
		return
	fi

	# Run cleanup
	"$PROJECT_DIR/src/vpn" cleanup >/dev/null 2>&1

	# Check PID after
	local nm_pid_after
	nm_pid_after=$(pgrep NetworkManager | head -1)

	if [[ "$nm_pid_before" == "$nm_pid_after" ]]; then
		log_test "PASS" "$CURRENT_TEST: NetworkManager preserved (PID $nm_pid_before)"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: NetworkManager restarted (PID changed)"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_commands_complete_without_hanging() {
	start_test "VPN commands complete within reasonable time"

	local commands=("cleanup" "kill" "health" "status")
	local timeouts=(30 30 10 15)

	for _i in "${!commands[@]}"; do
		local cmd="${commands[$i]}"
		local timeout_val="${timeouts[$i]}"

		if timeout "${timeout_val}s" "$PROJECT_DIR/src/vpn" "$cmd" >/dev/null 2>&1; then
			log_test "PASS" "$CURRENT_TEST: '$cmd' completed within ${timeout_val}s"
			((TESTS_PASSED++))
		else
			log_test "FAIL" "$CURRENT_TEST: '$cmd' timed out or failed"
			FAILED_TESTS+=("$CURRENT_TEST: $cmd")
			((TESTS_FAILED++))
		fi
	done
}

test_health_command_works() {
	start_test "Health command is accessible and works"

	# Test via main script
	local health_output
	health_output=$("$PROJECT_DIR/src/vpn" health 2>&1)
	local exit_code=$?

	if [[ $exit_code -eq 0 ]] && echo "$health_output" | grep -q "PROCESSES RUNNING"; then
		log_test "PASS" "$CURRENT_TEST: Health command works correctly"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Health command failed (exit: $exit_code)"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_emergency_reset_separate_from_cleanup() {
	start_test "Emergency reset is separate from regular cleanup"

	# Check help distinguishes them
	local help_output
	help_output=$("$PROJECT_DIR/src/vpn" help 2>&1)

	local has_cleanup has_emergency has_distinction
	has_cleanup=false
	has_emergency=false
	has_distinction=false

	if echo "$help_output" | grep -q "cleanup.*safe"; then
		has_cleanup=true
	fi

	if echo "$help_output" | grep -q "emergency-reset.*NetworkManager"; then
		has_emergency=true
	fi

	if [[ "$has_cleanup" == true && "$has_emergency" == true ]]; then
		has_distinction=true
	fi

	if [[ "$has_distinction" == true ]]; then
		log_test "PASS" "$CURRENT_TEST: Emergency reset properly separated from cleanup"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Commands not properly distinguished"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_process_pattern_specificity() {
	start_test "Process detection pattern is specific"

	# Test that the pattern in the code is the corrected one
	if grep -q "pgrep -f \"\\^openvpn.*--config\"" "$PROJECT_DIR/src/vpn-manager"; then
		log_test "PASS" "$CURRENT_TEST: Specific process pattern in use"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Old problematic pattern may still be in use"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

test_bash_options_safe() {
	start_test "VPN integration uses safe bash options"

	if [[ -f "$PROJECT_DIR/src/vpn-integration" ]]; then
		local integration_content
		integration_content=$(cat "$PROJECT_DIR/src/vpn-integration")

		# Should have 'set -uo pipefail' but NOT 'set -euo pipefail'
		if echo "$integration_content" | grep -q "set -uo pipefail" && ! echo "$integration_content" | grep -q "set -euo pipefail"; then
			log_test "PASS" "$CURRENT_TEST: Safe bash options in use"
			((TESTS_PASSED++))
		else
			log_test "FAIL" "$CURRENT_TEST: Unsafe bash options may cause hanging"
			FAILED_TESTS+=("$CURRENT_TEST")
			((TESTS_FAILED++))
		fi
	else
		log_test "SKIP" "$CURRENT_TEST: vpn-integration file not found"
	fi
}

test_cleanup_output_safety_message() {
	start_test "Cleanup output mentions NetworkManager safety"

	local cleanup_output
	cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1)

	if echo "$cleanup_output" | grep -q "NetworkManager left intact"; then
		log_test "PASS" "$CURRENT_TEST: Cleanup confirms NetworkManager safety"
		((TESTS_PASSED++))
	else
		log_test "FAIL" "$CURRENT_TEST: Cleanup doesn't mention NetworkManager safety"
		FAILED_TESTS+=("$CURRENT_TEST")
		((TESTS_FAILED++))
	fi
}

# Run all simple regression tests
main() {
	log_test "INFO" "Starting Simple Regression Prevention Tests"
	echo "================================================="
	echo "      SIMPLE REGRESSION PREVENTION TESTS"
	echo "================================================="
	echo "Verifying fixes for the critical issues:"
	echo "  ✓ NetworkManager preservation during cleanup"
	echo "  ✓ Commands completing without hanging"
	echo "  ✓ Health command functionality"
	echo "  ✓ Emergency reset vs cleanup separation"
	echo "  ✓ Specific process detection patterns"
	echo "  ✓ Safe bash options to prevent hanging"
	echo "================================================="

	test_cleanup_preserves_networkmanager
	test_commands_complete_without_hanging
	test_health_command_works
	test_emergency_reset_separate_from_cleanup
	test_process_pattern_specificity
	test_bash_options_safe
	test_cleanup_output_safety_message

	show_test_summary

	if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
		echo
		echo "⚠️  REGRESSION DETECTED! The following critical fixes may have regressed:"
		for failed_test in "${FAILED_TESTS[@]}"; do
			echo "   ✗ $failed_test"
		done
		exit 1
	else
		echo
		echo "✅ ALL REGRESSION PREVENTION TESTS PASSED"
		echo "The critical fixes are intact and working correctly."
		exit 0
	fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main
fi

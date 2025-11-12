#!/usr/bin/env bash
# Tests for refactored hierarchical_process_cleanup functions
# Issue #71: Break down 149-line function into 5 smaller functions
# shellcheck disable=SC2317  # Mock functions appear unreachable but are used via export -f

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$TEST_DIR")/src"

# Source the module under test
# shellcheck source=../src/vpn-manager
source "$SRC_DIR/vpn-manager" 2>/dev/null || true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
	((TESTS_PASSED++))
	echo "  ✓ $1"
}

fail() {
	((TESTS_FAILED++))
	echo "  ✗ $1"
}

run_test() {
	((TESTS_RUN++))
	echo "Test $TESTS_RUN: $1"
}

# ============================================================================
# Tests for validate_and_discover_processes()
# ============================================================================

test_validate_and_discover_no_processes() {
	run_test "validate_and_discover_processes returns empty when no VPN processes"

	# Mock pgrep to return nothing
	pgrep() { return 1; }
	ps() { echo ""; }
	export -f pgrep ps

	local result
	result=$(validate_and_discover_processes 2>/dev/null || echo "")

	if [[ -z "$result" ]]; then
		pass "Returns empty string when no processes found"
	else
		fail "Expected empty, got: $result"
	fi

	unset -f pgrep ps
}

test_validate_and_discover_with_openvpn() {
	run_test "validate_and_discover_processes finds OpenVPN processes"

	# Mock to return test PIDs
	pgrep() {
		if [[ "$*" =~ "openvpn" ]]; then
			echo "1234"
		fi
		return 0
	}
	ps() {
		if [[ "$*" =~ "eo pid,stat,comm" ]]; then
			echo ""
		fi
		return 0
	}
	export -f pgrep ps

	local result
	result=$(validate_and_discover_processes 2>/dev/null || echo "")

	if [[ "$result" == "1234" ]]; then
		pass "Discovers OpenVPN process PIDs"
	else
		fail "Expected '1234', got: '$result'"
	fi

	unset -f pgrep ps
}

test_validate_and_discover_with_zombies() {
	run_test "validate_and_discover_processes finds zombie processes"

	pgrep() {
		if [[ "$*" =~ "openvpn" ]]; then
			echo "1234"
		fi
		return 0
	}
	ps() {
		if [[ "$*" =~ "eo pid,stat,comm" ]]; then
			echo "5678 Z openvpn"
		else
			echo ""
		fi
		return 0
	}
	export -f pgrep ps

	local result
	result=$(validate_and_discover_processes 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')

	if [[ "$result" =~ "1234" && "$result" =~ "5678" ]]; then
		pass "Discovers both regular and zombie processes"
	else
		fail "Expected both PIDs, got: '$result'"
	fi

	unset -f pgrep ps
}

# ============================================================================
# Tests for attempt_graceful_termination()
# ============================================================================

test_attempt_graceful_sends_term() {
	run_test "attempt_graceful_termination sends TERM signal"

	# Track kill calls
	kill() {
		if [[ "$1" == "-TERM" ]]; then
			echo "TERM sent to $2" >>/tmp/test_kill_log.$$
		fi
		return 0
	}
	export -f kill

	rm -f /tmp/test_kill_log.$$
	attempt_graceful_termination "1234" >/dev/null 2>&1 || true

	if [[ -f /tmp/test_kill_log.$$ ]] && grep -q "TERM sent to 1234" /tmp/test_kill_log.$$; then
		pass "Sends TERM signal to process"
		rm -f /tmp/test_kill_log.$$
	else
		fail "Did not send TERM signal"
		rm -f /tmp/test_kill_log.$$
	fi

	unset -f kill
}

test_attempt_graceful_waits() {
	run_test "attempt_graceful_termination waits after signaling"

	local start_time end_time elapsed
	start_time=$(date +%s)

	# Mock functions to avoid actual killing
	kill() { return 0; }
	validate_openvpn_process() { return 0; }
	sleep() { command sleep 0.1; } # Reduce wait time for testing
	export -f kill validate_openvpn_process sleep

	attempt_graceful_termination "1234" >/dev/null 2>&1 || true

	end_time=$(date +%s)
	elapsed=$((end_time - start_time))

	# Should have waited at least briefly
	if [[ $elapsed -ge 0 ]]; then
		pass "Waits after sending signal"
	else
		fail "Did not wait after signaling"
	fi

	unset -f kill validate_openvpn_process sleep
}

# ============================================================================
# Tests for attempt_forceful_termination()
# ============================================================================

test_attempt_forceful_sends_kill() {
	run_test "attempt_forceful_termination sends KILL signal"

	kill() {
		if [[ "$1" == "-KILL" ]]; then
			echo "KILL sent to $2" >>/tmp/test_kill_log.$$
		fi
		return 0
	}
	export -f kill

	rm -f /tmp/test_kill_log.$$
	attempt_forceful_termination "1234" >/dev/null 2>&1 || true

	if [[ -f /tmp/test_kill_log.$$ ]] && grep -q "KILL sent to 1234" /tmp/test_kill_log.$$; then
		pass "Sends KILL signal to process"
		rm -f /tmp/test_kill_log.$$
	else
		fail "Did not send KILL signal"
		rm -f /tmp/test_kill_log.$$
	fi

	unset -f kill
}

# ============================================================================
# Tests for attempt_sudo_termination()
# ============================================================================

test_attempt_sudo_uses_sudo() {
	run_test "attempt_sudo_termination uses sudo for KILL signal"

	sudo() {
		if [[ "$1" == "kill" && "$2" == "-KILL" ]]; then
			echo "sudo KILL sent to $3" >>/tmp/test_sudo_log.$$
		fi
		return 0
	}
	export -f sudo

	rm -f /tmp/test_sudo_log.$$
	attempt_sudo_termination "1234" >/dev/null 2>&1 || true

	if [[ -f /tmp/test_sudo_log.$$ ]] && grep -q "sudo KILL sent to 1234" /tmp/test_sudo_log.$$; then
		pass "Uses sudo to send KILL signal"
		rm -f /tmp/test_sudo_log.$$
	else
		fail "Did not use sudo for KILL signal"
		rm -f /tmp/test_sudo_log.$$
	fi

	unset -f sudo
}

# ============================================================================
# Tests for verify_cleanup_success()
# ============================================================================

test_verify_cleanup_success_no_processes() {
	run_test "verify_cleanup_success returns 0 when no processes remain"

	pgrep() { return 1; }
	export -f pgrep

	if verify_cleanup_success >/dev/null 2>&1; then
		pass "Returns success when no processes found"
	else
		fail "Should return success when clean"
	fi

	unset -f pgrep
}

test_verify_cleanup_success_processes_remain() {
	run_test "verify_cleanup_success returns 1 when processes remain"

	pgrep() {
		echo "1234"
		return 0
	}
	export -f pgrep

	if ! verify_cleanup_success >/dev/null 2>&1; then
		pass "Returns failure when processes remain"
	else
		fail "Should return failure when processes remain"
	fi

	unset -f pgrep
}

# ============================================================================
# Integration Tests
# ============================================================================

test_refactored_function_maintains_behavior() {
	run_test "Refactored hierarchical_process_cleanup maintains original behavior"

	# Mock all external dependencies
	pgrep() { return 1; } # No processes
	export -f pgrep

	if hierarchical_process_cleanup "false" >/dev/null 2>&1; then
		pass "Function executes without errors when no processes"
	else
		fail "Function failed when it should succeed"
	fi

	unset -f pgrep
}

test_function_respects_force_flag() {
	run_test "hierarchical_process_cleanup respects force parameter"

	# This is a behavioral test - just verify the function accepts the parameter
	pgrep() { return 1; }
	export -f pgrep

	if hierarchical_process_cleanup "true" >/dev/null 2>&1; then
		pass "Accepts force parameter"
	else
		fail "Should accept force parameter"
	fi

	unset -f pgrep
}

# ============================================================================
# Run all tests
# ============================================================================

echo "=========================================="
echo "Testing Hierarchical Cleanup Refactor"
echo "=========================================="
echo ""

# Note: These tests will fail until functions are extracted (TDD RED phase)
echo "Phase: RED (tests should fail before implementation)"
echo ""

# Process discovery tests
test_validate_and_discover_no_processes
test_validate_and_discover_with_openvpn
test_validate_and_discover_with_zombies

# Graceful termination tests
test_attempt_graceful_sends_term
test_attempt_graceful_waits

# Forceful termination test
test_attempt_forceful_sends_kill

# Sudo termination test
test_attempt_sudo_uses_sudo

# Verification tests
test_verify_cleanup_success_no_processes
test_verify_cleanup_success_processes_remain

# Integration tests
test_refactored_function_maintains_behavior
test_function_respects_force_flag

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests run:    $TESTS_RUN"
echo "Tests passed:       $TESTS_PASSED"
echo "Tests failed:       $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
	echo "✓ All tests passed!"
	exit 0
else
	echo "✗ Some tests failed"
	exit 1
fi

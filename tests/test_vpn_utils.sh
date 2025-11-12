#!/bin/bash
# ABOUTME: Unit tests for shared VPN utility functions (src/vpn-utils)
# ABOUTME: Tests notify_event and log_message functions

set -euo pipefail

# Source the utilities to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/src/vpn-utils"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
	local expected="$1"
	local actual="$2"
	local test_name="$3"

	TESTS_RUN=$((TESTS_RUN + 1))

	if [[ "$expected" == "$actual" ]]; then
		echo "✓ PASS: $test_name"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "✗ FAIL: $test_name"
		echo "  Expected: $expected"
		echo "  Got: $actual"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

assert_contains() {
	local substring="$1"
	local text="$2"
	local test_name="$3"

	TESTS_RUN=$((TESTS_RUN + 1))

	if [[ "$text" == *"$substring"* ]]; then
		echo "✓ PASS: $test_name"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "✗ FAIL: $test_name"
		echo "  Expected substring: $substring"
		echo "  In text: $text"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

assert_file_exists() {
	local filepath="$1"
	local test_name="$2"

	TESTS_RUN=$((TESTS_RUN + 1))

	if [[ -f "$filepath" ]]; then
		echo "✓ PASS: $test_name"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "✗ FAIL: $test_name"
		echo "  File not found: $filepath"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

# Setup test environment
setup_test_env() {
	export TEST_LOG_FILE="/tmp/test_vpn_utils_$$.log"
	rm -f "$TEST_LOG_FILE"
}

teardown_test_env() {
	rm -f "$TEST_LOG_FILE"
}

# Test: notify_event with all parameters
test_notify_event_full() {
	local output
	output=$(notify_event "TEST_EVENT" "arg1" "arg2" 2>&1)
	assert_contains "[INFO] TEST_EVENT: arg1 arg2" "$output" "notify_event with 3 parameters"
}

# Test: notify_event with two parameters
test_notify_event_two_args() {
	local output
	output=$(notify_event "CONNECT" "server.ovpn" 2>&1)
	assert_contains "[INFO] CONNECT: server.ovpn" "$output" "notify_event with 2 parameters"
}

# Test: notify_event with one parameter
test_notify_event_one_arg() {
	local output
	output=$(notify_event "STATUS" 2>&1)
	assert_contains "[INFO] STATUS:" "$output" "notify_event with 1 parameter"
}

# Test: log_message creates log file
test_log_message_creates_file() {
	setup_test_env

	log_message "Test message" "$TEST_LOG_FILE"

	assert_file_exists "$TEST_LOG_FILE" "log_message creates log file"

	teardown_test_env
}

# Test: log_message formats correctly
test_log_message_format() {
	setup_test_env

	log_message "Test message" "$TEST_LOG_FILE"
	local content
	content=$(cat "$TEST_LOG_FILE")

	# Check for timestamp pattern [YYYY-MM-DD HH:MM:SS]
	assert_contains "[20" "$content" "log_message includes timestamp"
	assert_contains "Test message" "$content" "log_message includes message"

	teardown_test_env
}

# Test: log_message handles missing log file
test_log_message_fallback() {
	local output
	# Try to write to non-writable location (should fallback to stderr)
	output=$(log_message "Fallback test" "/root/impossible.log" 2>&1)

	assert_contains "Fallback test" "$output" "log_message fallback to stderr"
}

# Test: log_message appends to existing file
test_log_message_append() {
	setup_test_env

	log_message "First message" "$TEST_LOG_FILE"
	log_message "Second message" "$TEST_LOG_FILE"

	local line_count
	line_count=$(wc -l <"$TEST_LOG_FILE")

	assert_equals "2" "$line_count" "log_message appends to existing file"

	teardown_test_env
}

# Run all tests
echo "=================================="
echo "VPN Utils Test Suite"
echo "=================================="
echo

test_notify_event_full
test_notify_event_two_args
test_notify_event_one_arg
test_log_message_creates_file
test_log_message_format
test_log_message_fallback
test_log_message_append

# Summary
echo
echo "=================================="
echo "Test Results"
echo "=================================="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo

if [[ $TESTS_FAILED -eq 0 ]]; then
	echo "✓ All tests passed!"
	exit 0
else
	echo "✗ Some tests failed!"
	exit 1
fi

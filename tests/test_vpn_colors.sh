#!/bin/bash
# ABOUTME: Unit tests for VPN color management functions (src/vpn-colors)
# ABOUTME: Tests color output, NO_COLOR support, and ANSI escape code generation

set -euo pipefail

# Source the colors module to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/src/vpn-colors"

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

# Test: Color variables are defined
test_color_variables_defined() {
    if [[ -n "$RED" ]]; then
        echo "✓ PASS: RED variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: RED not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$GREEN" ]]; then
        echo "✓ PASS: GREEN variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: GREEN not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$YELLOW" ]]; then
        echo "✓ PASS: YELLOW variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: YELLOW not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$BLUE" ]]; then
        echo "✓ PASS: BLUE variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: BLUE not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$CYAN" ]]; then
        echo "✓ PASS: CYAN variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: CYAN not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$NC" ]]; then
        echo "✓ PASS: NC (No Color) variable defined"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: NC not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test: Color variables contain ANSI codes when NO_COLOR is unset
test_colors_have_ansi_codes() {
    unset NO_COLOR
    # Re-source to reset colors
    source "$PROJECT_ROOT/src/vpn-colors"

    assert_contains "\033[" "$RED" "RED contains ANSI escape code"
    assert_contains "\033[" "$GREEN" "GREEN contains ANSI escape code"
    assert_contains "\033[" "$YELLOW" "YELLOW contains ANSI escape code"
    assert_contains "\033[" "$NC" "NC contains ANSI escape code"
}

# Test: NO_COLOR environment variable disables colors
test_no_color_support() {
    export NO_COLOR=1
    # Re-source to apply NO_COLOR
    source "$PROJECT_ROOT/src/vpn-colors"

    assert_equals "" "$RED" "NO_COLOR disables RED"
    assert_equals "" "$GREEN" "NO_COLOR disables GREEN"
    assert_equals "" "$YELLOW" "NO_COLOR disables YELLOW"
    assert_equals "" "$BLUE" "NO_COLOR disables BLUE"
    assert_equals "" "$CYAN" "NO_COLOR disables CYAN"
    assert_equals "" "$NC" "NO_COLOR disables NC"

    unset NO_COLOR
}

# Test: colorize function works correctly
test_colorize_function() {
    unset NO_COLOR
    source "$PROJECT_ROOT/src/vpn-colors"

    local output
    output=$(colorize "red" "Error message")

    assert_contains "[0;31m" "$output" "colorize produces ANSI codes"
    assert_contains "Error message" "$output" "colorize includes message"
}

# Test: colorize respects NO_COLOR
test_colorize_no_color() {
    export NO_COLOR=1
    source "$PROJECT_ROOT/src/vpn-colors"

    local output
    output=$(colorize "red" "Error message")

    assert_equals "Error message" "$output" "colorize respects NO_COLOR"

    unset NO_COLOR
}

# Test: colorize handles invalid color gracefully
test_colorize_invalid_color() {
    unset NO_COLOR
    source "$PROJECT_ROOT/src/vpn-colors"

    local output
    output=$(colorize "invalid_color" "Test message")

    assert_equals "Test message" "$output" "colorize handles invalid color"
}

# Run all tests
echo "=================================="
echo "VPN Colors Test Suite"
echo "=================================="
echo

test_color_variables_defined
test_colors_have_ansi_codes
test_no_color_support
test_colorize_function
test_colorize_no_color
test_colorize_invalid_color

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

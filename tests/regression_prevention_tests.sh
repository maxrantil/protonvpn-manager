#!/bin/bash
# ABOUTME: Master test runner for regression prevention tests
# ABOUTME: Runs all tests that prevent the specific issues we fixed (networking crashes, hanging, false positives)

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

run_test_suite() {
    local test_file="$1"
    local test_name="$2"

    echo
    echo "=========================================="
    echo "Running $test_name"
    echo "=========================================="

    if [[ -f "$test_file" && -x "$test_file" ]]; then
        if timeout 120s "$test_file"; then
            log_test "PASS" "$test_name: All tests passed"
            return 0
        else
            log_test "FAIL" "$test_name: Some tests failed"
            return 1
        fi
    else
        log_test "FAIL" "$test_name: Test file not found or not executable: $test_file"
        return 1
    fi
}

main() {
    local overall_failures=0

    echo "================================================="
    echo "      REGRESSION PREVENTION TEST SUITE"
    echo "================================================="
    echo "Testing fixes for:"
    echo "  - NetworkManager restart causing internet crashes"
    echo "  - Commands hanging due to strict bash options"
    echo "  - False positive process detection"
    echo "  - Missing health command functionality"
    echo "  - Confusion between cleanup and emergency reset"
    echo "================================================="

    # Initialize test counters
    TESTS_PASSED=0
    TESTS_FAILED=0
    FAILED_TESTS=()

    # Run all regression prevention test suites
    run_test_suite "$TEST_DIR/process_detection_accuracy_tests.sh" "Process Detection Accuracy" || ((overall_failures++))

    run_test_suite "$TEST_DIR/networkmanager_preservation_tests.sh" "NetworkManager Preservation" || ((overall_failures++))

    run_test_suite "$TEST_DIR/command_completion_tests.sh" "Command Completion (No Hanging)" || ((overall_failures++))

    run_test_suite "$TEST_DIR/health_command_functionality_tests.sh" "Health Command Functionality" || ((overall_failures++))

    run_test_suite "$TEST_DIR/emergency_reset_vs_cleanup_tests.sh" "Emergency Reset vs Cleanup Separation" || ((overall_failures++))

    echo
    echo "================================================="
    echo "      REGRESSION PREVENTION SUMMARY"
    echo "================================================="

    if [[ $overall_failures -eq 0 ]]; then
        echo -e "\033[1;32m✓ ALL REGRESSION PREVENTION TESTS PASSED\033[0m"
        echo "The specific issues we fixed are protected against future regression:"
        echo "  ✓ NetworkManager stays intact during cleanup"
        echo "  ✓ Commands complete without hanging"
        echo "  ✓ Process detection is accurate (no false positives)"
        echo "  ✓ Health command works correctly"
        echo "  ✓ Emergency reset is separate from regular cleanup"
        echo
        echo "These tests will catch if anyone accidentally reintroduces:"
        echo "  - Internet-breaking NetworkManager restarts in cleanup"
        echo "  - Hanging commands due to bash strict mode"
        echo "  - False process detection matching grep commands"
        echo "  - Missing or broken health command"
        echo "  - Confusion between safe and disruptive commands"
        exit 0
    else
        echo -e "\033[1;31m✗ $overall_failures TEST SUITES FAILED\033[0m"
        echo "Some regression prevention tests failed."
        echo "This indicates the fixes may have regressed or new issues introduced."
        exit 1
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

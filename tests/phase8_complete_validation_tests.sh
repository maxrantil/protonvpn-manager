#!/bin/bash
# ABOUTME: Phase 8 Complete Testing & Validation - Master test runner for performance and edge cases
# ABOUTME: Executes both Phase 8.2 Performance Validation and Phase 8.3 Edge Case Testing

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test files
readonly PERFORMANCE_TESTS="$TEST_DIR/phase8_2_performance_validation_tests.sh"
readonly EDGE_CASE_TESTS="$TEST_DIR/phase8_3_edge_case_tests.sh"

# Track overall Phase 8 results (counters removed - unused in current implementation)
# Can be re-added when implementing comprehensive phase reporting
declare -a PHASE8_FAILED_SUITES=()

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"

    if [[ ! -f "$test_script" ]]; then
        log_test "ERROR" "Test suite not found: $test_script"
        PHASE8_FAILED_SUITES+=("$suite_name")
        return 1
    fi

    log_test "INFO" "=================================="
    log_test "INFO" "Starting $suite_name"
    log_test "INFO" "Test file: $test_script"
    log_test "INFO" "=================================="

    local start_time end_time duration
    start_time=$(date +%s)

    # Run the test suite
    local exit_code=0
    if bash "$test_script"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log_test "PASS" "$suite_name completed successfully (${duration}s)"
        return 0
    else
        exit_code=$?
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log_test "FAIL" "$suite_name failed with exit code $exit_code (${duration}s)"
        PHASE8_FAILED_SUITES+=("$suite_name")
        return $exit_code
    fi
}

validate_system_prerequisites() {
    log_test "INFO" "Validating system prerequisites for Phase 8 testing"

    # Check for required tools
    local missing_tools=()

    for tool in bc timeout pgrep pkill; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_test "ERROR" "Missing required tools: ${missing_tools[*]}"
        log_test "ERROR" "Install missing tools and run again"
        return 1
    fi

    # Check VPN system availability
    if [[ ! -f "$PROJECT_DIR/src/vpn" ]]; then
        log_test "ERROR" "VPN main script not found: $PROJECT_DIR/src/vpn"
        return 1
    fi

    if [[ ! -x "$PROJECT_DIR/src/vpn" ]]; then
        log_test "ERROR" "VPN main script not executable: $PROJECT_DIR/src/vpn"
        return 1
    fi

    log_test "PASS" "System prerequisites validated"
    return 0
}

cleanup_before_tests() {
    log_test "INFO" "Performing pre-test cleanup"

    # Clean up any existing VPN connections
    timeout 10 "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1 || true

    # Clean up any stress test remnants
    pkill -f "while true; do echo" 2> /dev/null || true

    # Clean up temporary test files
    rm -f /tmp/vpn_performance_test_*.log 2> /dev/null || true
    rm -f /tmp/connect_test_*.log 2> /dev/null || true
    rm -f /tmp/corrupted_test.ovpn 2> /dev/null || true
    rm -f /tmp/invalid_credentials_test.txt 2> /dev/null || true
    rm -f /tmp/stress_memory 2> /dev/null || true

    sleep 2 # Give system time to clean up

    log_test "INFO" "Pre-test cleanup completed"
}

cleanup_after_tests() {
    log_test "INFO" "Performing post-test cleanup"

    # Force cleanup of any remaining VPN processes
    timeout 10 "$PROJECT_DIR/src/vpn" cleanup > /dev/null 2>&1 || true

    # Clean up any remaining stress processes
    pkill -f "while true; do echo" 2> /dev/null || true

    # Clean up test files
    rm -f /tmp/vpn_performance_test_*.log 2> /dev/null || true
    rm -f /tmp/connect_test_*.log 2> /dev/null || true
    rm -f /tmp/corrupted_test.ovpn 2> /dev/null || true
    rm -f /tmp/invalid_credentials_test.txt 2> /dev/null || true
    rm -f /tmp/stress_memory 2> /dev/null || true
    rm -f /tmp/disk_space_test_large_file 2> /dev/null || true

    log_test "INFO" "Post-test cleanup completed"
}

show_phase8_summary() {
    log_test "INFO" "=========================================="
    log_test "INFO" "PHASE 8 COMPLETE TESTING SUMMARY"
    log_test "INFO" "=========================================="

    if [[ ${#PHASE8_FAILED_SUITES[@]} -eq 0 ]]; then
        log_test "PASS" "✅ ALL PHASE 8 TEST SUITES PASSED"
        log_test "INFO" "Phase 8.2 Performance Validation: ✅ COMPLETE"
        log_test "INFO" "Phase 8.3 Edge Case Testing: ✅ COMPLETE"
        log_test "INFO" ""
        log_test "INFO" "Phase 8 Testing & Validation: ✅ READY FOR COMPLETION"

        # Performance requirements verification
        log_test "INFO" "Performance Requirements Status:"
        log_test "INFO" "• Connection speed < 30s: Tested ✅"
        log_test "INFO" "• Memory stability: Validated ✅"
        log_test "INFO" "• Performance regression detection: Active ✅"

        # Edge case coverage verification
        log_test "INFO" ""
        log_test "INFO" "Edge Case Coverage Status:"
        log_test "INFO" "• No internet connection: Handled ✅"
        log_test "INFO" "• Invalid credentials: Handled ✅"
        log_test "INFO" "• Corrupted config files: Handled ✅"
        log_test "INFO" "• High system load: Handled ✅"
        log_test "INFO" "• Concurrent operations: Handled ✅"
        log_test "INFO" "• Process cleanup: Validated ✅"

    else
        log_test "FAIL" "❌ SOME PHASE 8 TEST SUITES FAILED"
        log_test "INFO" "Failed suites:"
        for suite in "${PHASE8_FAILED_SUITES[@]}"; do
            log_test "FAIL" "  • $suite"
        done

        log_test "INFO" ""
        log_test "WARNING" "Phase 8 completion requires all test suites to pass"
        log_test "INFO" "Review failed test details above and address issues before completion"
    fi

    log_test "INFO" "=========================================="
}

# Main test execution
main() {
    local overall_start_time overall_end_time total_duration
    overall_start_time=$(date +%s)

    log_test "INFO" "🚀 Starting Phase 8: Complete Testing & Validation"
    log_test "INFO" "This validates the 30-second connection requirement and robust error handling"
    log_test "INFO" ""

    # Validate prerequisites
    if ! validate_system_prerequisites; then
        log_test "ERROR" "System prerequisites validation failed"
        exit 1
    fi

    # Pre-test cleanup
    cleanup_before_tests

    # Run test suites in order
    local phase8_2_result=0 phase8_3_result=0

    # Phase 8.2: Performance Validation
    if run_test_suite "Phase 8.2 Performance Validation" "$PERFORMANCE_TESTS"; then
        log_test "INFO" "✅ Phase 8.2 Performance Validation completed successfully"
    else
        phase8_2_result=$?
        log_test "ERROR" "❌ Phase 8.2 Performance Validation failed"
    fi

    log_test "INFO" ""

    # Phase 8.3: Edge Case Testing
    if run_test_suite "Phase 8.3 Edge Case Testing" "$EDGE_CASE_TESTS"; then
        log_test "INFO" "✅ Phase 8.3 Edge Case Testing completed successfully"
    else
        phase8_3_result=$?
        log_test "ERROR" "❌ Phase 8.3 Edge Case Testing failed"
    fi

    # Post-test cleanup
    cleanup_after_tests

    # Calculate total runtime
    overall_end_time=$(date +%s)
    total_duration=$((overall_end_time - overall_start_time))

    log_test "INFO" ""
    log_test "INFO" "Total Phase 8 testing duration: ${total_duration} seconds"

    # Show comprehensive summary
    show_phase8_summary

    # Exit with appropriate code
    if [[ $phase8_2_result -eq 0 && $phase8_3_result -eq 0 ]]; then
        log_test "INFO" ""
        log_test "PASS" "🎉 Phase 8 Testing & Validation: COMPLETE"
        log_test "INFO" "Ready to mark Phase 8 as complete in implementation plan"
        exit 0
    else
        log_test "INFO" ""
        log_test "FAIL" "💥 Phase 8 Testing & Validation: INCOMPLETE"
        log_test "INFO" "Address test failures before completing Phase 8"
        exit 1
    fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

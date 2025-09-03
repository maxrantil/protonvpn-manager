#!/bin/bash
# ABOUTME: Main test runner for VPN management system
# ABOUTME: Executes all test suites and provides comprehensive reporting

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# Test configuration
ENABLE_UNIT_TESTS=1
ENABLE_INTEGRATION_TESTS=1
ENABLE_E2E_TESTS=1
ENABLE_REALISTIC_TESTS=1
VERBOSE=0
FAIL_FAST=0

usage() {
    echo "VPN Management System Test Runner"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit-only      Run only unit tests"
    echo "  -i, --integration-only Run only integration tests"
    echo "  -e, --e2e-only       Run only end-to-end tests"
    echo "  -r, --realistic-only Run only realistic connection tests"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -f, --fail-fast      Stop on first test failure"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Run all tests"
    echo "  $0 -u                Run only unit tests"
    echo "  $0 -v -f             Run all tests with verbose output, stop on failure"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--unit-only)
                ENABLE_UNIT_TESTS=1
                ENABLE_INTEGRATION_TESTS=0
                ENABLE_E2E_TESTS=0
                ENABLE_REALISTIC_TESTS=0
                shift
                ;;
            -i|--integration-only)
                ENABLE_UNIT_TESTS=0
                ENABLE_INTEGRATION_TESTS=1
                ENABLE_E2E_TESTS=0
                ENABLE_REALISTIC_TESTS=0
                shift
                ;;
            -e|--e2e-only)
                ENABLE_UNIT_TESTS=0
                ENABLE_INTEGRATION_TESTS=0
                ENABLE_E2E_TESTS=1
                ENABLE_REALISTIC_TESTS=0
                shift
                ;;
            -r|--realistic-only)
                ENABLE_UNIT_TESTS=0
                ENABLE_INTEGRATION_TESTS=0
                ENABLE_E2E_TESTS=0
                ENABLE_REALISTIC_TESTS=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -f|--fail-fast)
                FAIL_FAST=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

check_prerequisites() {
    log_test "INFO" "Checking test prerequisites"

    # Check required commands
    local missing_commands=()
    local required_commands=("bash" "grep" "awk" "find" "wc" "sort")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_test "FAIL" "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    # Check project structure
    if [[ ! -f "$PROJECT_DIR/src/vpn" ]]; then
        log_test "FAIL" "VPN script not found at $PROJECT_DIR/src/vpn"
        return 1
    fi

    if [[ ! -f "$PROJECT_DIR/src/vpn-manager" ]]; then
        log_test "FAIL" "VPN manager not found at $PROJECT_DIR/src/vpn-manager"
        return 1
    fi

    if [[ ! -f "$PROJECT_DIR/src/vpn-connector" ]]; then
        log_test "FAIL" "VPN connector not found at $PROJECT_DIR/src/vpn-connector"
        return 1
    fi

    log_test "PASS" "All prerequisites met"
    return 0
}

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"

    log_test "INFO" "Running $suite_name"
    echo ""

    # Track suite results
    local suite_start_time=$(date +%s)
    local suite_passed_before=$TESTS_PASSED
    local suite_failed_before=$TESTS_FAILED

    if [[ -f "$test_script" ]]; then
        # Make sure test script is executable
        chmod +x "$test_script"

        # Run the test suite
        if [[ $VERBOSE -eq 1 ]]; then
            bash "$test_script"
        else
            bash "$test_script" 2>/dev/null
        fi
        local suite_exit_code=$?

        # Calculate suite statistics
        local suite_end_time=$(date +%s)
        local suite_duration=$((suite_end_time - suite_start_time))
        local suite_passed=$((TESTS_PASSED - suite_passed_before))
        local suite_failed=$((TESTS_FAILED - suite_failed_before))

        echo ""
        log_test "INFO" "$suite_name completed in ${suite_duration}s"
        log_test "INFO" "$suite_name results: ${suite_passed} passed, ${suite_failed} failed"

        if [[ $suite_exit_code -ne 0 ]] && [[ $FAIL_FAST -eq 1 ]]; then
            log_test "FAIL" "Stopping due to test failure (fail-fast enabled)"
            return 1
        fi

        return $suite_exit_code
    else
        log_test "FAIL" "Test script not found: $test_script"
        return 1
    fi
}

generate_test_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=0

    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    fi

    echo ""
    echo "=========================================="
    echo "         COMPREHENSIVE TEST REPORT"
    echo "=========================================="
    echo "Test Execution Date: $(date)"
    echo "Test Environment: $(uname -s) $(uname -r)"
    echo "Project Directory: $PROJECT_DIR"
    echo ""
    echo "Test Suite Results:"

    if [[ $ENABLE_UNIT_TESTS -eq 1 ]]; then
        echo "  ✓ Unit Tests: Enabled"
    else
        echo "  ✗ Unit Tests: Disabled"
    fi

    if [[ $ENABLE_INTEGRATION_TESTS -eq 1 ]]; then
        echo "  ✓ Integration Tests: Enabled"
    else
        echo "  ✗ Integration Tests: Disabled"
    fi

    if [[ $ENABLE_E2E_TESTS -eq 1 ]]; then
        echo "  ✓ End-to-End Tests: Enabled"
    else
        echo "  ✗ End-to-End Tests: Disabled"
    fi

    echo ""
    echo "Overall Statistics:"
    echo "  Total Tests: $total_tests"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "  Success Rate: ${success_rate}%"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Tests:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}  ✗${NC} $failed_test"
        done
    fi

    echo ""
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo -e "${GREEN}The VPN management system is functioning correctly.${NC}"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED ❌${NC}"
        echo -e "${RED}Please review the failed tests and fix the issues.${NC}"
        return 1
    fi
}

main() {
    parse_arguments "$@"

    echo "VPN Management System - Comprehensive Test Suite"
    echo "=============================================="

    if ! check_prerequisites; then
        exit 1
    fi

    local start_time=$(date +%s)
    local overall_exit_code=0

    # Run test suites based on configuration
    if [[ $ENABLE_UNIT_TESTS -eq 1 ]]; then
        if ! run_test_suite "Unit Tests" "$TEST_DIR/unit_tests.sh"; then
            overall_exit_code=1
            if [[ $FAIL_FAST -eq 1 ]]; then
                generate_test_report
                exit $overall_exit_code
            fi
        fi
    fi

    if [[ $ENABLE_INTEGRATION_TESTS -eq 1 ]]; then
        if ! run_test_suite "Integration Tests" "$TEST_DIR/integration_tests.sh"; then
            overall_exit_code=1
            if [[ $FAIL_FAST -eq 1 ]]; then
                generate_test_report
                exit $overall_exit_code
            fi
        fi
    fi

    if [[ $ENABLE_E2E_TESTS -eq 1 ]]; then
        if ! run_test_suite "End-to-End Tests" "$TEST_DIR/e2e_tests.sh"; then
            overall_exit_code=1
            if [[ $FAIL_FAST -eq 1 ]]; then
                generate_test_report
                exit $overall_exit_code
            fi
        fi
    fi

    if [[ $ENABLE_REALISTIC_TESTS -eq 1 ]]; then
        if ! run_test_suite "Realistic Connection Tests" "$TEST_DIR/realistic_connection_tests.sh"; then
            overall_exit_code=1
            if [[ $FAIL_FAST -eq 1 ]]; then
                generate_test_report
                exit $overall_exit_code
            fi
        fi
    fi

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    log_test "INFO" "All test suites completed in ${total_duration}s"

    generate_test_report
    exit $overall_exit_code
}

# Run main function with all arguments
main "$@"

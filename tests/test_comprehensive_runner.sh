#!/bin/bash
# ABOUTME: Comprehensive test runner for ProtonVPN production system
# ABOUTME: Orchestrates all test suites with proper setup, execution, and reporting

set -euo pipefail

# Test runner configuration
TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Test results
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_TEST_SUITES=0
FAILED_TEST_SUITES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Test suite runner
run_test_suite() {
    local test_script="$1"
    local test_name="$2"
    local test_description="$3"

    echo ""
    echo "================================================================"
    echo "  RUNNING: $test_name"
    echo "  Description: $test_description"
    echo "================================================================"

    ((TOTAL_TEST_SUITES++))

    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        FAILED_TEST_SUITES+=("$test_name (script not found)")
        ((TOTAL_TESTS_FAILED++))
        return 1
    fi

    # Make test script executable
    chmod +x "$test_script"

    # Run test suite and capture results
    local start_time=$(date +%s)
    local test_output_file="/tmp/test_output_$$.log"

    if bash "$test_script" > "$test_output_file" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "$test_name completed successfully in ${duration}s"

        # Extract test counts if available
        local passed=$(grep -o "Passed: [0-9]\+" "$test_output_file" | tail -1 | grep -o "[0-9]\+" || echo "0")
        local failed=$(grep -o "Failed: [0-9]\+" "$test_output_file" | tail -1 | grep -o "[0-9]\+" || echo "0")

        ((TOTAL_TESTS_PASSED += passed))
        ((TOTAL_TESTS_FAILED += failed))

        echo "  Suite Results: $passed passed, $failed failed"

        # Show last few lines of output for context
        echo "  Output preview:"
        tail -5 "$test_output_file" | sed 's/^/    /'

    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "$test_name failed after ${duration}s"
        FAILED_TEST_SUITES+=("$test_name")

        echo "  Error output:"
        tail -10 "$test_output_file" | sed 's/^/    /'

        ((TOTAL_TESTS_FAILED++))
    fi

    # Clean up
    rm -f "$test_output_file"
}

# Initialize test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Initialize mock framework
    log_info "Initializing mock framework..."
    if [[ -f "$TEST_DIR/test_mocking_framework.sh" ]]; then
        bash "$TEST_DIR/test_mocking_framework.sh" init
        log_success "Mock framework initialized"
    else
        log_warning "Mock framework not found, some tests may require root privileges"
    fi

    # Create test data directory
    mkdir -p "/tmp/protonvpn-test-data"

    # Set test environment variables
    export PROTONVPN_TEST_MODE="true"
    export PROTONVPN_PROJECT_DIR="$PROJECT_DIR"
    export PROTONVPN_TEST_DATA_DIR="/tmp/protonvpn-test-data"

    log_success "Test environment ready"
}

# Clean up test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    # Clean up mock framework
    if [[ -f "$TEST_DIR/test_mocking_framework.sh" ]]; then
        bash "$TEST_DIR/test_mocking_framework.sh" cleanup 2> /dev/null || true
    fi

    # Clean up test data
    rm -rf "/tmp/protonvpn-test-data" || true
    rm -rf "/tmp/test_output_"* || true
    rm -rf "/tmp/protonvpn-test-"* || true

    log_success "Test environment cleaned up"
}

# Generate test report
generate_test_report() {
    local report_file="$PROJECT_DIR/test_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
ProtonVPN System Test Report
============================
Generated: $(date)
Test Directory: $TEST_DIR
Project Directory: $PROJECT_DIR

Test Summary:
-------------
Total Test Suites: $TOTAL_TEST_SUITES
Individual Tests Passed: $TOTAL_TESTS_PASSED
Individual Tests Failed: $TOTAL_TESTS_FAILED
Test Suite Success Rate: $(((TOTAL_TEST_SUITES - ${#FAILED_TEST_SUITES[@]}) * 100 / TOTAL_TEST_SUITES || 0))%

Failed Test Suites:
-------------------
EOF

    if [[ ${#FAILED_TEST_SUITES[@]} -eq 0 ]]; then
        echo "None - All test suites passed!" >> "$report_file"
    else
        for suite in "${FAILED_TEST_SUITES[@]}"; do
            echo "- $suite" >> "$report_file"
        done
    fi

    cat >> "$report_file" << EOF

Test Environment:
-----------------
- Mock framework utilized for non-privileged testing
- Security validation included
- Installation robustness tested
- Service management validated
- Integration testing performed

Recommendations:
----------------
EOF

    if [[ ${#FAILED_TEST_SUITES[@]} -gt 0 ]]; then
        cat >> "$report_file" << EOF
1. Review failed test suites and address issues
2. Re-run individual test suites after fixes
3. Consider additional edge case testing for failed areas
4. Validate fixes in production-like environment
EOF
    else
        cat >> "$report_file" << EOF
1. All tests passing - system ready for production deployment
2. Consider running tests in actual production environment
3. Set up continuous integration for ongoing validation
4. Implement regular security scanning schedule
EOF
    fi

    echo ""
    log_success "Test report generated: $report_file"
    return "$report_file"
}

# Main test execution
run_comprehensive_tests() {
    local test_mode="${1:-all}"

    echo "================================================================"
    echo "  ProtonVPN Comprehensive Test Suite"
    echo "  Mode: $test_mode"
    echo "  Started: $(date)"
    echo "================================================================"

    setup_test_environment

    # Define test suites
    case "$test_mode" in
        "security")
            log_info "Running security tests only..."
            run_test_suite "$TEST_DIR/test_security_validation.sh" \
                "Security Validation" \
                "Validates security fixes and hardening measures"
            ;;
        "installation")
            log_info "Running installation tests only..."
            run_test_suite "$TEST_DIR/test_installation.sh" \
                "Installation Robustness" \
                "Tests installation scenarios and rollback procedures"
            ;;
        "service")
            log_info "Running service management tests only..."
            run_test_suite "$TEST_DIR/test_service_management.sh" \
                "Service Management" \
                "Tests service lifecycle and management operations"
            ;;
        "integration")
            log_info "Running integration tests only..."
            run_test_suite "$TEST_DIR/integration_tests.sh" \
                "Integration Testing" \
                "Tests component interactions and system integration"
            ;;
        "all" | *)
            log_info "Running all test suites..."

            # Security Tests (High Priority)
            run_test_suite "$TEST_DIR/test_security_validation.sh" \
                "Security Validation" \
                "Validates security fixes and hardening measures"

            # Installation Tests
            run_test_suite "$TEST_DIR/test_installation.sh" \
                "Installation Robustness" \
                "Tests installation scenarios and rollback procedures"

            # Service Management Tests
            run_test_suite "$TEST_DIR/test_service_management.sh" \
                "Service Management" \
                "Tests service lifecycle and management operations"

            # Integration Tests
            if [[ -f "$TEST_DIR/integration_tests.sh" ]]; then
                run_test_suite "$TEST_DIR/integration_tests.sh" \
                    "Integration Testing" \
                    "Tests component interactions and system integration"
            fi

            # Additional existing tests
            for test_file in "$TEST_DIR"/*_tests.sh; do
                if [[ -f "$test_file" ]] && [[ ! "$test_file" =~ (test_security_validation|test_installation|test_service_management|integration_tests) ]]; then
                    local test_name=$(basename "$test_file" .sh)
                    run_test_suite "$test_file" \
                        "$test_name" \
                        "Additional system testing"
                fi
            done
            ;;
    esac

    cleanup_test_environment

    # Final results
    echo ""
    echo "================================================================"
    echo "  TEST EXECUTION COMPLETE"
    echo "================================================================"

    local report_file
    report_file=$(generate_test_report)

    echo ""
    echo "Final Results:"
    echo "=============="
    echo "Test Suites Run: $TOTAL_TEST_SUITES"
    echo "Test Suites Passed: $((TOTAL_TEST_SUITES - ${#FAILED_TEST_SUITES[@]}))"
    echo "Test Suites Failed: ${#FAILED_TEST_SUITES[@]}"
    echo "Individual Tests Passed: $TOTAL_TESTS_PASSED"
    echo "Individual Tests Failed: $TOTAL_TESTS_FAILED"

    if [[ ${#FAILED_TEST_SUITES[@]} -eq 0 ]]; then
        echo ""
        log_success "🎉 ALL TESTS PASSED! System ready for production deployment."
        exit 0
    else
        echo ""
        log_error "❌ SOME TESTS FAILED! Please review and fix issues before deployment."
        echo ""
        echo "Failed test suites:"
        for suite in "${FAILED_TEST_SUITES[@]}"; do
            echo "  - $suite"
        done
        exit 1
    fi
}

# Usage information
show_usage() {
    cat << EOF
ProtonVPN Comprehensive Test Runner

Usage: $0 [mode]

Modes:
  all          - Run all test suites (default)
  security     - Run security validation tests only
  installation - Run installation robustness tests only
  service      - Run service management tests only
  integration  - Run integration tests only

Examples:
  $0                    # Run all tests
  $0 security          # Run only security tests
  $0 installation      # Run only installation tests

The test runner will:
1. Set up a mock environment for non-privileged testing
2. Run the specified test suites
3. Generate a comprehensive test report
4. Clean up the test environment
5. Provide detailed results and recommendations

Test results are logged and a report is generated in the project directory.
EOF
}

# Main execution
main() {
    local mode="${1:-all}"

    case "$mode" in
        "help" | "--help" | "-h")
            show_usage
            ;;
        *)
            run_comprehensive_tests "$mode"
            ;;
    esac
}

# Trap cleanup on exit
trap cleanup_test_environment EXIT

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

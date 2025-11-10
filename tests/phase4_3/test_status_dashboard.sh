#!/bin/bash
# ABOUTME: Phase 4.2.3 Status Dashboard comprehensive TDD test suite
# ABOUTME: Tests JSON output, real-time metrics, WCAG compliance, and service integration

set -euo pipefail

# Test framework integration
readonly PHASE4_TEST_DIR
PHASE4_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(cd "$PHASE4_TEST_DIR/../.." && pwd)"
readonly VPN_DIR="$PROJECT_ROOT/src"
readonly DASHBOARD_SCRIPT="$VPN_DIR/status-dashboard"

# Simple test framework functions (used by test execution)
# shellcheck disable=SC2317
log_info() { echo "[INFO] $1" >&2; }
# shellcheck disable=SC2317
log_error() { echo "[ERROR] $1" >&2; }

# Test configuration
TEST_PHASE="Phase 4.2.3 Status Dashboard"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_environment() {
    export TEST_TEMP_DIR="/tmp/status_dashboard_test_$$"
    mkdir -p "$TEST_TEMP_DIR"
    export TEST_CONFIG_FILE="$TEST_TEMP_DIR/test_config.toml"

    # Create test configuration
    cat > "$TEST_CONFIG_FILE" << 'EOF'
[dashboard]
refresh_interval = 5
output_format = "json"
real_time = true
history_retention = "7d"

[health_monitor]
check_interval = 30
recovery_enabled = true
max_retries = 3

[api]
enabled = false
port = 8080
auth_required = true
EOF
}

cleanup_test_environment() {
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# TDD RED PHASE - All these tests will fail until implementation
test_dashboard_exists() {
    start_test "status_dashboard_script_exists"
    if [[ -x "$DASHBOARD_SCRIPT" ]]; then
        pass_test "Status dashboard script exists and is executable"
    else
        fail_test "Status dashboard script not found or not executable at $DASHBOARD_SCRIPT"
    fi
}

test_dashboard_basic_json_output() {
    start_test "dashboard_basic_json_output"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard should provide JSON output"
    else
        # Validate JSON structure
        if echo "$result" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
            pass_test "Dashboard produces valid JSON output"
        else
            fail_test "Dashboard JSON output is malformed"
        fi
    fi
}

test_dashboard_human_readable_output() {
    start_test "dashboard_human_readable_output"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=human 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard should provide human-readable output"
    else
        # Check for expected human-readable elements
        if echo "$result" | grep -q "Status:" && echo "$result" | grep -q "Uptime:"; then
            pass_test "Dashboard produces human-readable output"
        else
            fail_test "Dashboard human output missing expected elements"
        fi
    fi
}

test_dashboard_connection_status() {
    start_test "dashboard_connection_status_field"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for connection status test"
    else
        if echo "$result" | grep -q '"service"'; then
            pass_test "Dashboard includes service status field"
        else
            fail_test "Dashboard JSON missing service status field"
        fi
    fi
}

test_dashboard_uptime_tracking() {
    start_test "dashboard_uptime_field"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for uptime test"
    else
        if echo "$result" | grep -q '"uptime"'; then
            pass_test "Dashboard includes uptime field"
        else
            fail_test "Dashboard JSON missing uptime field"
        fi
    fi
}

test_dashboard_performance_metrics() {
    start_test "dashboard_performance_metrics"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for performance metrics test"
    else
        if echo "$result" | grep -q '"performance"'; then
            pass_test "Dashboard includes performance metrics"
        else
            fail_test "Dashboard JSON missing performance metrics"
        fi
    fi
}

test_dashboard_security_status() {
    start_test "dashboard_security_status"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for security status test"
    else
        if echo "$result" | grep -q '"security"'; then
            pass_test "Dashboard includes security status"
        else
            fail_test "Dashboard JSON missing security status"
        fi
    fi
}

test_dashboard_error_handling() {
    start_test "dashboard_error_handling"
    local result exit_code
    result=$("$DASHBOARD_SCRIPT" --invalid-flag 2>&1) || exit_code=$?

    if [[ "${exit_code:-0}" -ne 0 ]]; then
        # Should fail with invalid flag
        if echo "$result" | grep -qi "error\|invalid\|usage"; then
            pass_test "Dashboard handles invalid arguments correctly"
        else
            fail_test "Dashboard error message not user-friendly"
        fi
    else
        fail_test "Dashboard should fail with invalid arguments"
    fi
}

test_dashboard_help_output() {
    start_test "dashboard_help_output"
    local result
    result=$("$DASHBOARD_SCRIPT" --help 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard --help should be available"
    else
        if echo "$result" | grep -q "Usage:" && echo "$result" | grep -q "format"; then
            pass_test "Dashboard provides helpful usage information"
        else
            fail_test "Dashboard help output missing essential information"
        fi
    fi
}

# WCAG Accessibility Tests (following agent recommendations)
test_dashboard_accessibility_semantic_output() {
    start_test "dashboard_accessibility_semantic_structure"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=human 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for accessibility test"
    else
        # Check for semantic markers as recommended by UX agent
        if echo "$result" | grep -q "===.*==="; then
            pass_test "Dashboard uses semantic output structure for screen readers"
        else
            fail_test "Dashboard missing semantic structure for accessibility"
        fi
    fi
}

test_dashboard_accessibility_json_metadata() {
    start_test "dashboard_accessibility_json_metadata"
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for accessibility JSON test"
    else
        if echo "$result" | grep -q '"accessibility"'; then
            pass_test "Dashboard JSON includes accessibility metadata"
        else
            fail_test "Dashboard JSON missing accessibility metadata"
        fi
    fi
}

# Integration Tests
test_dashboard_notification_integration() {
    start_test "dashboard_notification_system_integration"
    # Test that dashboard can trigger notifications (security requirement)
    local result
    result=$("$DASHBOARD_SCRIPT" --notify-on-error 2>&1 || echo "no_notification_support")

    if echo "$result" | grep -q "no_notification_support"; then
        fail_test "Dashboard should integrate with notification system"
    else
        pass_test "Dashboard supports notification integration"
    fi
}

test_dashboard_config_integration() {
    start_test "dashboard_config_manager_integration"
    # Test configuration loading from TOML
    local result
    export VPN_CONFIG_FILE="$TEST_CONFIG_FILE"
    result=$("$DASHBOARD_SCRIPT" --config="$TEST_CONFIG_FILE" 2>&1 || echo "config_failed")

    if echo "$result" | grep -q "config_failed"; then
        fail_test "Dashboard should load configuration from TOML files"
    else
        pass_test "Dashboard integrates with config-manager"
    fi
}

# Security Tests (maintaining 17/17 security test score)
test_dashboard_security_sanitization() {
    start_test "dashboard_output_sanitization"
    # Test that sensitive data is not exposed
    local result
    result=$("$DASHBOARD_SCRIPT" --format=json 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Dashboard not available for security test"
    else
        # Check that no credentials or sensitive paths are exposed
        if echo "$result" | grep -Eq "(password|key|secret|token|/root|/home/.*/\.ssh)"; then
            fail_test "Dashboard output may contain sensitive information"
        else
            pass_test "Dashboard output properly sanitized"
        fi
    fi
}

test_dashboard_audit_logging() {
    start_test "dashboard_audit_log_integration"
    # Test that dashboard access is logged
    local log_before log_after
    log_before=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")
    "$DASHBOARD_SCRIPT" --format=json >/dev/null 2>&1 || true
    log_after=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")

    if [[ "$log_after" -gt "$log_before" ]]; then
        pass_test "Dashboard usage properly logged in audit system"
    else
        fail_test "Dashboard should log access to audit system"
    fi
}

# Performance Tests (following performance-optimizer agent recommendations)
test_dashboard_response_time() {
    start_test "dashboard_performance_response_time"
    local start_time end_time duration_ms

    start_time=$(date +%s%N)
    "$DASHBOARD_SCRIPT" --format=json >/dev/null 2>&1 || true
    end_time=$(date +%s%N)

    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$duration_ms" -lt 100 ]]; then
        pass_test "Dashboard response time under 100ms target: ${duration_ms}ms"
    else
        fail_test "Dashboard response time exceeds 100ms target: ${duration_ms}ms"
    fi
}

test_dashboard_memory_usage() {
    start_test "dashboard_memory_efficiency"
    local memory_before memory_after memory_used

    memory_before=$(ps -o pid,vsz,rss | awk '{sum+=$3} END {print sum}' 2>/dev/null || echo "0")
    "$DASHBOARD_SCRIPT" --format=json >/dev/null 2>&1 || true
    memory_after=$(ps -o pid,vsz,rss | awk '{sum+=$3} END {print sum}' 2>/dev/null || echo "0")

    memory_used=$((memory_after - memory_before))

    if [[ "$memory_used" -lt 5120 ]]; then  # 5MB limit
        pass_test "Dashboard memory usage within limits: ${memory_used}KB"
    else
        fail_test "Dashboard memory usage exceeds 5MB limit: ${memory_used}KB"
    fi
}

# Real-time/Watch mode tests
test_dashboard_watch_mode() {
    start_test "dashboard_watch_mode_support"
    local result exit_code

    # Start watch mode in background and kill after 2 seconds
    timeout 2 "$DASHBOARD_SCRIPT" --watch 2>&1 || exit_code=$?

    # Exit code 124 means timeout (expected), others indicate problems
    if [[ "${exit_code:-0}" -eq 124 ]]; then
        pass_test "Dashboard watch mode functions correctly"
    else
        fail_test "Dashboard watch mode not supported or failed"
    fi
}

# Test execution framework
run_all_tests() {
    log_info "Starting $TEST_PHASE Test Suite"
    log_info "Target implementation: $DASHBOARD_SCRIPT"

    setup_test_environment

    # Basic functionality tests (RED phase - will fail)
    test_dashboard_exists
    test_dashboard_basic_json_output
    test_dashboard_human_readable_output
    test_dashboard_connection_status
    test_dashboard_uptime_tracking
    test_dashboard_performance_metrics
    test_dashboard_security_status
    test_dashboard_error_handling
    test_dashboard_help_output

    # Accessibility tests (WCAG compliance)
    test_dashboard_accessibility_semantic_output
    test_dashboard_accessibility_json_metadata

    # Integration tests
    test_dashboard_notification_integration
    test_dashboard_config_integration

    # Security tests (maintain 17/17 score)
    test_dashboard_security_sanitization
    test_dashboard_audit_logging

    # Performance tests (<100ms target)
    test_dashboard_response_time
    test_dashboard_memory_usage

    # Real-time functionality
    test_dashboard_watch_mode

    cleanup_test_environment

    # Test summary
    log_info "=== Test Summary ==="
    log_info "Tests Run: $TESTS_RUN"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"

    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        log_info "✅ All tests passed!"
        return 0
    else
        log_error "❌ $TESTS_FAILED tests failed"
        return 1
    fi
}

# Test framework helper functions
start_test() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo -n "Testing $test_name... "
}

pass_test() {
    local message="$1"
    ((TESTS_PASSED++))
    echo "✅ PASS - $message"
}

fail_test() {
    local message="$1"
    ((TESTS_FAILED++))
    echo "❌ FAIL - $message"
}

log_info() {
    echo "[INFO] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi

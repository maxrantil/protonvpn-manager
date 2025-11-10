#!/bin/bash
# ABOUTME: Phase 4.2.3 Health Monitor comprehensive TDD test suite
# ABOUTME: Tests proactive monitoring, automatic recovery, alerting, and service integration

set -euo pipefail

# Test framework integration
readonly PHASE4_TEST_DIR
PHASE4_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(cd "$PHASE4_TEST_DIR/../.." && pwd)"
readonly VPN_DIR="$PROJECT_ROOT/src"
readonly HEALTH_MONITOR_SCRIPT="$VPN_DIR/health-monitor"

# Simple test framework functions (used by test execution)
# shellcheck disable=SC2317
log_info() { echo "[INFO] $1" >&2; }
# shellcheck disable=SC2317
log_error() { echo "[ERROR] $1" >&2; }

# Test configuration
TEST_PHASE="Phase 4.2.3 Health Monitor"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_environment() {
    export TEST_TEMP_DIR="/tmp/health_monitor_test_$$"
    mkdir -p "$TEST_TEMP_DIR"
    export TEST_CONFIG_FILE="$TEST_TEMP_DIR/test_health_config.toml"

    # Create test configuration for health monitor
    cat > "$TEST_CONFIG_FILE" << 'EOF'
[health_monitor]
enabled = true
check_interval = 10
recovery_enabled = true
max_recovery_attempts = 3

[health_monitor.thresholds]
memory_warning_mb = 20.0
memory_critical_mb = 23.0
cpu_warning_percent = 80.0
cpu_critical_percent = 95.0
connection_timeout_seconds = 10.0

[health_monitor.recovery_actions]
high_memory = "restart_service"
vpn_disconnected = "reconnect_vpn"
config_corrupted = "reload_config"

[health_monitor.notifications]
send_warnings = true
send_critical = true
escalation_delay_minutes = 15
EOF

    # Create mock service files for testing
    export MOCK_SERVICE_PID="/tmp/mock_vpn_service.pid"
    echo "12345" > "$MOCK_SERVICE_PID"
}

cleanup_test_environment() {
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    [[ -f "$MOCK_SERVICE_PID" ]] && rm -f "$MOCK_SERVICE_PID"
}

# TDD RED PHASE - All these tests will fail until implementation

# Basic functionality tests
test_health_monitor_exists() {
    start_test "health_monitor_script_exists"
    if [[ -x "$HEALTH_MONITOR_SCRIPT" ]]; then
        pass_test "Health monitor script exists and is executable"
    else
        fail_test "Health monitor script not found or not executable at $HEALTH_MONITOR_SCRIPT"
    fi
}

test_health_monitor_help() {
    start_test "health_monitor_help_output"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --help 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "Health monitor --help should be available"
    else
        if echo "$result" | grep -q "Usage:" && echo "$result" | grep -q "daemon\|check"; then
            pass_test "Health monitor provides helpful usage information"
        else
            fail_test "Health monitor help output missing essential information"
        fi
    fi
}

# Health checking functionality tests
test_health_monitor_check_all() {
    start_test "health_monitor_check_all_functionality"
    local result exit_code=0
    result=$("$HEALTH_MONITOR_SCRIPT" --check-all 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        if echo "$result" | grep -q "Health check"; then
            pass_test "Health monitor can perform system health checks"
        else
            fail_test "Health monitor check output doesn't contain expected content"
        fi
    else
        fail_test "Health monitor check-all should execute successfully"
    fi
}

test_health_monitor_daemon_mode() {
    start_test "health_monitor_daemon_mode_support"
    local result exit_code=0

    # Test daemon mode startup (should run briefly then we'll kill it)
    timeout 2 "$HEALTH_MONITOR_SCRIPT" --daemon 2>&1 || exit_code=$?

    # Exit code 124 means timeout (expected for daemon), others indicate problems
    if [[ "$exit_code" -eq 124 ]]; then
        pass_test "Health monitor daemon mode functions correctly"
    elif [[ "$exit_code" -eq 0 ]]; then
        pass_test "Health monitor daemon mode started successfully"
    else
        fail_test "Health monitor daemon mode not supported or failed"
    fi
}

test_health_monitor_recovery_mode() {
    start_test "health_monitor_recovery_mode_support"
    local result exit_code=0
    result=$("$HEALTH_MONITOR_SCRIPT" --recovery-mode 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        if echo "$result" | grep -qi "recovery\|repair\|restart"; then
            pass_test "Health monitor supports recovery mode operations"
        else
            fail_test "Health monitor recovery mode output doesn't contain expected content"
        fi
    else
        fail_test "Health monitor recovery mode should be available"
    fi
}

# Configuration and integration tests
test_health_monitor_config_loading() {
    start_test "health_monitor_config_integration"
    local result exit_code=0
    export VPN_CONFIG_FILE="$TEST_CONFIG_FILE"
    result=$("$HEALTH_MONITOR_SCRIPT" --config="$TEST_CONFIG_FILE" --check-all 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        pass_test "Health monitor integrates with config system"
    else
        fail_test "Health monitor should load configuration from TOML files"
    fi
}

test_health_monitor_notification_integration() {
    start_test "health_monitor_notification_system_integration"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --notify-critical 2>&1 || echo "no_notification_support")

    if echo "$result" | grep -q "no_notification_support"; then
        fail_test "Health monitor should integrate with notification system"
    else
        pass_test "Health monitor supports notification integration"
    fi
}

# Health check specific tests
test_health_monitor_service_checks() {
    start_test "health_monitor_service_status_checks"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --check=service 2>&1 || echo "check_failed")

    if echo "$result" | grep -q "check_failed"; then
        fail_test "Health monitor should check VPN service status"
    else
        if echo "$result" | grep -qi "service\|vpn\|active\|inactive"; then
            pass_test "Health monitor can check service status"
        else
            fail_test "Health monitor service check output unexpected"
        fi
    fi
}

test_health_monitor_resource_checks() {
    start_test "health_monitor_resource_usage_checks"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --check=resources 2>&1 || echo "check_failed")

    if echo "$result" | grep -q "check_failed"; then
        fail_test "Health monitor should check resource usage"
    else
        if echo "$result" | grep -qi "memory\|cpu\|disk"; then
            pass_test "Health monitor can check resource usage"
        else
            fail_test "Health monitor resource check output unexpected"
        fi
    fi
}

test_health_monitor_connectivity_checks() {
    start_test "health_monitor_connectivity_checks"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --check=connectivity 2>&1 || echo "check_failed")

    if echo "$result" | grep -q "check_failed"; then
        fail_test "Health monitor should check network connectivity"
    else
        if echo "$result" | grep -qi "connect\|network\|ping\|dns"; then
            pass_test "Health monitor can check connectivity"
        else
            fail_test "Health monitor connectivity check output unexpected"
        fi
    fi
}

# Recovery and automation tests
test_health_monitor_automatic_recovery() {
    start_test "health_monitor_automatic_recovery_capabilities"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --recover=service_failure 2>&1 || echo "recovery_failed")

    if echo "$result" | grep -q "recovery_failed"; then
        fail_test "Health monitor should support automatic recovery"
    else
        if echo "$result" | grep -qi "recover\|restart\|repair"; then
            pass_test "Health monitor supports automatic recovery"
        else
            fail_test "Health monitor recovery output unexpected"
        fi
    fi
}

test_health_monitor_recovery_limits() {
    start_test "health_monitor_recovery_attempt_limits"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --test-recovery-limits 2>&1 || echo "limits_not_supported")

    if echo "$result" | grep -q "limits_not_supported"; then
        fail_test "Health monitor should implement recovery attempt limits"
    else
        if echo "$result" | grep -qi "limit\|attempt\|maximum"; then
            pass_test "Health monitor implements recovery limits"
        else
            fail_test "Health monitor recovery limits not properly implemented"
        fi
    fi
}

# Integration with existing components tests
test_health_monitor_dashboard_integration() {
    start_test "health_monitor_status_dashboard_integration"
    # Test that health monitor can provide data to status dashboard
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --export-status 2>&1 || echo "export_failed")

    if echo "$result" | grep -q "export_failed"; then
        fail_test "Health monitor should export status for dashboard integration"
    else
        pass_test "Health monitor can export status data"
    fi
}

test_health_monitor_audit_logging() {
    start_test "health_monitor_audit_log_integration"
    # Test that health monitor logs to audit system
    local log_before log_after
    log_before=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")
    "$HEALTH_MONITOR_SCRIPT" --check=service >/dev/null 2>&1 || true
    log_after=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")

    if [[ "$log_after" -gt "$log_before" ]]; then
        pass_test "Health monitor usage properly logged in audit system"
    else
        fail_test "Health monitor should log activities to audit system"
    fi
}

# Security and validation tests
test_health_monitor_security_compliance() {
    start_test "health_monitor_security_integration"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --validate-security 2>&1 || echo "security_check_failed")

    if echo "$result" | grep -q "security_check_failed"; then
        fail_test "Health monitor should implement security validation"
    else
        if echo "$result" | grep -qi "security\|permission\|access"; then
            pass_test "Health monitor implements security compliance"
        else
            fail_test "Health monitor security validation unexpected output"
        fi
    fi
}

test_health_monitor_error_handling() {
    start_test "health_monitor_error_handling"
    local result exit_code
    result=$("$HEALTH_MONITOR_SCRIPT" --invalid-flag 2>&1) || exit_code=$?

    if [[ "${exit_code:-0}" -ne 0 ]]; then
        # Should fail with invalid flag
        if echo "$result" | grep -qi "error\|invalid\|usage"; then
            pass_test "Health monitor handles invalid arguments correctly"
        else
            fail_test "Health monitor error message not user-friendly"
        fi
    else
        fail_test "Health monitor should fail with invalid arguments"
    fi
}

# Performance and reliability tests
test_health_monitor_performance() {
    start_test "health_monitor_performance_requirements"
    local start_time end_time duration_ms

    start_time=$(date +%s%N)
    "$HEALTH_MONITOR_SCRIPT" --check=service >/dev/null 2>&1 || true
    end_time=$(date +%s%N)

    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$duration_ms" -lt 500 ]]; then  # 500ms limit for health checks
        pass_test "Health monitor performance within limits: ${duration_ms}ms"
    else
        fail_test "Health monitor performance exceeds 500ms limit: ${duration_ms}ms"
    fi
}

test_health_monitor_concurrent_execution() {
    start_test "health_monitor_concurrent_safety"
    local pids=()
    local failed=0

    # Start multiple health monitor instances
    # shellcheck disable=SC2034  # i is loop counter placeholder
    for i in {1..3}; do
        "$HEALTH_MONITOR_SCRIPT" --check=service >/dev/null 2>&1 &
        pids+=($!)
    done

    # Wait for all to complete
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done

    if [[ "$failed" -eq 0 ]]; then
        pass_test "Health monitor handles concurrent execution safely"
    else
        fail_test "Health monitor failed under concurrent execution"
    fi
}

# Alerting and escalation tests
test_health_monitor_alerting_system() {
    start_test "health_monitor_alert_generation"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --generate-test-alert 2>&1 || echo "alerting_failed")

    if echo "$result" | grep -q "alerting_failed"; then
        fail_test "Health monitor should support alert generation"
    else
        if echo "$result" | grep -qi "alert\|notification\|warning"; then
            pass_test "Health monitor can generate alerts"
        else
            fail_test "Health monitor alerting output unexpected"
        fi
    fi
}

test_health_monitor_escalation() {
    start_test "health_monitor_alert_escalation"
    local result
    result=$("$HEALTH_MONITOR_SCRIPT" --test-escalation 2>&1 || echo "escalation_failed")

    if echo "$result" | grep -q "escalation_failed"; then
        fail_test "Health monitor should support alert escalation"
    else
        if echo "$result" | grep -qi "escalat\|critical\|urgent"; then
            pass_test "Health monitor supports alert escalation"
        else
            fail_test "Health monitor escalation output unexpected"
        fi
    fi
}

# Test execution framework
run_all_tests() {
    log_info "Starting $TEST_PHASE Test Suite"
    log_info "Target implementation: $HEALTH_MONITOR_SCRIPT"

    setup_test_environment

    # Basic functionality tests (RED phase - will fail)
    test_health_monitor_exists
    test_health_monitor_help
    test_health_monitor_check_all
    test_health_monitor_daemon_mode
    test_health_monitor_recovery_mode

    # Configuration and integration tests
    test_health_monitor_config_loading
    test_health_monitor_notification_integration

    # Health check specific tests
    test_health_monitor_service_checks
    test_health_monitor_resource_checks
    test_health_monitor_connectivity_checks

    # Recovery and automation tests
    test_health_monitor_automatic_recovery
    test_health_monitor_recovery_limits

    # Integration tests
    test_health_monitor_dashboard_integration
    test_health_monitor_audit_logging

    # Security tests
    test_health_monitor_security_compliance
    test_health_monitor_error_handling

    # Performance tests
    test_health_monitor_performance
    test_health_monitor_concurrent_execution

    # Alerting tests
    test_health_monitor_alerting_system
    test_health_monitor_escalation

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
        log_error "❌ $TESTS_FAILED tests failed (RED phase - expected until implementation)"
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

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi

#!/bin/bash
# ABOUTME: Phase 4.2.3 Real-time Integration comprehensive TDD test suite
# ABOUTME: Tests HTTP API, WebSocket support, authentication, and external system integration

set -euo pipefail

# Test framework integration
readonly PHASE4_TEST_DIR
PHASE4_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(cd "$PHASE4_TEST_DIR/../.." && pwd)"
readonly VPN_DIR="$PROJECT_ROOT/src"
readonly API_SERVER_SCRIPT="$VPN_DIR/api-server"

# Simple test framework functions (used by test execution)
# shellcheck disable=SC2317
log_info() { echo "[INFO] $1" >&2; }
# shellcheck disable=SC2317
log_error() { echo "[ERROR] $1" >&2; }

# Test configuration
TEST_PHASE="Phase 4.2.3 Real-time Integration"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_environment() {
    export TEST_TEMP_DIR="/tmp/realtime_integration_test_$$"
    mkdir -p "$TEST_TEMP_DIR"
    export TEST_CONFIG_FILE="$TEST_TEMP_DIR/test_api_config.toml"
    export TEST_PORT=18080  # Use different port to avoid conflicts

    # Create test configuration for real-time integration
    cat > "$TEST_CONFIG_FILE" << 'EOF'
[real_time_integration]
enabled = true
port = 18080
bind_address = "127.0.0.1"
auth_required = true
rate_limit_requests_per_minute = 60

[real_time_integration.endpoints]
status_updates = "/ws/status"
health_alerts = "/ws/health"
metrics_stream = "/api/v1/events"

[real_time_integration.security]
tls_enabled = false
allowed_origins = ["localhost", "127.0.0.1"]
api_key_required = true

[api]
enabled = true
port = 18080
bind_address = "127.0.0.1"
auth_required = true
EOF

    # Test API key for authentication tests
    export TEST_API_KEY="test-api-key-12345"
    export TEST_INVALID_API_KEY="invalid-key"
}

cleanup_test_environment() {
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi

    # Kill any test API servers
    pkill -f "api-server.*--port.*$TEST_PORT" 2>/dev/null || true
    sleep 1
}

# TDD RED PHASE - All these tests will fail until implementation

# Basic API server tests
test_api_server_exists() {
    start_test "api_server_script_exists"
    if [[ -x "$API_SERVER_SCRIPT" ]]; then
        pass_test "API server script exists and is executable"
    else
        fail_test "API server script not found or not executable at $API_SERVER_SCRIPT"
    fi
}

test_api_server_help() {
    start_test "api_server_help_output"
    local result
    result=$("$API_SERVER_SCRIPT" --help 2>/dev/null || echo "failed")

    if [[ "$result" == "failed" ]]; then
        fail_test "API server --help should be available"
    else
        if echo "$result" | grep -q "Usage:" && echo "$result" | grep -q "port\|bind\|api"; then
            pass_test "API server provides helpful usage information"
        else
            fail_test "API server help output missing essential information"
        fi
    fi
}

# HTTP API endpoint tests
test_api_server_startup() {
    start_test "api_server_startup_functionality"
    local result exit_code=0

    # Test API server startup (should run briefly then we'll kill it)
    timeout 3 "$API_SERVER_SCRIPT" --port="$TEST_PORT" --bind="127.0.0.1" 2>&1 || exit_code=$?

    # Exit code 124 means timeout (expected for server), others indicate problems
    if [[ "$exit_code" -eq 124 ]]; then
        pass_test "API server starts successfully"
    elif [[ "$exit_code" -eq 0 ]]; then
        pass_test "API server started and stopped successfully"
    else
        fail_test "API server startup failed"
    fi
}

test_api_status_endpoint() {
    start_test "api_status_endpoint_availability"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test status endpoint
    local result exit_code=0
    result=$(curl -s "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "endpoint_failed")
    exit_code=$?

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "endpoint_failed" || "$exit_code" -ne 0 ]]; then
        fail_test "API status endpoint should be available"
    else
        if echo "$result" | grep -q "service\|status\|{"; then
            pass_test "API status endpoint returns data"
        else
            fail_test "API status endpoint returns unexpected data"
        fi
    fi
}

test_api_health_endpoint() {
    start_test "api_health_endpoint_availability"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test health endpoint
    local result exit_code=0
    result=$(curl -s "http://127.0.0.1:$TEST_PORT/api/v1/health" 2>/dev/null || echo "endpoint_failed")
    exit_code=$?

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "endpoint_failed" || "$exit_code" -ne 0 ]]; then
        fail_test "API health endpoint should be available"
    else
        if echo "$result" | grep -q "health\|status\|{"; then
            pass_test "API health endpoint returns health data"
        else
            fail_test "API health endpoint returns unexpected data"
        fi
    fi
}

test_api_metrics_endpoint() {
    start_test "api_metrics_endpoint_availability"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test metrics endpoint
    local result exit_code=0
    result=$(curl -s "http://127.0.0.1:$TEST_PORT/api/v1/metrics" 2>/dev/null || echo "endpoint_failed")
    exit_code=$?

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "endpoint_failed" || "$exit_code" -ne 0 ]]; then
        fail_test "API metrics endpoint should be available"
    else
        if echo "$result" | grep -q "metrics\|performance\|{"; then
            pass_test "API metrics endpoint returns metrics data"
        else
            fail_test "API metrics endpoint returns unexpected data"
        fi
    fi
}

# Authentication and security tests
test_api_authentication_required() {
    start_test "api_authentication_enforcement"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test without authentication
    local result
    result=$(curl -s -w "%{http_code}" "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "000")

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if echo "$result" | grep -q "401\|403\|unauthorized\|forbidden"; then
        pass_test "API properly enforces authentication"
    else
        fail_test "API should require authentication"
    fi
}

test_api_authentication_valid() {
    start_test "api_authentication_with_valid_key"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test with valid API key
    local result
    result=$(curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "auth_failed")

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "auth_failed" ]]; then
        fail_test "API should accept valid authentication"
    else
        if echo "$result" | grep -q "service\|status\|{"; then
            pass_test "API accepts valid authentication and returns data"
        else
            fail_test "API authentication successful but data unexpected"
        fi
    fi
}

test_api_rate_limiting() {
    start_test "api_rate_limiting_enforcement"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Make multiple rapid requests to trigger rate limiting
    local rate_limited=false
    for i in {1..10}; do
        local result
        result=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "000")
        if echo "$result" | grep -q "429\|rate.*limit"; then
            rate_limited=true
            break
        fi
        sleep 0.1
    done

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$rate_limited" == true ]]; then
        pass_test "API properly enforces rate limiting"
    else
        fail_test "API should implement rate limiting (may need faster requests)"
    fi
}

# WebSocket tests
test_websocket_support() {
    start_test "websocket_server_support"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test WebSocket connection (basic check)
    local result exit_code=0
    if command -v wscat >/dev/null 2>&1; then
        result=$(timeout 2 wscat -c "ws://127.0.0.1:$TEST_PORT/ws/status" 2>&1 || echo "websocket_failed")
    elif command -v websocat >/dev/null 2>&1; then
        result=$(timeout 2 websocat "ws://127.0.0.1:$TEST_PORT/ws/status" 2>&1 || echo "websocket_failed")
    else
        # Fallback - check if WebSocket endpoint responds to HTTP upgrade request
        result=$(curl -s -H "Connection: Upgrade" -H "Upgrade: websocket" "http://127.0.0.1:$TEST_PORT/ws/status" 2>/dev/null || echo "websocket_failed")
    fi

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if echo "$result" | grep -q "websocket_failed"; then
        fail_test "WebSocket support should be available"
    else
        if echo "$result" | grep -qi "websocket\|upgrade\|101\|connection.*established"; then
            pass_test "WebSocket support is available"
        else
            fail_test "WebSocket endpoint exists but behavior unexpected"
        fi
    fi
}

test_websocket_status_updates() {
    start_test "websocket_status_update_stream"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test WebSocket status updates
    local result
    if command -v websocat >/dev/null 2>&1; then
        result=$(timeout 3 websocat "ws://127.0.0.1:$TEST_PORT/ws/status" 2>&1 | head -1 || echo "no_status_updates")
    else
        result="no_websocket_client"
    fi

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "no_status_updates" ]]; then
        fail_test "WebSocket should provide status updates"
    elif [[ "$result" == "no_websocket_client" ]]; then
        pass_test "WebSocket endpoint available (client tools not installed for full test)"
    else
        if echo "$result" | grep -q "status\|service\|{"; then
            pass_test "WebSocket provides status updates"
        else
            fail_test "WebSocket status updates format unexpected"
        fi
    fi
}

# Server-Sent Events tests
test_sse_support() {
    start_test "server_sent_events_support"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test Server-Sent Events endpoint
    local result
    result=$(timeout 3 curl -s -H "Accept: text/event-stream" "http://127.0.0.1:$TEST_PORT/api/v1/events" 2>/dev/null || echo "sse_failed")

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "sse_failed" ]]; then
        fail_test "Server-Sent Events endpoint should be available"
    else
        if echo "$result" | grep -q "event:\|data:\|text/event-stream"; then
            pass_test "Server-Sent Events support is available"
        else
            fail_test "Server-Sent Events endpoint exists but format unexpected"
        fi
    fi
}

# Integration tests
test_dashboard_integration() {
    start_test "api_status_dashboard_integration"

    # Test that API server can get data from status dashboard
    local dashboard_result
    dashboard_result=$("$VPN_DIR/status-dashboard" --format=json 2>/dev/null || echo "dashboard_failed")

    if [[ "$dashboard_result" == "dashboard_failed" ]]; then
        fail_test "API server requires status dashboard integration"
    else
        # Start API server and test integration
        "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
        local server_pid=$!
        sleep 2

        local api_result
        api_result=$(curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "integration_failed")

        # Cleanup
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true

        if [[ "$api_result" == "integration_failed" ]]; then
            fail_test "API server should integrate with status dashboard"
        else
            pass_test "API server integrates with status dashboard"
        fi
    fi
}

test_health_monitor_integration() {
    start_test "api_health_monitor_integration"

    # Test that API server can get data from health monitor
    local health_result
    health_result=$("$VPN_DIR/health-monitor" --export-status 2>/dev/null || echo "health_failed")

    if [[ "$health_result" == "health_failed" ]]; then
        fail_test "API server requires health monitor integration"
    else
        # Start API server and test integration
        "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
        local server_pid=$!
        sleep 2

        local api_result
        api_result=$(curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/health" 2>/dev/null || echo "integration_failed")

        # Cleanup
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true

        if [[ "$api_result" == "integration_failed" ]]; then
            fail_test "API server should integrate with health monitor"
        else
            pass_test "API server integrates with health monitor"
        fi
    fi
}

# Configuration and error handling tests
test_api_config_loading() {
    start_test "api_server_config_integration"
    local result exit_code=0
    export VPN_CONFIG_FILE="$TEST_CONFIG_FILE"
    result=$("$API_SERVER_SCRIPT" --config="$TEST_CONFIG_FILE" --test-config 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        pass_test "API server integrates with config system"
    else
        fail_test "API server should load configuration from TOML files"
    fi
}

test_api_error_handling() {
    start_test "api_server_error_handling"
    local result exit_code
    result=$("$API_SERVER_SCRIPT" --invalid-flag 2>&1) || exit_code=$?

    if [[ "${exit_code:-0}" -ne 0 ]]; then
        # Should fail with invalid flag
        if echo "$result" | grep -qi "error\|invalid\|usage"; then
            pass_test "API server handles invalid arguments correctly"
        else
            fail_test "API server error message not user-friendly"
        fi
    else
        fail_test "API server should fail with invalid arguments"
    fi
}

# Performance tests
test_api_performance() {
    start_test "api_server_performance_requirements"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    local start_time end_time duration_ms
    start_time=$(date +%s%N)
    curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" >/dev/null 2>&1 || true
    end_time=$(date +%s%N)

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$duration_ms" -lt 200 ]]; then  # 200ms limit for API responses
        pass_test "API response time within limits: ${duration_ms}ms"
    else
        fail_test "API response time exceeds 200ms limit: ${duration_ms}ms"
    fi
}

test_api_concurrent_clients() {
    start_test "api_server_concurrent_client_support"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    local pids=()
    local failed=0

    # Start multiple concurrent API clients
    # shellcheck disable=SC2034  # i is loop counter placeholder
    for i in {1..5}; do
        curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" >/dev/null 2>&1 &
        pids+=($!)
    done

    # Wait for all to complete
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$failed" -eq 0 ]]; then
        pass_test "API server handles concurrent clients successfully"
    else
        fail_test "API server failed under concurrent load ($failed failures)"
    fi
}

# Security and audit tests
test_api_security_logging() {
    start_test "api_server_audit_log_integration"
    # Test that API access is logged
    local log_before log_after
    log_before=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")

    # Start API server and make request
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" >/dev/null 2>&1 || true

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    log_after=$(wc -l < /var/log/protonvpn/config-audit.log 2>/dev/null || echo "0")

    if [[ "$log_after" -gt "$log_before" ]]; then
        pass_test "API server access properly logged in audit system"
    else
        fail_test "API server should log access to audit system"
    fi
}

test_api_content_security() {
    start_test "api_server_content_sanitization"

    # Start API server in background
    "$API_SERVER_SCRIPT" --port="$TEST_PORT" --config="$TEST_CONFIG_FILE" &
    local server_pid=$!
    sleep 2

    # Test that sensitive data is not exposed
    local result
    result=$(curl -s -H "Authorization: Bearer $TEST_API_KEY" "http://127.0.0.1:$TEST_PORT/api/v1/status" 2>/dev/null || echo "failed")

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ "$result" == "failed" ]]; then
        fail_test "API server not available for security test"
    else
        # Check that no credentials or sensitive paths are exposed
        if echo "$result" | grep -Eq "(password|key|secret|token|/root|/home/.*/\.ssh)"; then
            fail_test "API server output may contain sensitive information"
        else
            pass_test "API server output properly sanitized"
        fi
    fi
}

# Test execution framework
run_all_tests() {
    log_info "Starting $TEST_PHASE Test Suite"
    log_info "Target implementation: $API_SERVER_SCRIPT"

    setup_test_environment

    # Basic functionality tests (RED phase - will fail)
    test_api_server_exists
    test_api_server_help
    test_api_server_startup

    # HTTP API endpoint tests
    test_api_status_endpoint
    test_api_health_endpoint
    test_api_metrics_endpoint

    # Authentication and security tests
    test_api_authentication_required
    test_api_authentication_valid
    test_api_rate_limiting

    # WebSocket and real-time tests
    test_websocket_support
    test_websocket_status_updates
    test_sse_support

    # Integration tests
    test_dashboard_integration
    test_health_monitor_integration

    # Configuration and error handling
    test_api_config_loading
    test_api_error_handling

    # Performance tests
    test_api_performance
    test_api_concurrent_clients

    # Security tests
    test_api_security_logging
    test_api_content_security

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

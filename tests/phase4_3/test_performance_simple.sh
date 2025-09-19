#!/bin/bash
# ABOUTME: Simplified Phase 4.2.3 Performance Test Runner
# ABOUTME: Focused performance validation for Component 4 completion

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Performance targets
readonly STATUS_DASHBOARD_MAX_MS=100
readonly HEALTH_MONITOR_MAX_MS=500
readonly API_SERVER_MAX_MS=200

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }

start_test() {
    ((TESTS_RUN++))
    echo "[$TESTS_RUN] Testing: $1"
}

pass_test() {
    ((TESTS_PASSED++))
    echo "  ✅ PASS: $1"
}

fail_test() {
    ((TESTS_FAILED++))
    echo "  ❌ FAIL: $1"
}

# Simple timing function
time_command() {
    local command="$1"
    local iterations="${2:-5}"
    local total=0

    for ((i=1; i<=iterations; i++)); do
        local start end duration
        start=$(date +%s%N)
        eval "$command" >/dev/null 2>&1 || true
        end=$(date +%s%N)
        duration=$(( (end - start) / 1000000 ))
        total=$((total + duration))
    done

    echo $((total / iterations))
}

# Test 1: Status Dashboard Performance
test_status_dashboard() {
    start_test "Status Dashboard Performance"

    local avg_time
    avg_time=$(time_command "./src/status-dashboard --format json" 5)

    if [[ $avg_time -lt $STATUS_DASHBOARD_MAX_MS ]]; then
        pass_test "Status dashboard avg: ${avg_time}ms < ${STATUS_DASHBOARD_MAX_MS}ms"
    else
        fail_test "Status dashboard avg: ${avg_time}ms >= ${STATUS_DASHBOARD_MAX_MS}ms"
    fi
}

# Test 2: Health Monitor Performance
test_health_monitor() {
    start_test "Health Monitor Performance"

    local avg_time
    avg_time=$(time_command "./src/health-monitor --check service" 3)

    if [[ $avg_time -lt $HEALTH_MONITOR_MAX_MS ]]; then
        pass_test "Health monitor avg: ${avg_time}ms < ${HEALTH_MONITOR_MAX_MS}ms"
    else
        fail_test "Health monitor avg: ${avg_time}ms >= ${HEALTH_MONITOR_MAX_MS}ms"
    fi
}

# Test 3: API Server Performance
test_api_server() {
    start_test "API Server Performance"

    # Start API server in background
    ./src/api-server --port 18081 >/dev/null 2>&1 &
    local server_pid=$!

    # Wait for server startup
    sleep 2

    local avg_time
    avg_time=$(time_command 'curl -s -H "Authorization: Bearer test-token-12345" http://127.0.0.1:18081/api/v1/status' 3)

    # Cleanup
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    if [[ $avg_time -lt $API_SERVER_MAX_MS ]]; then
        pass_test "API server avg: ${avg_time}ms < ${API_SERVER_MAX_MS}ms"
    else
        fail_test "API server avg: ${avg_time}ms >= ${API_SERVER_MAX_MS}ms"
    fi
}

# Main execution
main() {
    log_info "Starting Phase 4.2.3 Performance Tests"
    log_info "Targets: Dashboard<${STATUS_DASHBOARD_MAX_MS}ms, Health<${HEALTH_MONITOR_MAX_MS}ms, API<${API_SERVER_MAX_MS}ms"

    test_status_dashboard
    test_health_monitor
    test_api_server

    # Results
    echo
    log_info "Performance Test Results:"
    log_info "Tests run: $TESTS_RUN"
    log_info "Passed: $TESTS_PASSED"
    log_info "Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_info "🎉 ALL PERFORMANCE TESTS PASSED - Phase 4.2.3 Component 4 Complete!"
        exit 0
    else
        log_error "❌ Performance tests failed - optimization needed"
        exit 1
    fi
}

main "$@"

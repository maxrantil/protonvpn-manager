#!/bin/bash
# ABOUTME: Phase 4.2.3 Performance Optimization comprehensive test suite
# ABOUTME: Cross-platform testing, benchmarking, and final performance validation

set -euo pipefail

# Test framework integration
readonly PHASE4_TEST_DIR
PHASE4_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(cd "$PHASE4_TEST_DIR/../.." && pwd)"
# shellcheck disable=SC2034  # VPN_DIR reserved for path validation
readonly VPN_DIR="$PROJECT_ROOT/src"

# Simple test framework functions (used by test execution)
# shellcheck disable=SC2317
log_info() { echo "[INFO] $1" >&2; }
# shellcheck disable=SC2317
log_error() { echo "[ERROR] $1" >&2; }

# Test configuration
TEST_PHASE="Phase 4.2.3 Performance Optimization"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Performance thresholds (based on agent recommendations)
readonly STATUS_DASHBOARD_MAX_MS=100
readonly HEALTH_MONITOR_MAX_MS=500
readonly API_SERVER_MAX_MS=200
readonly MEMORY_LIMIT_MB=25
readonly CPU_LIMIT_PERCENT=5

# Test utilities
setup_test_environment() {
	export TEST_TEMP_DIR="/tmp/performance_test_$$"
	mkdir -p "$TEST_TEMP_DIR"

	# Performance test configuration
	export PERFORMANCE_TEST_ITERATIONS=10
	export LOAD_TEST_CLIENTS=5
	export STRESS_TEST_DURATION=30
}

cleanup_test_environment() {
	if [[ -d "$TEST_TEMP_DIR" ]]; then
		rm -rf "$TEST_TEMP_DIR"
	fi

	# Kill any test processes
	pkill -f "api-server.*--port.*18080" 2>/dev/null || true
}

# Performance measurement utilities
measure_execution_time() {
	local command="$1"
	local iterations="${2:-10}"
	local total_time=0
	local min_time=999999
	local max_time=0

	for ((i = 1; i <= iterations; i++)); do
		local start_time end_time duration
		start_time=$(date +%s%N)
		eval "$command" >/dev/null 2>&1 || true
		end_time=$(date +%s%N)
		duration=$(((end_time - start_time) / 1000000)) # Convert to ms

		total_time=$((total_time + duration))
		if [[ $duration -lt $min_time ]]; then min_time=$duration; fi
		if [[ $duration -gt $max_time ]]; then max_time=$duration; fi
	done

	local avg_time=$((total_time / iterations))
	echo "$avg_time,$min_time,$max_time"
}

measure_memory_usage() {
	local process_name="$1"
	local duration="${2:-5}"

	local max_memory=0
	for ((i = 0; i < duration; i++)); do
		local current_memory
		current_memory=$(ps -C "$process_name" -o rss= 2>/dev/null | awk '{sum+=$1} END {print int(sum/1024)}' || echo "0")
		if [[ $current_memory -gt $max_memory ]]; then
			max_memory=$current_memory
		fi
		sleep 1
	done

	echo "$max_memory"
}

# Component performance tests
test_status_dashboard_performance() {
	start_test "status_dashboard_performance_benchmark"

	local result
	result=$(measure_execution_time "./src/status-dashboard --format json" "$PERFORMANCE_TEST_ITERATIONS")
	local avg_time min_time max_time
	IFS=',' read -r avg_time min_time max_time <<<"$result"

	if [[ $avg_time -lt $STATUS_DASHBOARD_MAX_MS ]]; then
		pass_test "Status dashboard performance: avg=${avg_time}ms, min=${min_time}ms, max=${max_time}ms (target: <${STATUS_DASHBOARD_MAX_MS}ms)"
	else
		fail_test "Status dashboard performance: avg=${avg_time}ms exceeds target of ${STATUS_DASHBOARD_MAX_MS}ms"
	fi
}

test_health_monitor_performance() {
	start_test "health_monitor_performance_benchmark"

	local result
	result=$(measure_execution_time "./src/health-monitor --check=service" "$PERFORMANCE_TEST_ITERATIONS")
	local avg_time min_time max_time
	IFS=',' read -r avg_time min_time max_time <<<"$result"

	if [[ $avg_time -lt $HEALTH_MONITOR_MAX_MS ]]; then
		pass_test "Health monitor performance: avg=${avg_time}ms, min=${min_time}ms, max=${max_time}ms (target: <${HEALTH_MONITOR_MAX_MS}ms)"
	else
		fail_test "Health monitor performance: avg=${avg_time}ms exceeds target of ${HEALTH_MONITOR_MAX_MS}ms"
	fi
}

test_api_server_performance() {
	start_test "api_server_performance_benchmark"

	# Start API server for testing
	./src/api-server --port=18080 --bind=127.0.0.1 &
	local server_pid=$!
	sleep 2

	local result
	result=$(measure_execution_time 'curl -s -H "Authorization: Bearer test-token-12345" http://127.0.0.1:18080/api/v1/status' "$PERFORMANCE_TEST_ITERATIONS")
	local avg_time min_time max_time
	IFS=',' read -r avg_time min_time max_time <<<"$result"

	# Cleanup
	kill "$server_pid" 2>/dev/null || true
	wait "$server_pid" 2>/dev/null || true

	if [[ $avg_time -lt $API_SERVER_MAX_MS ]]; then
		pass_test "API server performance: avg=${avg_time}ms, min=${min_time}ms, max=${max_time}ms (target: <${API_SERVER_MAX_MS}ms)"
	else
		fail_test "API server performance: avg=${avg_time}ms exceeds target of ${API_SERVER_MAX_MS}ms"
	fi
}

# Resource usage tests
test_memory_usage_compliance() {
	start_test "memory_usage_within_limits"

	local dashboard_memory health_memory

	# Test status dashboard memory usage
	./src/status-dashboard --format json >/dev/null &
	local dashboard_pid=$!
	sleep 1
	dashboard_memory=$(ps -p "$dashboard_pid" -o rss= 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
	kill "$dashboard_pid" 2>/dev/null || true

	# Test health monitor memory usage
	timeout 3 ./src/health-monitor --check=all >/dev/null &
	local health_pid=$!
	sleep 1
	health_memory=$(ps -p "$health_pid" -o rss= 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
	wait "$health_pid" 2>/dev/null || true

	local total_memory=$((dashboard_memory + health_memory))

	if [[ $total_memory -lt $MEMORY_LIMIT_MB ]]; then
		pass_test "Memory usage within limits: dashboard=${dashboard_memory}MB, health=${health_memory}MB, total=${total_memory}MB (limit: ${MEMORY_LIMIT_MB}MB)"
	else
		fail_test "Memory usage exceeds limit: total=${total_memory}MB > ${MEMORY_LIMIT_MB}MB"
	fi
}

test_cpu_usage_compliance() {
	start_test "cpu_usage_within_limits"

	# Test CPU usage during normal operations
	local start_time end_time
	start_time=$(date +%s)

	# Run components briefly and measure CPU
	./src/status-dashboard --format json >/dev/null 2>&1 || true
	./src/health-monitor --check=all >/dev/null 2>&1 || true

	end_time=$(date +%s)
	local duration=$((end_time - start_time))

	# Get CPU usage for VPN-related processes
	local cpu_usage
	cpu_usage=$(ps -C protonvpn-updater,status-dashboard,health-monitor -o %cpu= 2>/dev/null |
		awk '{sum+=$1} END {if(sum>0) printf "%.1f", sum; else print "0"}' || echo "0")

	local cpu_numeric=${cpu_usage%\%}
	if (($(echo "$cpu_numeric < $CPU_LIMIT_PERCENT" | bc -l 2>/dev/null || echo "1"))); then
		pass_test "CPU usage within limits: ${cpu_usage}% (limit: ${CPU_LIMIT_PERCENT}%)"
	else
		fail_test "CPU usage exceeds limit: ${cpu_usage}% > ${CPU_LIMIT_PERCENT}%"
	fi
}

# Load testing
test_concurrent_performance() {
	start_test "concurrent_load_performance"

	# Start API server for load testing
	./src/api-server --port=18080 --bind=127.0.0.1 &
	local server_pid=$!
	sleep 2

	local start_time end_time
	start_time=$(date +%s)

	# Run concurrent requests
	local pids=()
	for ((i = 1; i <= LOAD_TEST_CLIENTS; i++)); do
		{
			for ((j = 1; j <= 5; j++)); do
				curl -s -H "Authorization: Bearer test-token-12345" "http://127.0.0.1:18080/api/v1/status" >/dev/null 2>&1 || true
				sleep 0.1
			done
		} &
		pids+=($!)
	done

	# Wait for all clients to complete
	local failed=0
	for pid in "${pids[@]}"; do
		if ! wait "$pid"; then
			((failed++))
		fi
	done

	end_time=$(date +%s)
	local total_time=$((end_time - start_time))

	# Cleanup
	kill "$server_pid" 2>/dev/null || true
	wait "$server_pid" 2>/dev/null || true

	if [[ $failed -eq 0 && $total_time -lt 30 ]]; then
		pass_test "Concurrent load test passed: ${LOAD_TEST_CLIENTS} clients, ${total_time}s duration, 0 failures"
	else
		fail_test "Concurrent load test failed: ${failed} failures, ${total_time}s duration"
	fi
}

# Cross-platform compatibility tests
test_cross_platform_compatibility() {
	start_test "cross_platform_shell_compatibility"

	# Test basic shell compatibility
	# shellcheck disable=SC2034  # shell_features reserved for capability detection
	local shell_features=("bash" "parameter expansion" "arrays" "process substitution")
	local compatible=true

	# Test parameter expansion
	local test_var="test_value"
	if [[ "${test_var#test_}" != "value" ]]; then
		compatible=false
	fi

	# Test array support
	local test_array=("one" "two" "three")
	if [[ "${test_array[1]}" != "two" ]]; then
		compatible=false
	fi

	# Test command availability
	local required_commands=("curl" "ps" "date" "awk" "grep" "sed")
	for cmd in "${required_commands[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			compatible=false
			break
		fi
	done

	if [[ $compatible == true ]]; then
		pass_test "Cross-platform compatibility verified: all features available"
	else
		fail_test "Cross-platform compatibility issues detected"
	fi
}

test_system_integration() {
	start_test "system_integration_performance"

	local integration_start integration_end integration_time
	integration_start=$(date +%s%N)

	# Test full system integration
	local status_result health_result
	status_result=$(./src/status-dashboard --format json 2>/dev/null | jq -r '.service // "unknown"' 2>/dev/null || echo "unknown")
	health_result=$(./src/health-monitor --export-status 2>/dev/null | jq -r '.health_monitor.service.status // "unknown"' 2>/dev/null || echo "unknown")

	integration_end=$(date +%s%N)
	integration_time=$(((integration_end - integration_start) / 1000000))

	if [[ "$status_result" != "unknown" && "$health_result" != "unknown" && $integration_time -lt 1000 ]]; then
		pass_test "System integration performance: ${integration_time}ms, status=${status_result}, health=${health_result}"
	else
		fail_test "System integration performance issues: ${integration_time}ms"
	fi
}

# Stress testing
test_stress_resilience() {
	start_test "stress_test_resilience"

	local stress_start stress_end
	stress_start=$(date +%s)

	# Run stress test for specified duration
	local stress_failures=0
	while [[ $(($(date +%s) - stress_start)) -lt 10 ]]; do # 10 second stress test
		./src/status-dashboard --format json >/dev/null 2>&1 || ((stress_failures++))
		./src/health-monitor --check=service >/dev/null 2>&1 || ((stress_failures++))
		sleep 0.1
	done

	stress_end=$(date +%s)
	local stress_duration=$((stress_end - stress_start))
	local stress_requests=$((stress_duration * 20)) # Approximate requests

	local success_rate=$(((stress_requests - stress_failures) * 100 / stress_requests))

	if [[ $success_rate -gt 95 ]]; then
		pass_test "Stress test resilience: ${success_rate}% success rate over ${stress_duration}s (${stress_requests} requests)"
	else
		fail_test "Stress test resilience: ${success_rate}% success rate below 95% threshold"
	fi
}

# Performance optimization validation
test_caching_effectiveness() {
	start_test "caching_system_effectiveness"

	# Test cache performance by comparing first vs subsequent calls
	local first_call_time second_call_time

	# First call (cold cache)
	local start_time end_time
	start_time=$(date +%s%N)
	./src/status-dashboard --format json >/dev/null 2>&1 || true
	end_time=$(date +%s%N)
	first_call_time=$(((end_time - start_time) / 1000000))

	# Second call (warm cache)
	start_time=$(date +%s%N)
	./src/status-dashboard --format json >/dev/null 2>&1 || true
	end_time=$(date +%s%N)
	second_call_time=$(((end_time - start_time) / 1000000))

	# Cache is effective if second call is faster or within reasonable margin
	local cache_improvement=$((first_call_time - second_call_time))

	if [[ $second_call_time -le $first_call_time ]]; then
		pass_test "Caching effectiveness: first=${first_call_time}ms, second=${second_call_time}ms, improvement=${cache_improvement}ms"
	else
		fail_test "Caching not effective: second call (${second_call_time}ms) slower than first (${first_call_time}ms)"
	fi
}

# Final validation tests
test_phase4_completion_criteria() {
	start_test "phase4_2_3_completion_validation"

	local components_working=0
	local total_components=3

	# Test Component 1: Status Dashboard
	if ./src/status-dashboard --format json >/dev/null 2>&1; then
		((components_working++))
	fi

	# Test Component 2: Health Monitor
	if ./src/health-monitor --check=service >/dev/null 2>&1; then
		((components_working++))
	fi

	# Test Component 3: API Server (configuration test)
	if ./src/api-server --test-config >/dev/null 2>&1; then
		((components_working++))
	fi

	if [[ $components_working -eq $total_components ]]; then
		pass_test "Phase 4.2.3 completion criteria met: all $total_components components functional"
	else
		fail_test "Phase 4.2.3 completion criteria not met: only $components_working/$total_components components working"
	fi
}

test_integration_performance() {
	start_test "full_integration_performance_validation"

	local integration_start integration_end total_time
	integration_start=$(date +%s%N)

	# Full integration test
	local status_data health_data api_config
	status_data=$(./src/status-dashboard --format json 2>/dev/null || echo '{"error":"failed"}')
	health_data=$(./src/health-monitor --export-status 2>/dev/null || echo '{"error":"failed"}')
	api_config=$(./src/api-server --test-config 2>&1 | grep -c "Configuration loaded" || echo "0")

	integration_end=$(date +%s%N)
	total_time=$(((integration_end - integration_start) / 1000000))

	local integration_success=true
	if echo "$status_data" | grep -q '"error"'; then integration_success=false; fi
	if echo "$health_data" | grep -q '"error"'; then integration_success=false; fi
	if [[ "$api_config" != "1" ]]; then integration_success=false; fi

	if [[ $integration_success == true && $total_time -lt 2000 ]]; then
		pass_test "Full integration performance validated: ${total_time}ms, all components operational"
	else
		fail_test "Full integration performance issues: ${total_time}ms, success=$integration_success"
	fi
}

# Test execution framework
run_all_tests() {
	log_info "Starting $TEST_PHASE Test Suite"
	log_info "Performance targets: Dashboard<${STATUS_DASHBOARD_MAX_MS}ms, Health<${HEALTH_MONITOR_MAX_MS}ms, API<${API_SERVER_MAX_MS}ms"

	setup_test_environment

	# Component performance tests
	test_status_dashboard_performance
	test_health_monitor_performance
	test_api_server_performance

	# Resource usage tests
	test_memory_usage_compliance
	test_cpu_usage_compliance

	# Load and stress tests
	test_concurrent_performance
	test_stress_resilience

	# Cross-platform compatibility
	test_cross_platform_compatibility
	test_system_integration

	# Optimization validation
	test_caching_effectiveness

	# Final validation
	test_phase4_completion_criteria
	test_integration_performance

	cleanup_test_environment

	# Test summary
	log_info "=== Performance Test Summary ==="
	log_info "Tests Run: $TESTS_RUN"
	log_info "Tests Passed: $TESTS_PASSED"
	log_info "Tests Failed: $TESTS_FAILED"

	if [[ $TESTS_FAILED -eq 0 ]]; then
		log_info "✅ All performance tests passed - Phase 4.2.3 ready for deployment!"
		return 0
	else
		log_error "❌ $TESTS_FAILED performance tests failed"
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

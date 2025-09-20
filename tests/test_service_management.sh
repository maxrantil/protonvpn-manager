#!/bin/bash
# ABOUTME: Service management testing for ProtonVPN system
# ABOUTME: Tests service lifecycle, dependency handling, and reliability

set -euo pipefail

# Test framework setup
TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Test configuration
TEST_SERVICE_DIR="/tmp/test-services-$$"
TEST_LOG_DIR="/tmp/test-logs-$$"
mkdir -p "$TEST_SERVICE_DIR" "$TEST_LOG_DIR"

# Mock systemctl for testing
MOCK_SYSTEMCTL_DIR="/tmp/mock-systemctl-$$"
mkdir -p "$MOCK_SYSTEMCTL_DIR"

# Test results tracking
SERVICE_TESTS_PASSED=0
SERVICE_TESTS_FAILED=0
SERVICE_FAILED_TESTS=()

log_service_test() {
    local status="$1"
    local message="$2"
    echo "[$status] SERVICE: $message"

    if [[ "$status" == "PASS" ]]; then
        ((SERVICE_TESTS_PASSED++))
    elif [[ "$status" == "FAIL" ]]; then
        ((SERVICE_TESTS_FAILED++))
        SERVICE_FAILED_TESTS+=("$message")
    fi
}

# Cleanup function
cleanup_service_test() {
    rm -rf "$TEST_SERVICE_DIR" "$TEST_LOG_DIR" "$MOCK_SYSTEMCTL_DIR"
}
trap cleanup_service_test EXIT

# Create mock systemctl for non-privileged testing
create_mock_systemctl() {
    cat > "$MOCK_SYSTEMCTL_DIR/systemctl" << 'EOF'
#!/bin/bash
# Mock systemctl for testing

case "$1" in
    "is-active")
        case "$2" in
            "protonvpn.target"|"protonvpn-daemon")
                echo "active"
                exit 0
                ;;
            "failing-service")
                echo "inactive"
                exit 1
                ;;
            *)
                echo "unknown"
                exit 3
                ;;
        esac
        ;;
    "is-enabled")
        case "$2" in
            "protonvpn.target"|"protonvpn-daemon")
                echo "enabled"
                exit 0
                ;;
            *)
                echo "disabled"
                exit 1
                ;;
        esac
        ;;
    "start"|"stop"|"restart")
        echo "Mock: $1 $2"
        exit 0
        ;;
    "status")
        case "$2" in
            "protonvpn.target")
                echo "● protonvpn.target - ProtonVPN Services"
                echo "   Loaded: loaded"
                echo "   Active: active (running)"
                exit 0
                ;;
            *)
                echo "● $2 - Mock Service"
                echo "   Loaded: loaded"
                echo "   Active: active (running)"
                exit 0
                ;;
        esac
        ;;
    "enable"|"disable")
        echo "Mock: $1 $2"
        exit 0
        ;;
    "daemon-reload")
        echo "Mock: daemon-reload"
        exit 0
        ;;
    *)
        echo "Mock systemctl: unknown command $1"
        exit 1
        ;;
esac
EOF

    chmod +x "$MOCK_SYSTEMCTL_DIR/systemctl"
    export PATH="$MOCK_SYSTEMCTL_DIR:$PATH"
}

# Test 1: Service Status Checking
test_service_status_checking() {
    echo "=== Service Test: Status Checking ==="

    create_mock_systemctl

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Create test environment variables
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"

    # Test status checking for all services
    if bash -c "source '$service_manager'; service_status all" > "$TEST_LOG_DIR/status_test.log" 2>&1; then
        if grep -q "protonvpn.target" "$TEST_LOG_DIR/status_test.log"; then
            log_service_test "PASS" "Service status checking works"
        else
            log_service_test "FAIL" "Service status output missing target info"
        fi
    else
        log_service_test "FAIL" "Service status checking failed"
    fi
}

# Test 2: Service Start/Stop Operations
test_service_lifecycle() {
    echo "=== Service Test: Lifecycle Operations ==="

    create_mock_systemctl

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    mkdir -p "$VPN_LOG_DIR" "$VPN_RUN_DIR"
    touch "$VPN_LOG_DIR/service-manager.log"

    local lifecycle_ok=true

    # Test start operation
    if bash -c "source '$service_manager'; start_services all" > "$TEST_LOG_DIR/start_test.log" 2>&1; then
        if grep -q "Starting all ProtonVPN services" "$TEST_LOG_DIR/start_test.log"; then
            echo "  GOOD: Start operation initiated"
        else
            echo "  WARNING: Start operation output unexpected"
            lifecycle_ok=false
        fi
    else
        echo "  WARNING: Start operation failed"
        lifecycle_ok=false
    fi

    # Test stop operation
    if bash -c "source '$service_manager'; stop_services all" > "$TEST_LOG_DIR/stop_test.log" 2>&1; then
        if grep -q "Stopping all ProtonVPN services" "$TEST_LOG_DIR/stop_test.log"; then
            echo "  GOOD: Stop operation initiated"
        else
            echo "  WARNING: Stop operation output unexpected"
            lifecycle_ok=false
        fi
    else
        echo "  WARNING: Stop operation failed"
        lifecycle_ok=false
    fi

    if [[ "$lifecycle_ok" == "true" ]]; then
        log_service_test "PASS" "Service lifecycle operations work"
    else
        log_service_test "FAIL" "Service lifecycle operations have issues"
    fi
}

# Test 3: Individual Service Management
test_individual_service_management() {
    echo "=== Service Test: Individual Service Management ==="

    create_mock_systemctl

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    mkdir -p "$VPN_LOG_DIR" "$VPN_RUN_DIR"
    touch "$VPN_LOG_DIR/service-manager.log"

    local individual_ok=true

    # Test individual service operations
    local test_service="protonvpn-daemon"

    # Test start individual service
    if bash -c "source '$service_manager'; start_services '$test_service'" > "$TEST_LOG_DIR/individual_start.log" 2>&1; then
        if grep -q "Starting service: $test_service" "$TEST_LOG_DIR/individual_start.log"; then
            echo "  GOOD: Individual service start works"
        else
            echo "  WARNING: Individual service start output unexpected"
            individual_ok=false
        fi
    else
        echo "  WARNING: Individual service start failed"
        individual_ok=false
    fi

    # Test stop individual service
    if bash -c "source '$service_manager'; stop_services '$test_service'" > "$TEST_LOG_DIR/individual_stop.log" 2>&1; then
        if grep -q "Stopping service: $test_service" "$TEST_LOG_DIR/individual_stop.log"; then
            echo "  GOOD: Individual service stop works"
        else
            echo "  WARNING: Individual service stop output unexpected"
            individual_ok=false
        fi
    else
        echo "  WARNING: Individual service stop failed"
        individual_ok=false
    fi

    if [[ "$individual_ok" == "true" ]]; then
        log_service_test "PASS" "Individual service management works"
    else
        log_service_test "FAIL" "Individual service management has issues"
    fi
}

# Test 4: Health Check Functionality
test_health_check() {
    echo "=== Service Test: Health Check Functionality ==="

    create_mock_systemctl

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    export VPN_CONFIG_DIR="$TEST_SERVICE_DIR/config"
    mkdir -p "$VPN_LOG_DIR" "$VPN_RUN_DIR" "$VPN_CONFIG_DIR"
    touch "$VPN_LOG_DIR/service-manager.log"

    # Test health check
    if bash -c "source '$service_manager'; health_check" > "$TEST_LOG_DIR/health_test.log" 2>&1; then
        if grep -q "Health check" "$TEST_LOG_DIR/health_test.log"; then
            log_service_test "PASS" "Health check functionality works"
        else
            log_service_test "FAIL" "Health check output unexpected"
        fi
    else
        log_service_test "FAIL" "Health check functionality failed"
    fi
}

# Test 5: Log Management
test_log_management() {
    echo "=== Service Test: Log Management ==="

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    mkdir -p "$VPN_LOG_DIR" "$VPN_RUN_DIR"

    # Test log initialization
    if bash -c "source '$service_manager'; init_directories" > /dev/null 2>&1; then
        if [[ -f "$VPN_LOG_DIR/service-manager.log" ]]; then
            log_service_test "PASS" "Log file creation works"
        else
            log_service_test "FAIL" "Log file not created"
        fi
    else
        log_service_test "FAIL" "Log initialization failed"
    fi

    # Test log rotation setup
    local rotation_config="/tmp/test-logrotate-$$"
    if bash -c "source '$service_manager'; setup_log_rotation" > /dev/null 2>&1; then
        if [[ -f "/etc/logrotate.d/protonvpn" ]]; then
            log_service_test "PASS" "Log rotation setup works"
        else
            log_service_test "WARN" "Log rotation requires root privileges (expected in test)"
        fi
    else
        log_service_test "WARN" "Log rotation setup failed (expected without root)"
    fi
}

# Test 6: Error Handling
test_error_handling() {
    echo "=== Service Test: Error Handling ==="

    # Create mock systemctl that simulates failures
    cat > "$MOCK_SYSTEMCTL_DIR/systemctl" << 'EOF'
#!/bin/bash
# Mock systemctl that fails for testing

case "$1 $2" in
    "start failing-service")
        echo "Failed to start failing-service.service"
        exit 1
        ;;
    "is-active failing-service")
        echo "failed"
        exit 3
        ;;
    *)
        echo "Mock: $*"
        exit 0
        ;;
esac
EOF

    chmod +x "$MOCK_SYSTEMCTL_DIR/systemctl"

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    mkdir -p "$VPN_LOG_DIR" "$VPN_RUN_DIR"
    touch "$VPN_LOG_DIR/service-manager.log"

    # Test error handling for invalid service
    if bash -c "source '$service_manager'; validate_service_name 'invalid-service'" > /dev/null 2>&1; then
        log_service_test "FAIL" "Should reject invalid service names"
    else
        log_service_test "PASS" "Invalid service name properly rejected"
    fi

    # Test error handling for empty service name
    if bash -c "source '$service_manager'; validate_service_name ''" > /dev/null 2>&1; then
        log_service_test "FAIL" "Should reject empty service name"
    else
        log_service_test "PASS" "Empty service name properly rejected"
    fi
}

# Test 7: Directory and Permission Management
test_directory_management() {
    echo "=== Service Test: Directory Management ==="

    local service_manager="$PROJECT_DIR/scripts/protonvpn-service-manager"

    # Set up test environment
    export VPN_LOG_DIR="$TEST_LOG_DIR"
    export VPN_RUN_DIR="$TEST_SERVICE_DIR"
    export VPN_USER="$(whoami)"
    export VPN_GROUP="$(id -gn)"

    # Test directory initialization
    if bash -c "source '$service_manager'; init_directories" > /dev/null 2>&1; then
        local dirs_ok=true

        # Check if directories exist
        if [[ ! -d "$VPN_LOG_DIR" ]]; then
            echo "  WARNING: Log directory not created"
            dirs_ok=false
        fi

        if [[ ! -d "$VPN_RUN_DIR" ]]; then
            echo "  WARNING: Run directory not created"
            dirs_ok=false
        fi

        if [[ "$dirs_ok" == "true" ]]; then
            log_service_test "PASS" "Directory management works"
        else
            log_service_test "FAIL" "Directory management issues"
        fi
    else
        log_service_test "FAIL" "Directory initialization failed"
    fi
}

# Test 8: Service Dependency Validation
test_service_dependencies() {
    echo "=== Service Test: Service Dependencies ==="

    local service_file="$PROJECT_DIR/systemd/protonvpn-daemon.service"

    if [[ ! -f "$service_file" ]]; then
        log_service_test "FAIL" "Service file not found for dependency check"
        return
    fi

    # Check for proper dependencies
    local deps_ok=true

    if ! grep -q "After=network-online.target" "$service_file"; then
        echo "  WARNING: Missing network dependency"
        deps_ok=false
    else
        echo "  GOOD: Network dependency present"
    fi

    if ! grep -q "Wants=network-online.target" "$service_file"; then
        echo "  WARNING: Missing network wants declaration"
        deps_ok=false
    else
        echo "  GOOD: Network wants declaration present"
    fi

    if [[ "$deps_ok" == "true" ]]; then
        log_service_test "PASS" "Service dependencies properly configured"
    else
        log_service_test "FAIL" "Service dependency issues"
    fi
}

# Main service test execution
main() {
    echo "Starting Service Management Tests"
    echo "================================"

    test_service_status_checking
    test_service_lifecycle
    test_individual_service_management
    test_health_check
    test_log_management
    test_error_handling
    test_directory_management
    test_service_dependencies

    echo ""
    echo "Service Management Test Summary:"
    echo "==============================="
    echo "Passed: $SERVICE_TESTS_PASSED"
    echo "Failed: $SERVICE_TESTS_FAILED"

    if [[ $SERVICE_TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "Failed Service Tests:"
        for test in "${SERVICE_FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
        echo "⚠️  Service management issues detected!"
        exit 1
    else
        echo ""
        echo "✅ All service management tests passed!"
        exit 0
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

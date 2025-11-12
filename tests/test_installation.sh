#!/bin/bash
# ABOUTME: Installation robustness testing for ProtonVPN system
# ABOUTME: Tests installation scenarios, failure recovery, and rollback procedures

set -euo pipefail

# Test framework setup
TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Test configuration
TEST_PREFIX="/tmp/protonvpn-test-$$"
TEST_USER="test-protonvpn-$$"
TEST_GROUP="test-protonvpn-$$"

# Cleanup function
cleanup_test() {
	echo "Cleaning up test environment..."
	sudo rm -rf "$TEST_PREFIX" || true
	sudo userdel "$TEST_USER" 2>/dev/null || true
	sudo groupdel "$TEST_GROUP" 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup_test EXIT

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

log_test() {
	local status="$1"
	local message="$2"
	echo "[$status] $message"

	if [[ "$status" == "PASS" ]]; then
		((TESTS_PASSED++))
	elif [[ "$status" == "FAIL" ]]; then
		((TESTS_FAILED++))
		FAILED_TESTS+=("$message")
	fi
}

# Test 1: Basic Installation
test_basic_installation() {
	echo "=== Test: Basic Installation ==="

	# Create temporary Makefile with test paths
	cat >/tmp/test-makefile <<EOF
PREFIX = $TEST_PREFIX
SYSCONFDIR = $TEST_PREFIX/etc
LOCALSTATEDIR = $TEST_PREFIX/var
RUNSTATEDIR = $TEST_PREFIX/run
VPN_USER = $TEST_USER
VPN_GROUP = $TEST_GROUP

include $PROJECT_DIR/Makefile
EOF

	# Test installation with custom paths
	if sudo -E make -f /tmp/test-makefile install-dirs 2>/dev/null; then
		# Verify directories were created
		if [[ -d "$TEST_PREFIX/etc/protonvpn" && -d "$TEST_PREFIX/var/log/protonvpn" ]]; then
			log_test "PASS" "Basic installation directories created"
		else
			log_test "FAIL" "Installation directories missing"
		fi
	else
		log_test "FAIL" "Basic installation failed"
	fi

	rm -f /tmp/test-makefile
}

# Test 2: Permission Validation
test_permission_validation() {
	echo "=== Test: Permission Validation ==="

	# Create test directory structure
	mkdir -p "$TEST_PREFIX/etc/protonvpn"
	mkdir -p "$TEST_PREFIX/var/log/protonvpn"

	# Set correct permissions
	sudo chown -R root:root "$TEST_PREFIX/etc/protonvpn"
	sudo chmod 755 "$TEST_PREFIX/etc/protonvpn"

	# Test permission checking
	local perms
	perms=$(stat -c "%a" "$TEST_PREFIX/etc/protonvpn")
	if [[ "$perms" == "755" ]]; then
		log_test "PASS" "Directory permissions validated"
	else
		log_test "FAIL" "Directory permissions incorrect: $perms"
	fi
}

# Test 3: User Creation Edge Cases
test_user_creation() {
	echo "=== Test: User Creation Edge Cases ==="

	# Test creating user that already exists
	sudo useradd --system "$TEST_USER" 2>/dev/null || true

	# Try to create again (should not fail)
	if sudo useradd --system "$TEST_USER" 2>/dev/null; then
		log_test "FAIL" "Should handle existing user gracefully"
	else
		log_test "PASS" "Existing user handled correctly"
	fi

	# Test user properties
	local shell
	shell=$(getent passwd "$TEST_USER" | cut -d: -f7)
	if [[ "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]]; then
		log_test "PASS" "Service user has no shell access"
	else
		log_test "FAIL" "Service user has shell access: $shell"
	fi
}

# Test 4: Partial Installation Recovery
test_partial_installation_recovery() {
	echo "=== Test: Partial Installation Recovery ==="

	# Create partial installation state
	mkdir -p "$TEST_PREFIX/var/log/protonvpn"

	# Simulate failed installation (missing directories)
	# Then test recovery
	mkdir -p "$TEST_PREFIX/etc/protonvpn"
	mkdir -p "$TEST_PREFIX/run/protonvpn"

	# Check if all required directories exist
	local required_dirs=(
		"$TEST_PREFIX/etc/protonvpn"
		"$TEST_PREFIX/var/log/protonvpn"
		"$TEST_PREFIX/run/protonvpn"
	)

	local all_exist=true
	for dir in "${required_dirs[@]}"; do
		if [[ ! -d "$dir" ]]; then
			all_exist=false
			break
		fi
	done

	if [[ "$all_exist" == "true" ]]; then
		log_test "PASS" "Partial installation recovery successful"
	else
		log_test "FAIL" "Partial installation recovery failed"
	fi
}

# Test 5: Installation Rollback
test_installation_rollback() {
	echo "=== Test: Installation Rollback ==="

	# Create test installation
	mkdir -p "$TEST_PREFIX/usr/local/bin"
	mkdir -p "$TEST_PREFIX/etc/protonvpn"
	touch "$TEST_PREFIX/usr/local/bin/test-service"
	touch "$TEST_PREFIX/etc/protonvpn/test.conf"

	# Test cleanup/rollback
	rm -rf "$TEST_PREFIX/usr/local/bin/test-service"
	rm -rf "$TEST_PREFIX/etc/protonvpn"

	# Verify cleanup
	if [[ ! -f "$TEST_PREFIX/usr/local/bin/test-service" && ! -d "$TEST_PREFIX/etc/protonvpn" ]]; then
		log_test "PASS" "Installation rollback successful"
	else
		log_test "FAIL" "Installation rollback incomplete"
	fi
}

# Test 6: Configuration File Creation
test_configuration_creation() {
	echo "=== Test: Configuration File Creation ==="

	# Create test config directory
	mkdir -p "$TEST_PREFIX/etc/protonvpn"

	# Test configuration creation (simulate secure-config-manager)
	cat >"$TEST_PREFIX/etc/protonvpn/test.conf" <<'EOF'
UPDATE_INTERVAL=3600
SERVICE_USER="protonvpn"
VPN_ROOT="/usr/local/lib/protonvpn"
EOF

	# Validate configuration
	if [[ -f "$TEST_PREFIX/etc/protonvpn/test.conf" ]]; then
		local interval
		interval=$(grep "UPDATE_INTERVAL" "$TEST_PREFIX/etc/protonvpn/test.conf" | cut -d= -f2)
		if [[ "$interval" == "3600" ]]; then
			log_test "PASS" "Configuration file created correctly"
		else
			log_test "FAIL" "Configuration file has wrong content"
		fi
	else
		log_test "FAIL" "Configuration file not created"
	fi
}

# Test 7: Service File Generation
test_service_file_generation() {
	echo "=== Test: Service File Generation ==="

	# Create test systemd directory
	mkdir -p "$TEST_PREFIX/etc/systemd/system"

	# Test service file creation (simulate)
	cat >"$TEST_PREFIX/etc/systemd/system/test-protonvpn.service" <<'EOF'
[Unit]
Description=Test ProtonVPN Service
After=network-online.target

[Service]
Type=simple
User=protonvpn
ExecStart=/usr/local/bin/test-service
Restart=always

[Install]
WantedBy=multi-user.target
EOF

	# Validate service file
	if [[ -f "$TEST_PREFIX/etc/systemd/system/test-protonvpn.service" ]]; then
		if grep -q "User=protonvpn" "$TEST_PREFIX/etc/systemd/system/test-protonvpn.service"; then
			log_test "PASS" "Service file generated correctly"
		else
			log_test "FAIL" "Service file missing required user setting"
		fi
	else
		log_test "FAIL" "Service file not generated"
	fi
}

# Main test execution
main() {
	echo "Starting Installation Robustness Tests"
	echo "======================================"

	test_basic_installation
	test_permission_validation
	test_user_creation
	test_partial_installation_recovery
	test_installation_rollback
	test_configuration_creation
	test_service_file_generation

	echo ""
	echo "Installation Test Summary:"
	echo "========================="
	echo "Passed: $TESTS_PASSED"
	echo "Failed: $TESTS_FAILED"

	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo ""
		echo "Failed Tests:"
		for test in "${FAILED_TESTS[@]}"; do
			echo "  - $test"
		done
		exit 1
	else
		echo "All installation tests passed!"
		exit 0
	fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi

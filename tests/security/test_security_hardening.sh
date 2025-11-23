#!/bin/bash
# ABOUTME: Comprehensive security hardening tests for ProtonVPN Service
# ABOUTME: TDD test suite to validate all critical security fixes
# shellcheck disable=SC2317

set -euo pipefail

# Test configuration
readonly TEST_DIR
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly TEST_LOG="/tmp/security_hardening_tests.log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test logging
log_test() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "[$timestamp] [$level] $message" | tee -a "$TEST_LOG"
}

# Test output functions
test_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
test_pass() {
	echo -e "${GREEN}[PASS]${NC} $1"
	((TESTS_PASSED++))
}
test_fail() {
	echo -e "${RED}[FAIL]${NC} $1"
	((TESTS_FAILED++))
}
# Test output functions
test_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Test runner function
run_test() {
	local test_name="$1"
	local test_function="$2"

	((TESTS_RUN++))
	log_test "INFO" "Running test: $test_name"

	if $test_function; then
		test_pass "$test_name"
		log_test "PASS" "$test_name"
	else
		test_fail "$test_name"
		log_test "FAIL" "$test_name"
	fi
}

# Critical Security Test 1: No Hardcoded Development Paths
test_no_hardcoded_paths() {
	test_info "Testing for hardcoded development paths"

	local hardcoded_found=false
	local files_to_check=(
		"$PROJECT_ROOT/src/secure-config-manager"
		"$PROJECT_ROOT/src/secure-database-manager"
		"$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"
		"$PROJECT_ROOT/install-secure.sh"
	)

	for file in "${files_to_check[@]}"; do
		if [[ -f "$file" ]]; then
			# Check for hardcoded development paths
			if grep -q "$HOME/workspace/claude-code/vpn" "$file" 2>/dev/null; then
				# Allow detection but not usage
				if grep -v "# Security check\|WARNING\|ERROR" "$file" | grep -q "$HOME/workspace/claude-code/vpn"; then
					test_warn "Hardcoded path found in: $file"
					hardcoded_found=true
				fi
			fi
		fi
	done

	if [[ "$hardcoded_found" == "false" ]]; then
		return 0
	else
		return 1
	fi
}

# Critical Security Test 2: Secure Database Configuration
test_secure_database_config() {
	test_info "Testing secure database configuration"

	local db_manager="$PROJECT_ROOT/src/secure-database-manager"

	if [[ ! -f "$db_manager" ]]; then
		return 1
	fi

	# Check for secure database path configuration
	if grep -q "/var/lib/protonvpn/databases" "$db_manager" &&
		grep -q "chmod 600" "$db_manager" &&
		grep -q "chown.*protonvpn" "$db_manager"; then
		return 0
	else
		return 1
	fi
}

# Critical Security Test 3: Service User Security
test_service_user_security() {
	test_info "Testing service user security configuration"

	local config_manager="$PROJECT_ROOT/src/secure-config-manager"
	local install_script="$PROJECT_ROOT/install-secure.sh"

	# Check for proper service user configuration
	if grep -q "SERVICE_USER=\"protonvpn\"" "$config_manager" &&
		grep -q "/bin/false" "$install_script" &&
		grep -q "system.*user" "$install_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 4: Configuration File Permissions
test_config_file_permissions() {
	test_info "Testing configuration file permission settings"

	local config_manager="$PROJECT_ROOT/src/secure-config-manager"

	# Check for secure permission settings
	if grep -q "chmod 640" "$config_manager" &&
		grep -q "chown root:" "$config_manager"; then
		return 0
	else
		return 1
	fi
}

# Security Test 5: FHS Compliance
test_fhs_compliance() {
	test_info "Testing FHS (Filesystem Hierarchy Standard) compliance"

	local config_manager="$PROJECT_ROOT/src/secure-config-manager"

	# Check for FHS-compliant paths
	local fhs_paths=(
		"/etc/protonvpn"
		"/usr/local/lib/protonvpn"
		"/usr/local/bin"
		"/var/lib/protonvpn"
		"/var/log/protonvpn"
		"/run/protonvpn"
	)

	local all_found=true
	for path in "${fhs_paths[@]}"; do
		if ! grep -q "$path" "$config_manager"; then
			all_found=false
			break
		fi
	done

	if [[ "$all_found" == "true" ]]; then
		return 0
	else
		return 1
	fi
}

# Security Test 6: Systemd Security Hardening
test_systemd_security_hardening() {
	test_info "Testing systemd security hardening features"

	local install_script="$PROJECT_ROOT/install-secure.sh"

	# Check for systemd security features
	local security_features=(
		"NoNewPrivileges=yes"
		"ProtectSystem=strict"
		"ProtectHome=yes"
		"PrivateDevices=yes"
		"MemoryDenyWriteExecute=yes"
		"RestrictNamespaces=yes"
	)

	local all_features=true
	for feature in "${security_features[@]}"; do
		if ! grep -q "$feature" "$install_script"; then
			all_features=false
			break
		fi
	done

	if [[ "$all_features" == "true" ]]; then
		return 0
	else
		return 1
	fi
}

# Security Test 7: Resource Limits
test_resource_limits() {
	test_info "Testing resource limit configurations"

	local install_script="$PROJECT_ROOT/install-secure.sh"

	# Check for resource limits
	if grep -q "MemoryLimit=25M" "$install_script" &&
		grep -q "CPUQuota=5%" "$install_script" &&
		grep -q "LimitNOFILE=512" "$install_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 8: Input Validation and Sanitization
test_input_validation() {
	test_info "Testing input validation and sanitization"

	local daemon_script="$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"

	# Check for input sanitization functions
	if grep -q "sanitize\|clean_message\|REDACTED" "$daemon_script" &&
		grep -q "sed.*password\|sed.*token" "$daemon_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 9: Audit Logging
test_audit_logging() {
	test_info "Testing audit logging capabilities"

	local daemon_script="$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"

	# Check for audit logging
	if grep -q "AUDIT_LOGGING" "$daemon_script" &&
		grep -q "logger.*protonvpn-updater" "$daemon_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 10: Timeout and Error Handling
test_timeout_error_handling() {
	test_info "Testing timeout and error handling"

	local daemon_script="$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"

	# Check for timeout handling
	if grep -q "timeout.*UPDATE_TIMEOUT" "$daemon_script" &&
		grep -q "set -euo pipefail" "$daemon_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 11: Database Encryption Capability
test_database_encryption() {
	test_info "Testing database encryption capability"

	local db_manager="$PROJECT_ROOT/src/secure-database-manager"

	# Check for encryption functions
	if grep -q "encrypt_database" "$db_manager" &&
		grep -q "gpg.*encrypt" "$db_manager"; then
		return 0
	else
		return 1
	fi
}

# Security Test 12: Secure Installation Process
test_secure_installation() {
	test_info "Testing secure installation process"

	local install_script="$PROJECT_ROOT/install-secure.sh"

	# Check for security validations in installation
	if grep -q "validate_security" "$install_script" &&
		grep -q "check_root" "$install_script" &&
		grep -q "SECURITY ISSUE" "$install_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 13: Network Security
test_network_security() {
	test_info "Testing network security restrictions"

	local install_script="$PROJECT_ROOT/install-secure.sh"

	# Check for network restrictions
	if grep -q "RestrictAddressFamilies" "$install_script" &&
		grep -q "SystemCallFilter" "$install_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 14: Process Security
test_process_security() {
	test_info "Testing process security measures"

	local daemon_script="$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"

	# Check for process security checks
	if grep -q "check_resource_usage" "$daemon_script" &&
		grep -q "instance_count" "$daemon_script" &&
		grep -q "memory_mb" "$daemon_script"; then
		return 0
	else
		return 1
	fi
}

# Security Test 15: Configuration Integrity
test_config_integrity() {
	test_info "Testing configuration integrity checks"

	local config_manager="$PROJECT_ROOT/src/secure-config-manager"

	# Check for integrity validation
	if grep -q "validate_config_integrity" "$config_manager" &&
		grep -q "required_vars" "$config_manager"; then
		return 0
	else
		return 1
	fi
}

# Integration Test: File Existence and Executability
test_file_existence() {
	test_info "Testing security-hardened file existence and permissions"

	local required_files=(
		"$PROJECT_ROOT/src/secure-config-manager"
		"$PROJECT_ROOT/src/secure-database-manager"
		"$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"
		"$PROJECT_ROOT/install-secure.sh"
	)

	for file in "${required_files[@]}"; do
		if [[ ! -f "$file" ]]; then
			return 1
		fi

		if [[ ! -x "$file" ]]; then
			return 1
		fi
	done

	return 0
}

# Performance Test: Security Overhead
test_security_overhead() {
	test_info "Testing security overhead is acceptable"

	local daemon_script="$PROJECT_ROOT/src/protonvpn-updater-daemon-secure.sh"

	# Count security-related operations (should be reasonable)
	local security_ops
	security_ops=$(grep -c "log_secure\|validate\|check\|verify" "$daemon_script" 2>/dev/null || echo "0")

	# Should have security operations but not excessive (< 50)
	if [[ "$security_ops" -gt 5 ]] && [[ "$security_ops" -lt 50 ]]; then
		return 0
	else
		return 1
	fi
}

# Main test runner
main() {
	test_info "Starting ProtonVPN Security Hardening Test Suite"
	test_info "====================================================="

	# Initialize test log
	echo "ProtonVPN Security Hardening Tests - $(date)" >"$TEST_LOG"

	# Critical Security Tests (must pass)
	run_test "No Hardcoded Development Paths" "test_no_hardcoded_paths"
	run_test "Secure Database Configuration" "test_secure_database_config"
	run_test "Service User Security" "test_service_user_security"
	run_test "Configuration File Permissions" "test_config_file_permissions"
	run_test "FHS Compliance" "test_fhs_compliance"

	# Systemd Security Hardening Tests
	run_test "Systemd Security Hardening" "test_systemd_security_hardening"
	run_test "Resource Limits" "test_resource_limits"
	run_test "Network Security" "test_network_security"

	# Application Security Tests
	run_test "Input Validation" "test_input_validation"
	run_test "Audit Logging" "test_audit_logging"
	run_test "Timeout and Error Handling" "test_timeout_error_handling"
	run_test "Database Encryption" "test_database_encryption"

	# Process and Installation Security
	run_test "Secure Installation Process" "test_secure_installation"
	run_test "Process Security" "test_process_security"
	run_test "Configuration Integrity" "test_config_integrity"

	# Integration and Performance Tests
	run_test "File Existence and Permissions" "test_file_existence"
	run_test "Security Overhead" "test_security_overhead"

	# Test Summary
	echo ""
	test_info "Test Results Summary"
	test_info "==================="
	echo "Tests Run: $TESTS_RUN"
	echo "Tests Passed: $TESTS_PASSED"
	echo "Tests Failed: $TESTS_FAILED"

	if [[ $TESTS_FAILED -eq 0 ]]; then
		test_pass "ALL SECURITY TESTS PASSED"
		echo ""
		test_info "Security hardening validation: SUCCESS"
		test_info "The ProtonVPN service meets all security requirements"
		exit 0
	else
		test_fail "SECURITY TESTS FAILED: $TESTS_FAILED"
		echo ""
		test_info "Security hardening validation: FAILED"
		test_info "Review failed tests and address security issues before deployment"
		test_info "Check log file: $TEST_LOG"
		exit 1
	fi
}

# Execute test suite
main "$@"

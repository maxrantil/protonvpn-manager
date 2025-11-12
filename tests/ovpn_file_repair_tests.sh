#!/bin/bash
# ABOUTME: TDD test suite for fix-ovpn-files repair utility
# ABOUTME: Tests configuration file corruption detection and repair capabilities

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_LOCATIONS_DIR="$SCRIPT_DIR/test_locations"
readonly FIX_OVPN_FILES="$PROJECT_ROOT/src/fix-ovpn-files"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;36m'
readonly NC='\033[0m'

# Test counters
test_count=0
pass_count=0
fail_count=0

# Setup and teardown
setup_test_environment() {
	# Create test locations directory
	rm -rf "$TEST_LOCATIONS_DIR"
	mkdir -p "$TEST_LOCATIONS_DIR"

	# Create test OpenVPN files with various corruption patterns
	create_test_ovpn_files
}

create_test_ovpn_files() {
	# Valid OpenVPN file (should not need repair)
	cat >"$TEST_LOCATIONS_DIR/valid-se-01.ovpn" <<'EOF'
client
dev tun
proto udp
remote se-01.protonvpn.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA512
verb 3
EOF

	# Corrupted file - missing essential client directive
	cat >"$TEST_LOCATIONS_DIR/corrupted-missing-client.ovpn" <<'EOF'
dev tun
proto udp
remote se-02.protonvpn.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA512
verb 3
EOF

	# Corrupted file - malformed remote directive
	cat >"$TEST_LOCATIONS_DIR/corrupted-malformed-remote.ovpn" <<'EOF'
client
dev tun
proto udp
remote
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA512
verb 3
EOF

	# Corrupted file - missing essential directives
	cat >"$TEST_LOCATIONS_DIR/corrupted-minimal.ovpn" <<'EOF'
client
remote se-03.protonvpn.com 1194
EOF

	# File with extra whitespace and comments (should be cleanable)
	cat >"$TEST_LOCATIONS_DIR/messy-but-valid.ovpn" <<'EOF'
# ProtonVPN Configuration
client

dev tun
proto udp
remote se-04.protonvpn.com 1194
resolv-retry infinite

nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA512
verb 3
# End of configuration
EOF

	# Completely corrupted file (binary-like content)
	cat >"$TEST_LOCATIONS_DIR/totally-corrupted.ovpn" <<'EOF'
ÿÿÿÿÿÿÿÿÿÿÿÿ
Binary data that shouldn't be in OpenVPN config
øøøøøøø§§§§§§§
EOF
}

teardown_test_environment() {
	rm -rf "$TEST_LOCATIONS_DIR"
}

# Test framework functions
start_test() {
	local test_name="$1"
	test_count=$((test_count + 1))
	echo -e "${BLUE}[TEST $test_count] $test_name${NC}"
}

assert_file_exists() {
	local file="$1"
	local message="$2"

	if [[ -f "$file" ]]; then
		echo -e "  ${GREEN}✓ PASS: $message${NC}"
		return 0
	else
		echo -e "  ${RED}✗ FAIL: $message (file not found: $file)${NC}"
		return 1
	fi
}

assert_executable() {
	local file="$1"
	local message="$2"

	if [[ -x "$file" ]]; then
		echo -e "  ${GREEN}✓ PASS: $message${NC}"
		return 0
	else
		echo -e "  ${RED}✗ FAIL: $message (not executable: $file)${NC}"
		return 1
	fi
}

assert_contains() {
	local text="$1"
	local pattern="$2"
	local message="$3"

	# Use fixed string matching for patterns starting with -- (command options)
	# Use regex matching for patterns containing regex metacharacters like \| or \[
	if [[ "$pattern" == --* ]]; then
		if echo "$text" | grep -qF -- "$pattern"; then
			echo -e "  ${GREEN}✓ PASS: $message${NC}"
			return 0
		fi
	else
		if echo "$text" | grep -q -- "$pattern"; then
			echo -e "  ${GREEN}✓ PASS: $message${NC}"
			return 0
		fi
	fi

	echo -e "  ${RED}✗ FAIL: $message (pattern '$pattern' not found)${NC}"
	echo -e "  ${YELLOW}  Actual content: $text${NC}"
	return 1
}

assert_not_contains() {
	local text="$1"
	local pattern="$2"
	local message="$3"

	# Use fixed string matching for patterns starting with -- (command options)
	# Use regex matching for patterns containing regex metacharacters like \| or \[
	if [[ "$pattern" == --* ]]; then
		if ! echo "$text" | grep -qF -- "$pattern"; then
			echo -e "  ${GREEN}✓ PASS: $message${NC}"
			return 0
		fi
	else
		if ! echo "$text" | grep -q -- "$pattern"; then
			echo -e "  ${GREEN}✓ PASS: $message${NC}"
			return 0
		fi
	fi

	echo -e "  ${RED}✗ FAIL: $message (pattern '$pattern' found but shouldn't be)${NC}"
	return 1
}

assert_exit_code() {
	local expected_code="$1"
	local actual_code="$2"
	local message="$3"

	if [[ $actual_code -eq $expected_code ]]; then
		echo -e "  ${GREEN}✓ PASS: $message${NC}"
		return 0
	else
		echo -e "  ${RED}✗ FAIL: $message (expected exit code $expected_code, got $actual_code)${NC}"
		return 1
	fi
}

record_result() {
	if [[ $? -eq 0 ]]; then
		pass_count=$((pass_count + 1))
	else
		fail_count=$((fail_count + 1))
	fi
}

# Test Cases (RED - These should fail initially)

test_tool_accessibility() {
	start_test "fix-ovpn-files tool exists and is executable"

	assert_file_exists "$FIX_OVPN_FILES" "fix-ovpn-files script exists" &&
		assert_executable "$FIX_OVPN_FILES" "fix-ovpn-files is executable"
	record_result
}

test_help_functionality() {
	start_test "fix-ovpn-files shows help when called with --help"

	local help_output
	help_output=$("$FIX_OVPN_FILES" --help 2>&1) || true

	assert_contains "$help_output" "Usage:" "Help shows usage information" &&
		assert_contains "$help_output" "--repair" "Help mentions repair option" &&
		assert_contains "$help_output" "--check" "Help mentions check option"
	record_result
}

test_corruption_detection() {
	start_test "fix-ovpn-files detects corrupted configurations"

	export LOCATIONS_DIR="$TEST_LOCATIONS_DIR"
	local check_output
	check_output=$("$FIX_OVPN_FILES" --check 2>&1) || true

	assert_contains "$check_output" "corrupted-missing-client.ovpn" "Detects missing client directive" &&
		assert_contains "$check_output" "corrupted-malformed-remote.ovpn" "Detects malformed remote directive" &&
		assert_contains "$check_output" "corrupted-minimal.ovpn" "Detects minimal configuration" &&
		assert_contains "$check_output" "totally-corrupted.ovpn" "Detects binary corruption"
	record_result
}

test_valid_file_recognition() {
	start_test "fix-ovpn-files recognizes valid configurations"

	export LOCATIONS_DIR="$TEST_LOCATIONS_DIR"
	local check_output
	check_output=$("$FIX_OVPN_FILES" --check 2>&1) || true

	assert_contains "$check_output" "VALID" "Shows valid file status" &&
		assert_contains "$check_output" "valid-se-01.ovpn" "Recognizes valid configuration"
	record_result
}

test_repair_functionality() {
	start_test "fix-ovpn-files repairs correctable issues"

	export LOCATIONS_DIR="$TEST_LOCATIONS_DIR"
	local repair_output
	repair_output=$("$FIX_OVPN_FILES" --repair --backup 2>&1) || true

	# Should attempt repairs and create backups
	assert_contains "$repair_output" "REPAIRED" "Shows repair attempts" &&
		assert_file_exists "$TEST_LOCATIONS_DIR/backups/corrupted-missing-client.ovpn.backup"* "Creates backup files"
	record_result
}

test_backup_mechanism() {
	start_test "fix-ovpn-files creates backups before repair"

	export LOCATIONS_DIR="$TEST_LOCATIONS_DIR"

	# Count files before repair (removed - unused in current test)
	# Can be re-added when implementing file count validation

	"$FIX_OVPN_FILES" --repair --backup &>/dev/null || true

	# Check backup directory exists and has files
	assert_file_exists "$TEST_LOCATIONS_DIR/backups" "Backup directory created" &&
		local backup_count
	backup_count=$(find "$TEST_LOCATIONS_DIR/backups" -name "*.backup.*" 2>/dev/null | wc -l)

	[[ $backup_count -gt 0 ]] && echo -e "  ${GREEN}✓ PASS: Backup files created ($backup_count files)${NC}" ||
		echo -e "  ${RED}✗ FAIL: No backup files created${NC}"
	record_result
}

test_unrepairable_file_handling() {
	start_test "fix-ovpn-files handles unrepairable files gracefully"

	export LOCATIONS_DIR="$TEST_LOCATIONS_DIR"
	local repair_output
	repair_output=$("$FIX_OVPN_FILES" --repair 2>&1) || true

	# Should report unrepairable files
	assert_contains "$repair_output" "UNREPAIRABLE\|FAILED" "Reports unrepairable files" &&
		assert_contains "$repair_output" "totally-corrupted.ovpn" "Identifies binary corruption as unrepairable"
	record_result
}

test_directory_validation() {
	start_test "fix-ovpn-files validates directory parameter"

	# Test with non-existent directory
	local error_output
	error_output=$(LOCATIONS_DIR="/nonexistent/directory" "$FIX_OVPN_FILES" --check 2>&1) || true

	assert_contains "$error_output" "Error\|not found\|directory" "Reports directory errors"
	record_result
}

# Main test execution
main() {
	echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
	echo -e "${BLUE}║     OpenVPN File Repair - TDD Tests     ║${NC}"
	echo -e "${BLUE}║        Phase 7.1 Configuration          ║${NC}"
	echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
	echo

	setup_test_environment

	# Run all test cases
	test_tool_accessibility
	test_help_functionality
	test_corruption_detection
	test_valid_file_recognition
	test_repair_functionality
	test_backup_mechanism
	test_unrepairable_file_handling
	test_directory_validation

	teardown_test_environment

	# Test summary
	echo
	echo -e "${BLUE}Test Summary:${NC}"
	echo -e "  Total tests: ${YELLOW}$test_count${NC}"
	echo -e "  Passed: ${GREEN}$pass_count${NC}"
	echo -e "  Failed: ${RED}$fail_count${NC}"

	if [[ $fail_count -eq 0 ]]; then
		echo -e "${GREEN}✓ All tests passed!${NC}"
		return 0
	else
		echo -e "${RED}✗ Some tests failed.${NC}"
		return 1
	fi
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi

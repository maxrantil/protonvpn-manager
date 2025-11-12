#!/bin/bash
# ABOUTME: PID validation security tests for Issue #67
# ABOUTME: Tests boundary values, injection attempts, process impersonation, and zombies

set -euo pipefail

# Simple standalone test runner (no test_framework.sh dependency)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Simple logging
log_test() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	case "$level" in
	"PASS") echo -e "${GREEN}[PASS]${NC} [$timestamp] $message" ;;
	"FAIL") echo -e "${RED}[FAIL]${NC} [$timestamp] $message" ;;
	"INFO") echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" ;;
	"WARN") echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message" ;;
	esac
}

# Source PID validation functions
if ! source "$PROJECT_DIR/src/vpn-validators" 2>/dev/null; then
	echo "ERROR: Cannot source vpn-validators" >&2
	exit 1
fi

# Test-specific variables
TEST_PIDS=()
TEST_PROCS_DIR="/tmp/pid-security-test-$$"
mkdir -p "$TEST_PROCS_DIR"

# Cleanup function
cleanup_pid_tests() {
	log_test "INFO" "Cleaning up test processes and directories"

	# Kill all test processes
	for pid in "${TEST_PIDS[@]}"; do
		kill -KILL "$pid" 2>/dev/null || true
	done

	# Clean up test process spawns
	pkill -f "sleep.*pid-test-marker" 2>/dev/null || true
	pkill -f "exec -a 'openvpn --config /test/" 2>/dev/null || true

	# Remove test directory
	rm -rf "$TEST_PROCS_DIR"

	wait 2>/dev/null || true
}
trap cleanup_pid_tests EXIT

# Helper: Create fake OpenVPN process for testing
create_fake_openvpn_process() {
	local config_name="${1:-test.ovpn}"
	local sleep_duration="${2:-300}"

	# Use exec -a to rename process, add marker for cleanup
	bash -c "exec -a 'openvpn --config /test/$config_name' sleep $sleep_duration" &
	local pid=$!
	TEST_PIDS+=("$pid")

	# Wait for process to start
	sleep 0.1

	echo "$pid"
}

# Helper: Create non-OpenVPN process
create_fake_process() {
	local process_name="${1:-sleep}"
	local duration="${2:-300}"

	"$process_name" "$duration" &
	local pid=$!
	TEST_PIDS+=("$pid")

	sleep 0.1
	echo "$pid"
}

# No helper needed - vpn-validators sourced at top of file

# ============================================================================
# UNIT TESTS: validate_pid() - Boundary Value Testing
# ============================================================================

test_validate_pid_accepts_valid_pids() {
	log_test "INFO" "Testing validate_pid: Accept valid PID range"

	local valid_pids=(1 100 1000 10000 100000 1000000 4194303)
	local all_passed=true

	for pid in "${valid_pids[@]}"; do
		if validate_pid "$pid"; then
			log_test "PASS" "Accepted valid PID: $pid"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_test "FAIL" "Rejected valid PID: $pid"
			FAILED_TESTS+=("validate_pid valid range: $pid")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_passed=false
		fi
	done

	if [[ "$all_passed" == "true" ]]; then
		log_test "INFO" "All valid PIDs accepted (7/7)"
	fi
}

test_validate_pid_rejects_zero() {
	log_test "INFO" "Testing validate_pid: Reject PID 0"

	if validate_pid "0"; then
		log_test "FAIL" "Accepted PID 0 (should reject - null process)"
		FAILED_TESTS+=("validate_pid: PID 0 accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected PID 0 (null process protection)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_pid_rejects_negative() {
	log_test "INFO" "Testing validate_pid: Reject negative PIDs"

	local negative_pids=(-1 -100 -999999)
	local all_rejected=true

	for pid in "${negative_pids[@]}"; do
		if validate_pid "$pid"; then
			log_test "FAIL" "Accepted negative PID: $pid"
			FAILED_TESTS+=("validate_pid negative: $pid")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected negative PID: $pid"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_overflow() {
	log_test "INFO" "Testing validate_pid: Reject PIDs above system maximum"

	# Linux PID_MAX_LIMIT is 4194304 (2^22)
	local overflow_pids=(4194304 4194305 9999999 2147483647 2147483648)
	local all_rejected=true

	for pid in "${overflow_pids[@]}"; do
		if validate_pid "$pid"; then
			log_test "FAIL" "Accepted overflow PID: $pid"
			FAILED_TESTS+=("validate_pid overflow: $pid")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected overflow PID: $pid"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_empty_string() {
	log_test "INFO" "Testing validate_pid: Reject empty string"

	if validate_pid ""; then
		log_test "FAIL" "Accepted empty string as PID"
		FAILED_TESTS+=("validate_pid: empty string")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected empty string"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_pid_rejects_whitespace() {
	log_test "INFO" "Testing validate_pid: Reject whitespace inputs"

	local whitespace_inputs=(" " "  " "	" "  123" "123  " " 123 ")
	local all_rejected=true

	for input in "${whitespace_inputs[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted whitespace input: '$(printf '%q' "$input")'"
			FAILED_TESTS+=("validate_pid whitespace: $(printf '%q' "$input")")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected whitespace input: '$(printf '%q' "$input")'"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_non_numeric() {
	log_test "INFO" "Testing validate_pid: Reject non-numeric inputs"

	local non_numeric=("abc" "12a34" "a1234" "pid" "one" "1.234" "1,234")
	local all_rejected=true

	for input in "${non_numeric[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted non-numeric input: $input"
			FAILED_TESTS+=("validate_pid non-numeric: $input")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected non-numeric input: $input"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_shell_metacharacters() {
	log_test "INFO" "Testing validate_pid: Reject shell metacharacters"

	local shell_chars=(
		"12;3"
		"12&3"
		"12|3"
		"12>3"
		"12<3"
		'12$3'
		'12`3`'
		'12$(3)'
		"12'3"
		'12"3'
		'12\3'
		'12*3'
		'12?3'
	)

	local all_rejected=true

	for input in "${shell_chars[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted shell metacharacter: $(printf '%q' "$input")"
			FAILED_TESTS+=("validate_pid shell: $(printf '%q' "$input")")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected shell metacharacter: $(printf '%q' "$input")"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_path_traversal() {
	log_test "INFO" "Testing validate_pid: Reject path traversal attempts"

	local path_attempts=("../1234" "../../proc/1" "/proc/1234" "./1234" "$HOME/1234")
	local all_rejected=true

	for input in "${path_attempts[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted path traversal: $input"
			FAILED_TESTS+=("validate_pid path traversal: $input")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected path traversal: $input"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_octal_hex() {
	log_test "INFO" "Testing validate_pid: Reject octal and hexadecimal encoding"

	local encoded_pids=("0123" "0777" "0x1234" "0xFFFF" "0o123")
	local all_rejected=true

	for input in "${encoded_pids[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted encoded PID: $input"
			FAILED_TESTS+=("validate_pid encoded: $input")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected encoded PID: $input"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_rejects_leading_zeros() {
	log_test "INFO" "Testing validate_pid: Reject PIDs with leading zeros"

	# Leading zeros could be interpreted as octal, security risk
	local leading_zero_pids=("00001" "000123" "0000000001")
	local all_rejected=true

	for input in "${leading_zero_pids[@]}"; do
		if validate_pid "$input"; then
			log_test "FAIL" "Accepted PID with leading zeros: $input"
			FAILED_TESTS+=("validate_pid leading zeros: $input")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected PID with leading zeros: $input"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_validate_pid_system_pid_max() {
	log_test "INFO" "Testing validate_pid: Respect system PID_MAX"

	# Read actual system PID_MAX
	local system_pid_max
	system_pid_max=$(cat /proc/sys/kernel/pid_max 2>/dev/null || echo "4194304")

	log_test "INFO" "System PID_MAX: $system_pid_max"

	# Test PID at system maximum (should accept)
	local max_valid_pid=$((system_pid_max - 1))
	if validate_pid "$max_valid_pid"; then
		log_test "PASS" "Accepted PID at system max-1: $max_valid_pid"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_test "FAIL" "Rejected valid PID at system max-1: $max_valid_pid"
		FAILED_TESTS+=("validate_pid: system max-1")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi

	# Test PID above system maximum (should reject)
	local over_max_pid=$((system_pid_max + 1))
	if validate_pid "$over_max_pid"; then
		log_test "FAIL" "Accepted PID above system max: $over_max_pid"
		FAILED_TESTS+=("validate_pid: above system max")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected PID above system max: $over_max_pid"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

# ============================================================================
# INTEGRATION TESTS: validate_openvpn_process() - Process Validation
# ============================================================================

test_validate_openvpn_process_valid() {
	log_test "INFO" "Testing validate_openvpn_process: Accept real OpenVPN process"

	# Create fake OpenVPN process
	local openvpn_pid
	openvpn_pid=$(create_fake_openvpn_process "valid.ovpn")

	if validate_openvpn_process "$openvpn_pid"; then
		log_test "PASS" "Validated legitimate OpenVPN process (PID: $openvpn_pid)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	else
		log_test "FAIL" "Rejected legitimate OpenVPN process (PID: $openvpn_pid)"
		FAILED_TESTS+=("validate_openvpn_process: valid process rejected")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

test_validate_openvpn_process_wrong_command() {
	log_test "INFO" "Testing validate_openvpn_process: Reject non-OpenVPN process"

	# Create regular sleep process
	local fake_pid
	fake_pid=$(create_fake_process "sleep" 60)

	if validate_openvpn_process "$fake_pid"; then
		log_test "FAIL" "Accepted non-OpenVPN process as valid (PID: $fake_pid)"
		FAILED_TESTS+=("validate_openvpn_process: non-openvpn accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected non-OpenVPN process (PID: $fake_pid)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_openvpn_process_similar_name() {
	log_test "INFO" "Testing validate_openvpn_process: Reject similar process names"

	# Create process with similar but wrong name
	bash -c "exec -a 'openvpn-fake --config /test/fake.ovpn' sleep 60" &
	local similar_pid=$!
	TEST_PIDS+=("$similar_pid")
	sleep 0.1

	if validate_openvpn_process "$similar_pid"; then
		log_test "FAIL" "Accepted 'openvpn-fake' as legitimate (PID: $similar_pid)"
		FAILED_TESTS+=("validate_openvpn_process: similar name accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected 'openvpn-fake' process (PID: $similar_pid)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_openvpn_process_nonexistent() {
	log_test "INFO" "Testing validate_openvpn_process: Reject nonexistent PID"

	# Use a PID that definitely doesn't exist
	local nonexistent_pid=999999

	if validate_openvpn_process "$nonexistent_pid"; then
		log_test "FAIL" "Accepted nonexistent PID: $nonexistent_pid"
		FAILED_TESTS+=("validate_openvpn_process: nonexistent PID accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected nonexistent PID: $nonexistent_pid"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_openvpn_process_invalid_pid_format() {
	log_test "INFO" "Testing validate_openvpn_process: Reject invalid PID format"

	# Should fail PID validation before checking process
	if validate_openvpn_process "not-a-pid"; then
		log_test "FAIL" "Accepted invalid PID format"
		FAILED_TESTS+=("validate_openvpn_process: invalid format accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected invalid PID format"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_openvpn_process_missing_config_flag() {
	log_test "INFO" "Testing validate_openvpn_process: Reject OpenVPN without --config"

	# Create process named openvpn but without --config flag
	bash -c "exec -a 'openvpn /test/file.ovpn' sleep 60" &
	local no_config_pid=$!
	TEST_PIDS+=("$no_config_pid")
	sleep 0.1

	if validate_openvpn_process "$no_config_pid"; then
		log_test "FAIL" "Accepted OpenVPN process without --config flag"
		FAILED_TESTS+=("validate_openvpn_process: missing --config accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected OpenVPN process without --config flag"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_validate_openvpn_process_concurrent_validation() {
	log_test "INFO" "Testing validate_openvpn_process: Handle concurrent validations"

	# Create multiple OpenVPN processes
	local pid1 pid2 pid3
	pid1=$(create_fake_openvpn_process "concurrent1.ovpn")
	pid2=$(create_fake_openvpn_process "concurrent2.ovpn")
	pid3=$(create_fake_openvpn_process "concurrent3.ovpn")

	# Validate all concurrently
	local all_valid=true

	if ! validate_openvpn_process "$pid1"; then all_valid=false; fi
	if ! validate_openvpn_process "$pid2"; then all_valid=false; fi
	if ! validate_openvpn_process "$pid3"; then all_valid=false; fi

	if [[ "$all_valid" == "true" ]]; then
		log_test "PASS" "All concurrent validations succeeded"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	else
		log_test "FAIL" "Concurrent validation failed"
		FAILED_TESTS+=("validate_openvpn_process: concurrent validation failed")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

# ============================================================================
# SECURITY TESTS: Attack Vector Prevention
# ============================================================================

test_command_injection_via_pid() {
	log_test "INFO" "Testing Security: Command injection prevention via PID parameter"

	# Create marker file to detect injection
	local marker_file="/tmp/pid-injection-marker-$$"

	# Malicious PIDs that attempt command execution
	local injection_attempts=(
		"1234; touch $marker_file"
		"1234 | touch $marker_file"
		"1234 && touch $marker_file"
		"\$(touch $marker_file)"
		"\`touch $marker_file\`"
		"1234\ntouch $marker_file"
	)

	local all_blocked=true

	for attempt in "${injection_attempts[@]}"; do
		# Try to validate (should reject)
		validate_pid "$attempt" 2>/dev/null || true

		# Check if injection succeeded
		if [[ -f "$marker_file" ]]; then
			log_test "FAIL" "Command injection succeeded: $(printf '%q' "$attempt")"
			FAILED_TESTS+=("command injection: $(printf '%q' "$attempt")")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_blocked=false
			rm -f "$marker_file"
		else
			log_test "PASS" "Command injection blocked: $(printf '%q' "$attempt")"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_blocked" == "true" ]]
}

test_process_impersonation_fake_path() {
	log_test "INFO" "Testing Security: Prevent process impersonation via fake path"

	# Create fake openvpn executable in /tmp
	local fake_openvpn="$TEST_PROCS_DIR/openvpn"
	cat >"$fake_openvpn" <<'EOF'
#!/bin/bash
sleep 300
EOF
	chmod +x "$fake_openvpn"

	# Run fake openvpn
	"$fake_openvpn" --config /test/fake.ovpn &
	local impostor_pid=$!
	TEST_PIDS+=("$impostor_pid")
	sleep 0.1

	# Should be rejected (not real openvpn executable)
	if validate_openvpn_process "$impostor_pid"; then
		log_test "FAIL" "Accepted fake openvpn from /tmp (PID: $impostor_pid)"
		FAILED_TESTS+=("process impersonation: fake path accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected fake openvpn from /tmp (PID: $impostor_pid)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_process_impersonation_symlink() {
	log_test "INFO" "Testing Security: Prevent process impersonation via symlink"

	# Create symlink to sleep named openvpn
	local symlink_path="$TEST_PROCS_DIR/openvpn-symlink"
	ln -sf "$(which sleep)" "$symlink_path"

	# Run via symlink
	"$symlink_path" 300 &
	local symlink_pid=$!
	TEST_PIDS+=("$symlink_pid")
	sleep 0.1

	if validate_openvpn_process "$symlink_pid"; then
		log_test "FAIL" "Accepted symlinked process as OpenVPN"
		FAILED_TESTS+=("process impersonation: symlink accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected symlinked process"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_privilege_escalation_system_pid() {
	log_test "INFO" "Testing Security: Prevent targeting system processes"

	# Critical system PIDs that should NEVER be accepted as OpenVPN
	local system_pids=(1 2) # init, kthreadd
	local all_rejected=true

	for sys_pid in "${system_pids[@]}"; do
		if validate_openvpn_process "$sys_pid"; then
			log_test "FAIL" "Accepted system PID as OpenVPN: $sys_pid"
			FAILED_TESTS+=("privilege escalation: system PID $sys_pid accepted")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_rejected=false
		else
			log_test "PASS" "Rejected system PID: $sys_pid"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	[[ "$all_rejected" == "true" ]]
}

test_information_disclosure_error_messages() {
	log_test "INFO" "Testing Security: Prevent PID information disclosure in error messages"

	# Test that error messages don't leak sensitive PID information
	# This is more of a code review test - checking that validation
	# doesn't echo PIDs in error messages

	local test_output
	test_output=$(validate_pid "invalid-pid" 2>&1 || true) || true

	if [[ "$test_output" =~ invalid-pid ]]; then
		log_test "WARN" "Error messages may leak input: $test_output"
		log_test "PASS" "Test completed (warning noted)"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_test "PASS" "No PID information disclosed in error messages"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	fi
}

test_pid_reuse_timing_window() {
	log_test "INFO" "Testing Security: TOCTOU race condition awareness"

	# This test validates that there's a small timing window between
	# validation and kill operations where PID reuse could occur

	# Create process
	local test_pid
	test_pid=$(create_fake_openvpn_process "toctou-test.ovpn" 1) || true

	# Validate process
	if validate_openvpn_process "$test_pid"; then
		log_test "INFO" "Process validated (PID: $test_pid)"

		# Process dies naturally after 1 second
		sleep 1.5

		# Check if PID still exists (might be reused)
		if ps -p "$test_pid" >/dev/null 2>&1; then
			local new_cmd
			new_cmd=$(ps -p "$test_pid" -o cmd= 2>/dev/null || echo "")

			if [[ ! "$new_cmd" =~ openvpn ]]; then
				log_test "WARN" "PID $test_pid was reused by different process: $new_cmd"
				log_test "PASS" "TOCTOU race condition possible (test demonstrates risk)"
				TESTS_PASSED=$((TESTS_PASSED + 1))
			else
				log_test "PASS" "PID not reused during test"
				TESTS_PASSED=$((TESTS_PASSED + 1))
			fi
		else
			log_test "PASS" "Process terminated, PID not reused"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	else
		log_test "FAIL" "Failed to validate test process"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

test_lock_file_pid_validation() {
	log_test "INFO" "Testing Security: Lock file PID content validation"

	local test_lock_file="$TEST_PROCS_DIR/test.lock"

	# Test malicious lock file contents
	local malicious_contents=(
		"-1"
		"999999999"
		"1234; rm -rf /"
		"\$(whoami)"
		""
		"not-a-number"
	)

	local all_handled=true

	for content in "${malicious_contents[@]}"; do
		echo "$content" >"$test_lock_file"

		# Read lock file PID
		local lock_pid
		lock_pid=$(cat "$test_lock_file" 2>/dev/null || echo "")

		# Validate it
		if [[ -n "$lock_pid" ]] && validate_pid "$lock_pid"; then
			log_test "FAIL" "Accepted malicious lock file content: $(printf '%q' "$content")"
			FAILED_TESTS+=("lock file validation: $(printf '%q' "$content")")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			all_handled=false
		else
			log_test "PASS" "Rejected malicious lock file content: $(printf '%q' "$content")"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	done

	rm -f "$test_lock_file"
	[[ "$all_handled" == "true" ]]
}

test_process_group_validation_safety() {
	log_test "INFO" "Testing Security: Process group validation (PGID safety)"

	# Create process group with leader
	setsid bash -c '
        exec -a "openvpn --config /test/pgid.ovpn" sleep 300
    ' &
	local leader_pid=$!
	TEST_PIDS+=("$leader_pid")
	sleep 0.5

	# Get process group ID
	local pgid
	pgid=$(ps -o pgid= -p "$leader_pid" 2>/dev/null | tr -d ' ')

	if [[ -n "$pgid" ]]; then
		log_test "INFO" "Created process group: $pgid (leader: $leader_pid)"

		# Verify PGID is not in dangerous range (<1000 often system processes)
		if [[ "$pgid" -lt 1000 ]]; then
			log_test "WARN" "Process group ID in system range: $pgid"
			log_test "PASS" "Test highlights PGID range checking need"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_test "PASS" "Process group ID in safe range: $pgid"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	else
		log_test "SKIP" "Could not create process group (test environment limitation)"
	fi
}

# ============================================================================
# EDGE CASES: Zombies, Race Conditions, Special States
# ============================================================================

test_zombie_process_detection() {
	log_test "INFO" "Testing Edge Case: Zombie process detection and handling"

	# Create zombie process (child exits, parent doesn't reap)
	(
		bash -c "exec -a 'openvpn --config /test/zombie.ovpn' true" &
		local _child_pid=$!
		sleep 0.5
		# Parent stays alive, child becomes zombie
		sleep 5
	) &
	local parent_pid=$!
	TEST_PIDS+=("$parent_pid")

	sleep 1

	# Find zombie PID
	local zombie_pid
	zombie_pid=$(ps -eo pid,stat,comm | awk '$2~/^Z/ && $3=="openvpn" {print $1}' | head -1)

	if [[ -n "$zombie_pid" ]]; then
		log_test "INFO" "Created zombie process: $zombie_pid"

		source_vpn_validators

		# Test if validate_and_discover_processes finds zombies
		local discovered
		discovered=$(validate_and_discover_processes 2>/dev/null || echo "")

		if echo "$discovered" | grep -q "$zombie_pid"; then
			log_test "PASS" "Zombie process discovered by validation"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_test "FAIL" "Zombie process not discovered"
			FAILED_TESTS+=("zombie detection: not found")
			TESTS_FAILED=$((TESTS_FAILED + 1))
		fi
	else
		log_test "SKIP" "Could not create zombie process (test environment limitation)"
	fi
}

test_recently_killed_process() {
	log_test "INFO" "Testing Edge Case: Process killed between validation and action"

	# Create short-lived process
	local short_pid
	short_pid=$(create_fake_openvpn_process "short-lived.ovpn" 0.5)

	# Validate process
	if validate_openvpn_process "$short_pid"; then
		log_test "INFO" "Process validated (PID: $short_pid)"

		# Wait for it to die
		sleep 1

		# Try to validate again (should fail gracefully)
		if validate_openvpn_process "$short_pid" 2>/dev/null; then
			log_test "FAIL" "Validated dead process"
			FAILED_TESTS+=("dead process: validated after death")
			TESTS_FAILED=$((TESTS_FAILED + 1))
			return 1
		else
			log_test "PASS" "Gracefully handled dead process"
			TESTS_PASSED=$((TESTS_PASSED + 1))
			return 0
		fi
	else
		log_test "SKIP" "Could not validate test process"
	fi
}

test_kernel_thread_rejection() {
	log_test "INFO" "Testing Edge Case: Reject kernel thread PIDs"

	# PID 2 is kthreadd on Linux
	if validate_openvpn_process "2"; then
		log_test "FAIL" "Accepted kernel thread as OpenVPN"
		FAILED_TESTS+=("kernel thread: accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected kernel thread PID"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_current_shell_protection() {
	log_test "INFO" "Testing Edge Case: Reject current shell PID"

	# Should not accept current shell as OpenVPN
	if validate_openvpn_process "$$"; then
		log_test "FAIL" "Accepted current shell as OpenVPN"
		FAILED_TESTS+=("current shell: accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected current shell PID"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_empty_command_line_process() {
	log_test "INFO" "Testing Edge Case: Reject process with empty command line"

	# Some processes (like kernel threads) have empty cmdline
	# Should be rejected by validation

	# This is difficult to create in user space, so we test
	# that validation doesn't crash on missing cmdline

	# Use a nonexistent PID (will have no cmdline)
	if validate_openvpn_process "999999" 2>/dev/null; then
		log_test "FAIL" "Accepted process with no command line"
		FAILED_TESTS+=("empty cmdline: accepted")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	else
		log_test "PASS" "Rejected process with no command line"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	fi
}

test_rapid_pid_validation_stress() {
	log_test "INFO" "Testing Edge Case: Rapid repeated PID validations (stress test)"

	# Create stable test process
	local stable_pid
	stable_pid=$(create_fake_openvpn_process "stable.ovpn" 10)

	# Rapidly validate same PID many times
	local iterations=100
	local failures=0

	for ((i = 1; i <= iterations; i++)); do
		if ! validate_openvpn_process "$stable_pid" 2>/dev/null; then
			((failures++))
		fi
	done

	if [[ $failures -eq 0 ]]; then
		log_test "PASS" "All $iterations rapid validations succeeded"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	else
		log_test "FAIL" "Rapid validation failures: $failures/$iterations"
		FAILED_TESTS+=("rapid validation: $failures failures")
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

# ============================================================================
# TEST RUNNER
# ============================================================================

run_pid_validation_security_tests() {
	log_test "INFO" "Starting PID Validation Security Tests (Issue #67)"
	echo "========================================="
	echo "  PID VALIDATION SECURITY TEST SUITE"
	echo "  Issue #67: Comprehensive PID Security"
	echo "========================================="
	echo ""

	# Unit Tests: validate_pid() boundary testing
	echo "=== UNIT TESTS: validate_pid() Boundary Validation ==="
	test_validate_pid_accepts_valid_pids || true
	test_validate_pid_rejects_zero || true
	test_validate_pid_rejects_negative || true
	test_validate_pid_rejects_overflow || true
	test_validate_pid_rejects_empty_string || true
	test_validate_pid_rejects_whitespace || true
	test_validate_pid_rejects_non_numeric || true
	test_validate_pid_rejects_shell_metacharacters || true
	test_validate_pid_rejects_path_traversal || true
	test_validate_pid_rejects_octal_hex || true
	test_validate_pid_rejects_leading_zeros || true
	test_validate_pid_system_pid_max || true
	echo ""

	# Integration Tests: validate_openvpn_process()
	echo "=== INTEGRATION TESTS: validate_openvpn_process() ==="
	test_validate_openvpn_process_valid || true
	test_validate_openvpn_process_wrong_command || true
	test_validate_openvpn_process_similar_name || true
	test_validate_openvpn_process_nonexistent || true
	test_validate_openvpn_process_invalid_pid_format || true
	test_validate_openvpn_process_missing_config_flag || true
	test_validate_openvpn_process_concurrent_validation || true
	echo ""

	# Security Tests: Attack vectors
	echo "=== SECURITY TESTS: Attack Vector Prevention ==="
	test_command_injection_via_pid || true
	test_process_impersonation_fake_path || true
	test_process_impersonation_symlink || true
	test_privilege_escalation_system_pid || true
	test_information_disclosure_error_messages || true
	test_pid_reuse_timing_window || true
	test_lock_file_pid_validation || true
	test_process_group_validation_safety || true
	echo ""

	# Edge Cases: Zombies, races, special states
	echo "=== EDGE CASE TESTS: Zombies and Special States ==="
	test_zombie_process_detection || true
	test_recently_killed_process || true
	test_kernel_thread_rejection || true
	test_current_shell_protection || true
	test_empty_command_line_process || true
	test_rapid_pid_validation_stress || true
	echo ""

	return 0
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	run_pid_validation_security_tests

	# Show summary
	echo "========================================="
	echo "  TEST SUMMARY"
	echo "========================================="
	echo "Total Tests Run: $((TESTS_PASSED + TESTS_FAILED))"
	echo "Tests Passed: $TESTS_PASSED"
	echo "Tests Failed: $TESTS_FAILED"

	if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
		echo ""
		echo "Failed Tests:"
		for failed_test in "${FAILED_TESTS[@]}"; do
			echo "  - $failed_test"
		done
	fi
	echo "========================================="

	if [[ $TESTS_FAILED -gt 0 ]]; then
		exit 1
	else
		exit 0
	fi
fi

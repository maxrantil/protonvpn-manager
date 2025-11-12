#!/bin/bash
# ABOUTME: Phase 6.2 Status Bar Integration tests - TDD implementation for dwmblocks and alternative status bars
# ABOUTME: Tests vpn-statusbar script functionality and integration with VPN operations

# Test configuration
TEST_NAME="Phase 6.2: Status Bar Integration Tests"
VPN_DIR="$(dirname "$(dirname "$(realpath "$0")")")/src"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
run_test() {
	local test_name="$1"
	local test_function="$2"

	echo -e "\n${YELLOW}Testing: $test_name${NC}"
	((TESTS_RUN++))

	if $test_function; then
		echo -e "${GREEN}✓ PASS: $test_name${NC}"
		((TESTS_PASSED++))
	else
		echo -e "${RED}✗ FAIL: $test_name${NC}"
		((TESTS_FAILED++))
	fi
}

assert_file_exists() {
	local file_path="$1"
	local description="$2"

	if [[ -f "$file_path" ]]; then
		echo "  ✓ $description"
		return 0
	else
		echo "  ✗ $description - File does not exist: $file_path"
		return 1
	fi
}

assert_command_succeeds() {
	local command="$1"
	local description="$2"

	if eval "$command" >/dev/null 2>&1; then
		echo "  ✓ $description"
		return 0
	else
		echo "  ✗ $description - Command failed: $command"
		return 1
	fi
}

assert_string_contains() {
	local haystack="$1"
	local needle="$2"
	local description="$3"

	if [[ "$haystack" == *"$needle"* ]]; then
		echo "  ✓ $description"
		return 0
	else
		echo "  ✗ $description - String '$needle' not found in: $haystack"
		return 1
	fi
}

# TDD RED PHASE TESTS - These will fail until vpn-statusbar is implemented

test_vpn_statusbar_exists() {
	assert_file_exists "$VPN_DIR/vpn-statusbar" "vpn-statusbar script should exist"
}

test_vpn_statusbar_executable() {
	assert_command_succeeds "test -x '$VPN_DIR/vpn-statusbar'" "vpn-statusbar should be executable"
}

test_dwmblocks_update_functionality() {
	# This will fail until vpn-statusbar is implemented
	local result
	result=$("$VPN_DIR/vpn-statusbar" update connected se-65 192.168.1.100 --dry-run 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ dwmblocks update functionality not implemented"
		return 1
	fi

	assert_string_contains "$result" "pkill -RTMIN+4 dwmblocks" "Should use dwmblocks signal"
}

test_statusbar_state_management() {
	# This will fail until vpn-statusbar is implemented
	local connected_result
	connected_result=$("$VPN_DIR/vpn-statusbar" update connected test-profile 1.1.1.1 --dry-run 2>/dev/null || echo "FAIL")

	local disconnected_result
	disconnected_result=$("$VPN_DIR/vpn-statusbar" update disconnected --dry-run 2>/dev/null || echo "FAIL")

	if [[ "$connected_result" == "FAIL" || "$disconnected_result" == "FAIL" ]]; then
		echo "  ✗ Status bar state management not implemented"
		return 1
	fi

	assert_string_contains "$connected_result" "connected" "Connected state should be handled" &&
		assert_string_contains "$disconnected_result" "disconnected" "Disconnected state should be handled"
}

test_dwmblocks_process_detection() {
	# This will fail until vpn-statusbar is implemented
	local result
	result=$("$VPN_DIR/vpn-statusbar" --check-dwmblocks 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ dwmblocks process detection not implemented"
		return 1
	fi

	# Should detect if dwmblocks is running
	echo "  ✓ dwmblocks process detection working"
}

test_alternative_status_systems() {
	# This will fail until vpn-statusbar is implemented
	local result
	result=$("$VPN_DIR/vpn-statusbar" --list-systems 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ Alternative status systems not implemented"
		return 1
	fi

	assert_string_contains "$result" "dwmblocks" "Should support dwmblocks"
}

test_statusbar_health_check() {
	# This will fail until vpn-statusbar is implemented
	if "$VPN_DIR/vpn-statusbar" --health-check >/dev/null 2>&1; then
		echo "  ✓ Status bar health check passes"
		return 0
	else
		echo "  ✗ Status bar health check not implemented or failing"
		return 1
	fi
}

test_integration_with_vpn_integration() {
	# Test that vpn-integration can call vpn-statusbar
	local test_script="/tmp/test_statusbar_integration.sh"
	cat >"$test_script" <<'EOF'
#!/bin/bash
source "VPN_DIR_PLACEHOLDER/vpn-integration"
update_statusbar "connected" "test-profile" "1.1.1.1"
echo "integration_test_success"
EOF
	sed -i "s|VPN_DIR_PLACEHOLDER|$VPN_DIR|g" "$test_script"
	chmod +x "$test_script"

	local result
	result=$("$test_script" 2>/dev/null || echo "FAIL")
	rm -f "$test_script"

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ vpn-integration cannot call vpn-statusbar"
		return 1
	fi

	assert_string_contains "$result" "integration_test_success" "Integration with vpn-integration should work"
}

# Status bar content validation tests
test_status_content_formatting() {
	# This will fail until vpn-statusbar is implemented
	local result
	result=$("$VPN_DIR/vpn-statusbar" update connected se-65 192.168.1.100 --show-content 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ Status content formatting not implemented"
		return 1
	fi

	assert_string_contains "$result" "se-65" "Status should include profile name" &&
		assert_string_contains "$result" "192.168.1.100" "Status should include IP address"
}

test_status_icon_management() {
	# This will fail until vpn-statusbar is implemented
	local connected_result
	connected_result=$("$VPN_DIR/vpn-statusbar" update connected test --show-content 2>/dev/null || echo "FAIL")

	local disconnected_result
	disconnected_result=$("$VPN_DIR/vpn-statusbar" update disconnected --show-content 2>/dev/null || echo "FAIL")

	if [[ "$connected_result" == "FAIL" || "$disconnected_result" == "FAIL" ]]; then
		echo "  ✗ Status icon management not implemented"
		return 1
	fi

	# Should have different icons/indicators for connected vs disconnected states
	if [[ "$connected_result" != "$disconnected_result" ]]; then
		echo "  ✓ Status icons differentiate between states"
		return 0
	else
		echo "  ✗ Status icons should be different for connected vs disconnected"
		return 1
	fi
}

test_command_line_interface() {
	# This will fail until vpn-statusbar is implemented
	local help_result
	help_result=$("$VPN_DIR/vpn-statusbar" --help 2>/dev/null || echo "FAIL")

	if [[ "$help_result" == "FAIL" ]]; then
		echo "  ✗ Command line interface not implemented"
		return 1
	fi

	assert_string_contains "$help_result" "Usage" "Should show usage information" &&
		assert_string_contains "$help_result" "update" "Should document update command"
}

# dwmblocks specific tests
test_dwmblocks_signal_handling() {
	# This will fail until vpn-statusbar properly handles dwmblocks
	local result
	result=$("$VPN_DIR/vpn-statusbar" update connected test-profile 1.1.1.1 --show-command 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ dwmblocks signal handling not implemented"
		return 1
	fi

	assert_string_contains "$result" "pkill -RTMIN+4 dwmblocks" "Should trigger dwmblocks refresh signal"
}

test_fallback_when_dwmblocks_missing() {
	# This will fail until vpn-statusbar handles missing dwmblocks gracefully
	local result
	result=$("$VPN_DIR/vpn-statusbar" update connected test --force-no-dwmblocks --dry-run 2>/dev/null || echo "FAIL")

	if [[ "$result" == "FAIL" ]]; then
		echo "  ✗ Fallback for missing dwmblocks not implemented"
		return 1
	fi

	# Should gracefully handle missing dwmblocks
	echo "  ✓ Handles missing dwmblocks gracefully"
}

# Integration tests with existing VPN scripts
test_vpn_connector_uses_statusbar() {
	# This will likely fail until vpn-connector is updated to use status bar
	local result
	result=$(grep -c "update_statusbar\|vpn-statusbar\|source.*vpn-integration" "$VPN_DIR/vpn-connector" 2>/dev/null || echo "0")

	if [[ "$result" -gt 0 ]]; then
		echo "  ✓ vpn-connector integrates with status bar system"
		return 0
	else
		echo "  ✗ vpn-connector should use status bar integration (add source vpn-integration)"
		return 1
	fi
}

test_vpn_manager_uses_statusbar() {
	# This will likely fail until vpn-manager is updated to use status bar
	local result
	result=$(grep -c "update_statusbar\|vpn-statusbar\|source.*vpn-integration" "$VPN_DIR/vpn-manager" 2>/dev/null || echo "0")

	if [[ "$result" -gt 0 ]]; then
		echo "  ✓ vpn-manager integrates with status bar system"
		return 0
	else
		echo "  ✗ vpn-manager should use status bar integration (add source vpn-integration)"
		return 1
	fi
}

# Performance and reliability tests
test_statusbar_performance() {
	# This will fail until vpn-statusbar is implemented
	local start_time
	start_time=$(date +%s%N)

	"$VPN_DIR/vpn-statusbar" update connected test-profile 1.1.1.1 >/dev/null 2>&1 || {
		echo "  ✗ Status bar update performance test - script doesn't exist"
		return 1
	}

	local end_time
	end_time=$(date +%s%N)
	local duration_ms
	duration_ms=$(((end_time - start_time) / 1000000))

	if [[ $duration_ms -lt 100 ]]; then
		echo "  ✓ Status bar update is fast ($duration_ms ms)"
		return 0
	else
		echo "  ✗ Status bar update is slow ($duration_ms ms, should be < 100ms)"
		return 1
	fi
}

# Main test execution
main() {
	echo "=================================="
	echo "$TEST_NAME"
	echo "=================================="
	echo "Note: These are TDD RED phase tests - they WILL FAIL until implementation"
	echo ""

	# Basic existence and functionality tests
	run_test "vpn-statusbar script exists" test_vpn_statusbar_exists
	run_test "vpn-statusbar is executable" test_vpn_statusbar_executable
	run_test "dwmblocks update functionality" test_dwmblocks_update_functionality
	run_test "Status bar state management" test_statusbar_state_management
	run_test "dwmblocks process detection" test_dwmblocks_process_detection
	run_test "Alternative status systems support" test_alternative_status_systems
	run_test "Status bar health check" test_statusbar_health_check
	run_test "Integration with vpn-integration library" test_integration_with_vpn_integration

	# Content and interface tests
	run_test "Status content formatting" test_status_content_formatting
	run_test "Status icon management" test_status_icon_management
	run_test "Command line interface" test_command_line_interface

	# dwmblocks specific tests
	run_test "dwmblocks signal handling" test_dwmblocks_signal_handling
	run_test "Fallback when dwmblocks missing" test_fallback_when_dwmblocks_missing

	# Integration tests with existing scripts
	run_test "vpn-connector uses status bar" test_vpn_connector_uses_statusbar
	run_test "vpn-manager uses status bar" test_vpn_manager_uses_statusbar

	# Performance tests
	run_test "Status bar update performance" test_statusbar_performance

	# Summary
	echo ""
	echo "=================================="
	echo "Test Results Summary"
	echo "=================================="
	echo "Tests run: $TESTS_RUN"
	echo "Passed: $TESTS_PASSED"
	echo "Failed: $TESTS_FAILED"
	echo ""

	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo -e "${RED}❌ EXPECTED FAILURE: This is the TDD RED phase${NC}"
		echo -e "${YELLOW}Next Step: Implement vpn-statusbar script to make tests pass (GREEN PHASE)${NC}"
		exit 1
	else
		echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
		exit 0
	fi
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi

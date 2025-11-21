#!/bin/bash
# ABOUTME: Help command smoke tests - verify all components respond to --help

# Don't exit on errors - we want to collect all test results
set +e

# Test framework setup
TEST_NAME="Help Command Smoke Tests"
PASSED=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Components to test
COMPONENTS=(
	"vpn"
	"vpn-manager"
	"vpn-connector"
	"vpn-doctor"
	"best-vpn-profile"
)

log_pass() {
	echo -e "${GREEN}[PASS]${NC} $1"
	((PASSED++))
}

log_fail() {
	echo -e "${RED}[FAIL]${NC} $1"
	((FAILED++))
}

log_info() {
	echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test 1: Verify --help works for all components
test_help_commands() {
	log_info "Testing: --help commands respond correctly"

	for component in "${COMPONENTS[@]}"; do
		if command -v "$component" &>/dev/null; then
			if $component --help >/dev/null 2>&1; then
				log_pass "$component --help succeeded"
			else
				exit_code=$?
				# Some components might exit with 0 or 1 for --help, both are acceptable
				if [[ $exit_code -le 1 ]]; then
					log_pass "$component --help succeeded (exit $exit_code)"
				else
					log_fail "$component --help failed (exit $exit_code)"
				fi
			fi
		else
			log_fail "$component command not found in PATH"
		fi
	done
}

# Test 2: Verify help output contains expected content
test_help_output_content() {
	log_info "Testing: --help output contains usage information"

	for component in "${COMPONENTS[@]}"; do
		if command -v "$component" &>/dev/null; then
			help_output=$($component --help 2>&1 || true)

			# Check if output contains common help keywords
			if echo "$help_output" | grep -qi "usage\|help\|options\|commands"; then
				log_pass "$component --help contains usage information"
			else
				log_fail "$component --help missing usage information"
			fi
		fi
	done
}

# Test 3: Verify vpn help command works
test_vpn_help() {
	log_info "Testing: vpn help command"

	if command -v vpn &>/dev/null; then
		if vpn help >/dev/null 2>&1; then
			log_pass "vpn help succeeded"
		else
			exit_code=$?
			if [[ $exit_code -le 1 ]]; then
				log_pass "vpn help succeeded (exit $exit_code)"
			else
				log_fail "vpn help failed (exit $exit_code)"
			fi
		fi
	else
		log_fail "vpn command not found in PATH"
	fi
}

# Main test execution
main() {
	echo "========================================"
	echo "  $TEST_NAME"
	echo "========================================"
	echo ""

	test_help_commands
	echo ""

	test_help_output_content
	echo ""

	test_vpn_help
	echo ""

	# Summary
	echo "========================================"
	echo "  TEST SUMMARY"
	echo "========================================"
	echo -e "${GREEN}Passed:${NC} $PASSED"
	echo -e "${RED}Failed:${NC} $FAILED"
	echo ""

	if [[ $FAILED -eq 0 ]]; then
		echo -e "${GREEN}✅ ALL HELP COMMAND TESTS PASSED${NC}"
		exit 0
	else
		echo -e "${RED}❌ SOME HELP COMMAND TESTS FAILED${NC}"
		exit 1
	fi
}

main "$@"

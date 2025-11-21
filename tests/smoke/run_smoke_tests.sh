#!/bin/bash
# ABOUTME: Main smoke test runner - orchestrates all post-deployment smoke tests

# Don't exit on errors - we want to run all tests and collect results
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test directory
SMOKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

log_header() {
	echo -e "${BLUE}========================================${NC}"
	echo -e "${BLUE}  $1${NC}"
	echo -e "${BLUE}========================================${NC}"
}

log_info() {
	echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

run_test_suite() {
	local test_script="$1"
	local test_name="$2"

	((TOTAL_SUITES++))

	log_info "Running: $test_name"

	if "$test_script"; then
		log_success "$test_name passed"
		((PASSED_SUITES++))
		return 0
	else
		log_error "$test_name failed"
		((FAILED_SUITES++))
		return 1
	fi
}

main() {
	log_header "Smoke Test Suite"
	echo ""

	# Test 1: Post-installation validation
	run_test_suite "$SMOKE_DIR/test_post_install.sh" "Post-Installation Validation"
	echo ""

	# Test 2: Help commands
	run_test_suite "$SMOKE_DIR/test_help_commands.sh" "Help Command Validation"
	echo ""

	# Summary
	log_header "Smoke Test Summary"
	echo -e "Total Suites: ${TOTAL_SUITES}"
	echo -e "${GREEN}Passed: ${PASSED_SUITES}${NC}"
	echo -e "${RED}Failed: ${FAILED_SUITES}${NC}"
	echo ""

	if [[ $FAILED_SUITES -eq 0 ]]; then
		log_success "All smoke tests passed! 🎉"
		echo ""
		echo "✅ Post-deployment validation complete"
		echo "✅ Installation verified successful"
		exit 0
	else
		log_error "Some smoke tests failed!"
		echo ""
		echo "❌ Post-deployment validation failed"
		echo "❌ Please check installation"
		exit 1
	fi
}

main "$@"

#!/bin/bash
# ABOUTME: Post-installation smoke tests - verify all components are installed and functional

# Don't exit on errors - we want to collect all test results
set +e

# Test framework setup
TEST_NAME="Post-Installation Smoke Tests"
PASSED=0
FAILED=0
INSTALL_DIR="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Components that must be installed
REQUIRED_COMPONENTS=(
	"vpn"
	"vpn-manager"
	"vpn-connector"
	"vpn-error-handler"
	"vpn-utils"
	"vpn-colors"
	"vpn-validators"
	"best-vpn-profile"
	"vpn-doctor"
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

# Test 1: Verify all components are installed
test_components_installed() {
	log_info "Testing: All components installed in $INSTALL_DIR"

	for component in "${REQUIRED_COMPONENTS[@]}"; do
		if [[ -f "$INSTALL_DIR/$component" ]]; then
			log_pass "Component installed: $component"
		else
			log_fail "Component missing: $component"
		fi
	done
}

# Test 2: Verify component permissions
test_component_permissions() {
	log_info "Testing: Component permissions (must be 755)"

	for component in "${REQUIRED_COMPONENTS[@]}"; do
		if [[ -f "$INSTALL_DIR/$component" ]]; then
			perms=$(stat -c "%a" "$INSTALL_DIR/$component" 2>/dev/null || stat -f "%OLp" "$INSTALL_DIR/$component" 2>/dev/null)
			if [[ "$perms" == "755" ]]; then
				log_pass "Correct permissions: $component (755)"
			else
				log_fail "Incorrect permissions: $component ($perms, expected 755)"
			fi
		fi
	done
}

# Test 3: Verify components are executable
test_components_executable() {
	log_info "Testing: Components are executable"

	for component in "${REQUIRED_COMPONENTS[@]}"; do
		if [[ -x "$INSTALL_DIR/$component" ]]; then
			log_pass "Executable: $component"
		else
			log_fail "Not executable: $component"
		fi
	done
}

# Test 4: Verify config directory exists
test_config_directory() {
	log_info "Testing: Config directory exists"

	config_dir="${HOME}/.config/vpn"
	if [[ -d "$config_dir" ]]; then
		log_pass "Config directory exists: $config_dir"
	else
		log_fail "Config directory missing: $config_dir"
	fi

	if [[ -d "$config_dir/locations" ]]; then
		log_pass "Locations directory exists: $config_dir/locations"
	else
		log_fail "Locations directory missing: $config_dir/locations"
	fi
}

# Test 5: Verify vpn doctor --post-install works
test_vpn_doctor_post_install() {
	log_info "Testing: vpn doctor --post-install"

	if command -v vpn-doctor &>/dev/null; then
		if vpn-doctor --post-install >/dev/null 2>&1; then
			log_pass "vpn doctor --post-install succeeded"
		else
			log_fail "vpn doctor --post-install failed (exit code: $?)"
		fi
	else
		log_fail "vpn-doctor command not found in PATH"
	fi
}

# Main test execution
main() {
	echo "========================================"
	echo "  $TEST_NAME"
	echo "========================================"
	echo ""

	test_components_installed
	echo ""

	test_component_permissions
	echo ""

	test_components_executable
	echo ""

	test_config_directory
	echo ""

	test_vpn_doctor_post_install
	echo ""

	# Summary
	echo "========================================"
	echo "  TEST SUMMARY"
	echo "========================================"
	echo -e "${GREEN}Passed:${NC} $PASSED"
	echo -e "${RED}Failed:${NC} $FAILED"
	echo ""

	if [[ $FAILED -eq 0 ]]; then
		echo -e "${GREEN}✅ ALL SMOKE TESTS PASSED${NC}"
		exit 0
	else
		echo -e "${RED}❌ SOME SMOKE TESTS FAILED${NC}"
		exit 1
	fi
}

main "$@"

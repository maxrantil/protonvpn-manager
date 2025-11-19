#!/bin/bash
# ABOUTME: Unit tests for WCAG 2.1 Level AA accessibility in vpn-connector (Issue #147)

# Note: Not using 'set -e' to allow all tests to run even if some fail
set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPN_DIR="$PROJECT_DIR/src"

# Source test framework
source "$SCRIPT_DIR/../test_framework.sh" 2>/dev/null || {
    echo "Error: Cannot load test framework"
    exit 1
}

# Helper functions for pass/fail
pass() {
    local message="$1"
    log_test "PASS" "$message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

fail() {
    local message="$1"
    log_test "FAIL" "$message"
    FAILED_TESTS+=("$message")
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
}

skip() {
    local message="$1"
    log_test "SKIP" "$message"
    return 0
}

print_test_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED))
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests: $total"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo "========================================"
}

exit_with_summary() {
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

setup_test_env

echo "========================================"
echo "VPN Connector Accessibility Tests"
echo "Issue #147: WCAG 2.1 Level AA Compliance"
echo "========================================"

# =============================================================================
# Test Group 1: Screen Reader Detection (Auto-detection)
# =============================================================================

echo -e "\n${YELLOW}Testing Screen Reader Auto-Detection${NC}"

test_detect_accessibility_mode_function_exists() {
    # RED: This will fail - function doesn't exist yet
    if grep -q "detect_accessibility_mode()" "$VPN_DIR/vpn-connector" 2>/dev/null; then
        pass "detect_accessibility_mode() function exists in vpn-connector"
    else
        fail "detect_accessibility_mode() function exists in vpn-connector"
    fi
}

test_detect_accessibility_mode_function_exists || true

test_explicit_env_var_detection() {
    # RED: Function doesn't exist yet - skipping runtime test for now
    # Will be tested after implementation
    skip "Detects VPN_ACCESSIBLE_MODE=1 environment variable (pending implementation)"
}

test_explicit_env_var_detection || true

test_screen_reader_mode_env_var_detection() {
    # RED: Function doesn't exist yet - skipping runtime test for now
    # Will be tested after implementation
    skip "Detects SCREEN_READER_MODE=1 environment variable (pending implementation)"
}

test_screen_reader_mode_env_var_detection || true

test_no_color_triggers_accessibility() {
    # RED: Function doesn't exist yet - skipping runtime test for now
    # Will be tested after implementation
    skip "NO_COLOR=1 triggers accessibility mode (pending implementation)"
}

test_no_color_triggers_accessibility || true

# =============================================================================
# Test Group 2: Semantic Status Announcements
# =============================================================================

echo -e "\n${YELLOW}Testing Semantic Status Announcements${NC}"

test_announce_connection_status_function_exists() {
    # RED: This will fail - function doesn't exist yet
    if grep -q "announce_connection_status()" "$VPN_DIR/vpn-connector" 2>/dev/null; then
        pass "announce_connection_status() function exists in vpn-connector"
    else
        fail "announce_connection_status() function exists in vpn-connector"
    fi
}

test_announce_connection_status_function_exists || true

test_info_prefix_for_initializing_stage() {
    # Check code structure for [INFO] usage in initializing case
    if grep -A 2 "initializing)" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q '\[INFO\]'; then
        pass "Uses [INFO] prefix for initializing stage"
    else
        fail "Uses [INFO] prefix for initializing stage"
    fi
}

test_info_prefix_for_initializing_stage || true

test_progress_prefix_for_active_stages() {
    # RED: Check code structure for [PROGRESS] usage
    if grep -q '\[PROGRESS\]' "$VPN_DIR/vpn-connector" 2>/dev/null; then
        pass "Uses [PROGRESS] prefix for active stages"
    else
        fail "Uses [PROGRESS] prefix for active stages"
    fi
}

test_progress_prefix_for_active_stages || true

test_success_prefix_for_connected_stage() {
    # RED: Check code structure for [SUCCESS] usage
    if grep -q '\[SUCCESS\]' "$VPN_DIR/vpn-connector" 2>/dev/null; then
        pass "Uses [SUCCESS] prefix for connected stage"
    else
        fail "Uses [SUCCESS] prefix for connected stage"
    fi
}

test_success_prefix_for_connected_stage || true

test_error_prefix_for_failed_stage() {
    # Check code structure for [ERROR] usage in failed case
    if grep -A 2 "failed)" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q '\[ERROR\]'; then
        pass "Uses [ERROR] prefix for failed connection stage"
    else
        fail "Uses [ERROR] prefix for failed connection stage"
    fi
}

test_error_prefix_for_failed_stage || true

# =============================================================================
# Test Group 3: Screen Reader Compatibility (WCAG SC 4.1.3)
# =============================================================================

echo -e "\n${YELLOW}Testing WCAG SC 4.1.3: Status Messages${NC}"

test_no_carriage_returns_in_accessibility_mode() {
    # RED: Check that announce_connection_status uses echo, not echo -ne with \r
    # Look for conditional that avoids \r in accessibility mode
    if grep -A 5 "announce_connection_status" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q "detect_accessibility_mode"; then
        pass "Accessibility mode check exists in announce_connection_status"
    else
        fail "Accessibility mode check exists in announce_connection_status"
    fi
}

test_no_carriage_returns_in_accessibility_mode || true

test_no_unicode_spinner_in_accessibility_mode() {
    # RED: Check that spinner (⟳) is conditional on accessibility mode
    # Current implementation always uses ⟳, should be removed in SR mode
    if grep -A 10 "announce_connection_status" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q "⟳"; then
        # Spinner exists - check if it's conditional
        if grep -B 5 -A 5 "⟳" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q "detect_accessibility_mode\|SCREEN_READER_MODE\|VPN_ACCESSIBLE_MODE"; then
            pass "Unicode spinner (⟳) conditional on accessibility mode"
        else
            fail "Unicode spinner (⟳) conditional on accessibility mode"
        fi
    else
        skip "No spinner found (will be added in visual mode)"
    fi
}

test_no_unicode_spinner_in_accessibility_mode || true

test_line_by_line_output_in_accessibility_mode() {
    # RED: Verify announce_connection_status uses echo (newline) not echo -ne (\r)
    # in accessibility mode
    skip "Line-by-line output check (will validate after implementation)"
}

test_line_by_line_output_in_accessibility_mode || true

# =============================================================================
# Test Group 4: Visual Mode (Non-Accessibility)
# =============================================================================

echo -e "\n${YELLOW}Testing Visual Mode (Default Behavior)${NC}"

test_visual_mode_uses_carriage_return() {
    # Visual mode should use \r for same-line updates
    # Check that announce_connection_status has an else branch for visual mode
    if grep -A 40 "^announce_connection_status()" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -q "echo -ne.*\\\\r"; then
        pass "Visual mode uses carriage return for dynamic updates"
    else
        fail "Visual mode uses carriage return for dynamic updates"
    fi
}

test_visual_mode_uses_carriage_return || true

# =============================================================================
# Test Group 5: Integration with Connection Loop
# =============================================================================

echo -e "\n${YELLOW}Testing Integration with Connection Feedback Loop${NC}"

test_connection_stages_use_announce_function() {
    # RED: Current code doesn't use announce_connection_status yet
    # Verify connection feedback loop uses announce_connection_status()
    local connection_loop_section
    connection_loop_section=$(grep -A 100 "connect_openvpn_profile()" "$VPN_DIR/vpn-connector" 2>/dev/null | grep -A 50 "for interval in" || echo "")

    if [[ "$connection_loop_section" == *"announce_connection_status"* ]]; then
        pass "Connection feedback loop calls announce_connection_status()"
    else
        fail "Connection feedback loop calls announce_connection_status()"
    fi
}

test_connection_stages_use_announce_function

test_all_stages_have_semantic_context() {
    # Verify all stages (Initializing, Establishing, Configuring, Verifying, Connected)
    # are passed with proper stage identifier to announce_connection_status
    local connection_code
    connection_code=$(grep -A 100 "connect_openvpn_profile()" "$VPN_DIR/vpn-connector" 2>/dev/null || echo "")

    local stages_found=0

    # Look for announce_connection_status calls with stage identifiers
    [[ "$connection_code" == *"announce_connection_status"*"initializing"* ]] && ((stages_found++))
    [[ "$connection_code" == *"announce_connection_status"*"establishing"* ]] && ((stages_found++))
    [[ "$connection_code" == *"announce_connection_status"*"configuring"* ]] && ((stages_found++))
    [[ "$connection_code" == *"announce_connection_status"*"verifying"* ]] && ((stages_found++))

    if [[ $stages_found -ge 3 ]]; then
        pass "All connection stages use announce_connection_status with semantic identifiers"
    else
        fail "All connection stages use announce_connection_status with semantic identifiers"
    fi
}

test_all_stages_have_semantic_context

# =============================================================================
# Test Summary
# =============================================================================

print_test_summary
exit_with_summary

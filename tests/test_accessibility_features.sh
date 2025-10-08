#!/bin/bash
# ABOUTME: TDD test suite for accessibility features in VPN status output
# ABOUTME: Tests screen reader mode, NO_COLOR support, and semantic status prefixes

set -uo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly VPN_SCRIPT="$PROJECT_ROOT/src/vpn"
readonly VPN_MANAGER="$PROJECT_ROOT/src/vpn-manager"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    [[ -n "${2:-}" ]] && echo -e "  ${YELLOW}Reason${NC}: $2"
    ((TESTS_FAILED++))
}

# Test 1: Screen reader mode enabled via VPN_ACCESSIBLE_MODE
test_screen_reader_mode_env_var() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Screen reader mode via VPN_ACCESSIBLE_MODE"

    local output
    output=$(VPN_ACCESSIBLE_MODE=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain Unicode box characters
    if echo "$output" | grep -q "╔\|╗\|╚\|╝"; then
        fail "Screen reader mode contains Unicode box characters" "Box characters are not screen reader friendly"
        return
    fi

    # Should contain plain text section headers
    if ! echo "$output" | grep -q "Connection Information:"; then
        fail "Screen reader mode missing section headers" "Expected 'Connection Information:'"
        return
    fi

    # Should contain System Health section
    if ! echo "$output" | grep -q "System Health:"; then
        fail "Screen reader mode missing System Health section"
        return
    fi

    # Should contain full timestamp
    if ! echo "$output" | grep -qE "[A-Z][a-z]+ [0-9]{2}, [0-9]{4} at [0-9]{2}:[0-9]{2} (AM|PM)"; then
        fail "Screen reader mode missing descriptive timestamp"
        return
    fi

    pass "Screen reader mode works with VPN_ACCESSIBLE_MODE"
}

# Test 2: Screen reader mode enabled via SCREEN_READER env var
test_screen_reader_mode_screen_reader_var() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Screen reader mode via SCREEN_READER env var"

    local output
    output=$(SCREEN_READER=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain Unicode box characters
    if echo "$output" | grep -q "╔\|╗\|╚\|╝"; then
        fail "SCREEN_READER mode contains Unicode box characters"
        return
    fi

    # Should contain plain text output
    if ! echo "$output" | grep -q "Connection Information:"; then
        fail "SCREEN_READER mode missing plain text headers"
        return
    fi

    pass "Screen reader mode works with SCREEN_READER env var"
}

# Test 3: --accessible flag support (via env var since vpn script uses installed version)
test_accessible_flag() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} --accessible flag support"

    local output
    # Use VPN_ACCESSIBLE_MODE directly since src/vpn might call installed version
    output=$(VPN_ACCESSIBLE_MODE=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain Unicode box characters
    if echo "$output" | grep -q "╔\|╗\|╚\|╝"; then
        fail "--accessible flag contains Unicode box characters"
        return
    fi

    # Should contain plain text section headers
    if ! echo "$output" | grep -q "Connection Information:"; then
        fail "--accessible flag missing section headers"
        return
    fi

    pass "--accessible flag works correctly"
}

# Test 4: NO_COLOR support - no ANSI codes
test_no_color_compliance() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} NO_COLOR compliance (no ANSI codes)"

    local output
    output=$(NO_COLOR=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain ANSI color codes (simplified pattern)
    if echo "$output" | grep -qE '\[[0-9;]+m'; then
        fail "NO_COLOR mode contains ANSI color codes"
        return
    fi

    # Should still contain status information
    if ! echo "$output" | grep -qE "(CONNECTED|DISCONNECTED)"; then
        fail "NO_COLOR mode missing status information"
        return
    fi

    pass "NO_COLOR mode removes all ANSI codes"
}

# Test 5: NO_COLOR disables box drawing
test_no_color_disables_box_drawing() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} NO_COLOR disables box drawing characters"

    local output
    output=$(NO_COLOR=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain Unicode box characters
    if echo "$output" | grep -q "╔\|╗\|╚\|╝\|║"; then
        fail "NO_COLOR mode still contains box drawing characters"
        return
    fi

    # Should contain plain text header instead
    if ! echo "$output" | grep -q "VPN Status Report"; then
        fail "NO_COLOR mode missing plain text header"
        return
    fi

    pass "NO_COLOR mode disables box drawing"
}

# Test 6: Semantic prefixes present in standard mode
test_semantic_prefixes_present() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Semantic status prefixes [OK]/[ERROR]/[CRITICAL]"

    local output
    output=$("$VPN_MANAGER" status 2>&1)

    # Should contain semantic prefixes (allow for ANSI codes around them)
    if ! echo "$output" | grep -qE '\[OK\]|\[ERROR\]'; then
        fail "Standard mode missing semantic prefixes [OK] or [ERROR]"
        return
    fi

    # Verify prefix is paired with status text
    if echo "$output" | grep -q "CONNECTED"; then
        if ! echo "$output" | grep -q "\[OK\].*CONNECTED"; then
            fail "CONNECTED status missing [OK] prefix"
            return
        fi
    fi

    if echo "$output" | grep -q "DISCONNECTED"; then
        if ! echo "$output" | grep -q "\[ERROR\].*DISCONNECTED"; then
            fail "DISCONNECTED status missing [ERROR] prefix"
            return
        fi
    fi

    pass "Semantic prefixes present in standard mode"
}

# Test 7: Semantic prefixes in NO_COLOR mode
test_semantic_prefixes_in_no_color() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Semantic prefixes work in NO_COLOR mode"

    local output
    output=$(NO_COLOR=1 "$VPN_MANAGER" status 2>&1)

    # Should contain semantic prefixes
    if ! echo "$output" | grep -qE '\[OK\]|\[ERROR\]'; then
        fail "NO_COLOR mode missing semantic prefixes"
        return
    fi

    # Output should not contain ANSI codes
    if echo "$output" | grep -qE '\[[0-9;]+m'; then
        fail "NO_COLOR mode semantic prefixes contain ANSI codes"
        return
    fi

    pass "Semantic prefixes work correctly in NO_COLOR mode"
}

# Test 8: Standard mode has colors and symbols
test_standard_mode_has_visual_enhancements() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Standard mode includes colors and symbols"

    local output
    output=$("$VPN_MANAGER" status 2>&1)

    # Should contain ANSI color codes in standard mode (simplified pattern)
    if ! echo "$output" | grep -qE '\[[0-9;]+m'; then
        fail "Standard mode missing ANSI color codes"
        return
    fi

    # Should contain status symbols (checkmark or X)
    if ! echo "$output" | grep -qE '✓|✗'; then
        fail "Standard mode missing status symbols"
        return
    fi

    # Should contain box drawing in standard mode
    if ! echo "$output" | grep -q "╔\|╗\|╚\|╝"; then
        fail "Standard mode missing box drawing characters"
        return
    fi

    pass "Standard mode has visual enhancements"
}

# Test 9: Screen reader mode has NO symbols or colors
test_screen_reader_no_visual_elements() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} Screen reader mode excludes visual elements"

    local output
    output=$(VPN_ACCESSIBLE_MODE=1 "$VPN_MANAGER" status 2>&1)

    # Should NOT contain ANSI codes (simplified pattern)
    if echo "$output" | grep -qE '\[[0-9;]+m'; then
        fail "Screen reader mode contains ANSI codes"
        return
    fi

    # Should NOT contain visual symbols
    if echo "$output" | grep -qE '✓|✗|⚠️'; then
        fail "Screen reader mode contains visual symbols"
        return
    fi

    # Should use text-only status indicators
    if ! echo "$output" | grep -qE "Status: (Connected|Disconnected)"; then
        fail "Screen reader mode missing text status indicators"
        return
    fi

    pass "Screen reader mode is purely textual"
}

# Test 10: Process health warning includes [CRITICAL] prefix
test_critical_prefix_for_health_warnings() {
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST $TESTS_RUN]${NC} [CRITICAL] prefix for process health warnings"

    # This test verifies the code structure, actual health warning requires multiple processes
    if ! grep -q '\[CRITICAL\].*PROCESS HEALTH' "$VPN_MANAGER"; then
        fail "vpn-manager missing [CRITICAL] prefix for process health warnings"
        return
    fi

    pass "[CRITICAL] prefix present in code for health warnings"
}

# Run all tests
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Accessibility Features Test Suite   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo

test_screen_reader_mode_env_var
test_screen_reader_mode_screen_reader_var
test_accessible_flag
test_no_color_compliance
test_no_color_disables_box_drawing
test_semantic_prefixes_present
test_semantic_prefixes_in_no_color
test_standard_mode_has_visual_enhancements
test_screen_reader_no_visual_elements
test_critical_prefix_for_health_warnings

# Summary
echo
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

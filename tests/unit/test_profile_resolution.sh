#!/bin/bash
# ABOUTME: Unit tests for profile path resolution helper function (Issue #141)
# ABOUTME: Tests resolve_profile_path() function extraction and refactoring

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(realpath "$SCRIPT_DIR/../..")"

# Source test framework
source "$PROJECT_DIR/tests/test_framework.sh" 2> /dev/null || {
    echo "Error: Could not source test framework"
    exit 1
}

# Fix PROJECT_DIR which the framework might override
# Use SCRIPT_DIR (saved before framework) instead of TEST_DIR
PROJECT_DIR="$(realpath "$SCRIPT_DIR/../..")"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_resolution_test_env() {
    # Create temporary directories
    TEST_TEMP_DIR=$(mktemp -d)
    export LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
    export LOG_DIR="$TEST_TEMP_DIR/log"
    export PROFILE_CACHE="$LOG_DIR/vpn_profiles.cache"

    mkdir -p "$LOCATIONS_DIR" "$LOG_DIR"

    # Create test profiles matching realistic ProtonVPN naming
    # Country-filtered profiles (SE = Sweden)
    cat > "$LOCATIONS_DIR/se-01.protonvpn.udp.ovpn" << EOF
remote 192.168.1.1 1194
proto udp
dev tun
EOF

    cat > "$LOCATIONS_DIR/se-02.protonvpn.udp.ovpn" << EOF
remote 192.168.1.2 1194
proto udp
dev tun
EOF

    # Non-country-filtered profiles (various countries)
    cat > "$LOCATIONS_DIR/us-free-01.protonvpn.udp.ovpn" << EOF
remote 192.168.2.1 1194
proto udp
dev tun
EOF

    cat > "$LOCATIONS_DIR/jp-03.protonvpn.udp.ovpn" << EOF
remote 192.168.3.3 1194
proto udp
dev tun
EOF

    # .conf format profiles
    cat > "$LOCATIONS_DIR/dk-01.protonvpn.udp.conf" << EOF
remote 192.168.4.1 1194
proto udp
dev tun
EOF
}

cleanup_resolution_test_env() {
    [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Source vpn-connector for testing (MUST be done AFTER fixing PROJECT_DIR)
export VPN_DIR="$PROJECT_DIR/src"
source "$PROJECT_DIR/src/vpn-connector" 2> /dev/null || {
    echo "Error: Could not source vpn-connector"
    exit 1
}

# Test helper functions
start_test() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo -n "Testing: $test_name ... "
}

pass_test() {
    ((TESTS_PASSED++))
    echo "✓ PASS"
}

fail_test() {
    local message="${1:-}"
    ((TESTS_FAILED++))
    echo "✗ FAIL${message:+: $message}"
}

# ============================================================================
# INTEGRATION TESTS: Verify backward compatibility
# ============================================================================

# Create a mock best-vpn-profile in a temporary directory (never touch src/)
# Its `rank` answer is the first stdin path matching $1, at 12.5 ms
make_mock_evaluator() {
    local pattern="$1" dir
    dir=$(mktemp -d)
    cat > "$dir/best-vpn-profile" << MOCK
#!/bin/bash
[[ "\$1" == "rank" ]] || exit 1
match=\$(grep -m1 -- '$pattern')
[[ -n "\$match" ]] || exit 1
printf '12.5\t%s\n' "\$match"
MOCK
    chmod +x "$dir/best-vpn-profile"
    echo "$dir"
}

test_select_fastest_profile_uses_evaluator() {
    start_test "select_fastest_profile returns the evaluator's fastest profile"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    local mock_dir result
    mock_dir=$(make_mock_evaluator "se-01")
    result=$(get_cached_profiles | VPN_DIR="$mock_dir" select_fastest_profile 0 2> /dev/null)
    rm -rf "$mock_dir"

    if [[ "$result" == "$LOCATIONS_DIR/se-01.protonvpn.udp.ovpn" ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "expected se-01 path, got: $result"
        cleanup_resolution_test_env
        return 1
    fi
}

test_best_server_connect_uses_fastest() {
    start_test "best_server_connect connects to the fastest profile"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    local mock_dir result
    mock_dir=$(make_mock_evaluator "us-free-01")
    result=$(
        VPN_DIR="$mock_dir"
        connect_to_profile() { echo "CONNECT $1"; }
        best_server_connect full "" 2> /dev/null | grep '^CONNECT'
    )
    rm -rf "$mock_dir"

    if [[ "$result" == "CONNECT $LOCATIONS_DIR/us-free-01.protonvpn.udp.ovpn" ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "expected us-free-01 connection, got: $result"
        cleanup_resolution_test_env
        return 1
    fi
}

# ============================================================================
# Run all tests
# ============================================================================

echo "========================================="
echo "Profile Resolution Unit Tests (Issue #141)"
echo "========================================="
echo ""

# Integration/backward compatibility tests
test_select_fastest_profile_uses_evaluator || true
test_best_server_connect_uses_fastest || true

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi

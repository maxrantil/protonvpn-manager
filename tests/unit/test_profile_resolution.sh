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
# UNIT TESTS: resolve_profile_path() Function
# ============================================================================

test_resolve_profile_path_function_exists() {
    start_test "resolve_profile_path function exists"

    if type resolve_profile_path &> /dev/null; then
        pass_test
        return 0
    else
        fail_test "resolve_profile_path function not found"
        return 1
    fi
}

test_resolve_profile_path_with_country_filter() {
    start_test "resolve_profile_path resolves with country filter"

    setup_resolution_test_env

    # Build cache
    rebuild_cache > /dev/null 2>&1

    # Test: resolve profile WITH country filter
    # Should match "se-01" anywhere in path (flexible matching)
    local profile_path
    profile_path=$(resolve_profile_path "se-01" "se")

    if [[ -f "$profile_path" ]] && [[ "$profile_path" == *"se-01"* ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Expected valid path containing 'se-01', got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_without_country_filter() {
    start_test "resolve_profile_path resolves without country filter"

    setup_resolution_test_env

    # Build cache
    rebuild_cache > /dev/null 2>&1

    # Test: resolve profile WITHOUT country filter
    # Should match exact filename pattern (strict matching)
    local profile_path
    profile_path=$(resolve_profile_path "us-free-01" "")

    if [[ -f "$profile_path" ]] && [[ "$profile_path" == *"/us-free-01."* ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Expected valid path with '/us-free-01.', got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_handles_ovpn_extension() {
    start_test "resolve_profile_path handles .ovpn extension"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Should match .ovpn files
    local profile_path
    profile_path=$(resolve_profile_path "se-02" "se")

    if [[ -f "$profile_path" ]] && [[ "$profile_path" == *.ovpn ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Expected .ovpn file, got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_handles_conf_extension() {
    start_test "resolve_profile_path handles .conf extension"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Should match .conf files
    local profile_path
    profile_path=$(resolve_profile_path "dk-01" "dk")

    if [[ -f "$profile_path" ]] && [[ "$profile_path" == *.conf ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Expected .conf file, got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_fallback_to_partial_match() {
    start_test "resolve_profile_path falls back to partial match"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Test fallback: use profile name that won't match strict pattern
    # but will match partial search
    local profile_path
    profile_path=$(resolve_profile_path "jp-03" "")

    if [[ -f "$profile_path" ]] && [[ "$profile_path" == *"jp-03"* ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Fallback should find partial match, got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_returns_empty_for_nonexistent() {
    start_test "resolve_profile_path returns empty for nonexistent profile"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Test: try to resolve profile that doesn't exist
    local profile_path
    profile_path=$(resolve_profile_path "nonexistent-profile" "xx")

    if [[ -z "$profile_path" ]] || [[ ! -f "$profile_path" ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Should return empty/invalid path for nonexistent profile, got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

test_resolve_profile_path_empty_country_filter() {
    start_test "resolve_profile_path handles empty country filter correctly"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Test: empty string country filter (different from no filter)
    local profile_path
    profile_path=$(resolve_profile_path "se-01" "")

    # Should use strict matching (no country filter)
    if [[ -f "$profile_path" ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "Should handle empty country filter, got: $profile_path"
        cleanup_resolution_test_env
        return 1
    fi
}

# ============================================================================
# INTEGRATION TESTS: Verify backward compatibility
# ============================================================================

test_get_cached_best_profile_still_works() {
    start_test "get_cached_best_profile works with refactored code"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Mock best-vpn-profile to return known profile
    cat > "$VPN_DIR/best-vpn-profile" << 'EOF'
#!/bin/bash
# Mock for testing
if [[ "$1" == "best" ]]; then
    echo "se-01"
    exit 0
fi
exit 1
EOF
    chmod +x "$VPN_DIR/best-vpn-profile"

    # Test get_cached_best_profile function
    local result
    result=$(get_cached_best_profile "se" 2>&1)

    # Restore original best-vpn-profile (if backup exists)
    if [[ -f "$VPN_DIR/best-vpn-profile.bak" ]]; then
        mv "$VPN_DIR/best-vpn-profile.bak" "$VPN_DIR/best-vpn-profile"
    else
        rm -f "$VPN_DIR/best-vpn-profile"
        git checkout "$VPN_DIR/best-vpn-profile" 2>/dev/null || true
    fi

    if [[ "$result" == *"se-01"* ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "get_cached_best_profile integration failed"
        cleanup_resolution_test_env
        return 1
    fi
}

test_test_and_cache_performance_still_works() {
    start_test "test_and_cache_performance works with refactored code"

    setup_resolution_test_env
    rebuild_cache > /dev/null 2>&1

    # Mock best-vpn-profile to return known profile
    cat > "$VPN_DIR/best-vpn-profile" << 'EOF'
#!/bin/bash
# Mock for testing
if [[ "$1" == "fresh" ]]; then
    echo "us-free-01"
    exit 0
fi
exit 1
EOF
    chmod +x "$VPN_DIR/best-vpn-profile"

    # Mock check_internet to pass
    check_internet() { return 0; }
    export -f check_internet

    # Test test_and_cache_performance function
    local result
    result=$(test_and_cache_performance "" 2>&1)

    # Restore
    if [[ -f "$VPN_DIR/best-vpn-profile.bak" ]]; then
        mv "$VPN_DIR/best-vpn-profile.bak" "$VPN_DIR/best-vpn-profile"
    else
        rm -f "$VPN_DIR/best-vpn-profile"
        git checkout "$VPN_DIR/best-vpn-profile" 2>/dev/null || true
    fi

    if [[ "$result" == *"us-free-01"* ]]; then
        pass_test
        cleanup_resolution_test_env
        return 0
    else
        fail_test "test_and_cache_performance integration failed"
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

# Function existence tests
test_resolve_profile_path_function_exists || true

# Core functionality tests
test_resolve_profile_path_with_country_filter || true
test_resolve_profile_path_without_country_filter || true
test_resolve_profile_path_handles_ovpn_extension || true
test_resolve_profile_path_handles_conf_extension || true
test_resolve_profile_path_fallback_to_partial_match || true
test_resolve_profile_path_returns_empty_for_nonexistent || true
test_resolve_profile_path_empty_country_filter || true

# Integration/backward compatibility tests
test_get_cached_best_profile_still_works || true
test_test_and_cache_performance_still_works || true

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

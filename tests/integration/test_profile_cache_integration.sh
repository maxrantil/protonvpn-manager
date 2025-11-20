#!/bin/bash
# ABOUTME: Integration tests for profile cache system (Issue #142)
# ABOUTME: Tests end-to-end cache behavior across multiple VPN operations

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

# Source vpn-connector for testing (MUST be done AFTER fixing PROJECT_DIR)
export VPN_DIR="$PROJECT_DIR/src"
source "$PROJECT_DIR/src/vpn-connector" 2> /dev/null || {
    echo "Error: Could not source vpn-connector"
    exit 1
}

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup integration test environment
setup_integration_test_env() {
    # Create temporary directories
    TEST_TEMP_DIR=$(mktemp -d)
    export LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
    export LOG_DIR="$TEST_TEMP_DIR/log"
    export PROFILE_CACHE="$LOG_DIR/vpn_profiles.cache"

    mkdir -p "$LOCATIONS_DIR" "$LOG_DIR"
}

cleanup_integration_test_env() {
    [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: Create realistic test profiles
create_test_profiles() {
    local count="$1"
    local prefix="${2:-test}"

    for i in $(seq 1 "$count"); do
        cat > "$LOCATIONS_DIR/${prefix}-profile-$i.ovpn" << EOF
remote 192.168.1.$i 1194
proto udp
dev tun
EOF
    done
}

# Helper: Create country-specific profiles
create_country_profiles() {
    local country="$1"
    local count="$2"

    for i in $(seq 1 "$count"); do
        cat > "$LOCATIONS_DIR/${country}-$i.ovpn" << EOF
remote 192.168.1.$i 1194
proto udp
dev tun
EOF
    done
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
# INTEGRATION TEST 1: Cache Persistence Across Multiple Operations
# ============================================================================

test_cache_persists_across_operations() {
    start_test "Cache persists across multiple sequential operations"

    setup_integration_test_env

    # Create diverse profile set
    create_country_profiles "se" 10
    create_country_profiles "dk" 8
    create_country_profiles "nl" 5

    # Operation 1: get_cached_profiles (cold cache - should build cache)
    rm -f "$PROFILE_CACHE"
    local first_list
    first_list=$(get_cached_profiles 2> /dev/null | wc -l)

    if [[ ! -f "$PROFILE_CACHE" ]]; then
        fail_test "Cache not created on first operation"
        cleanup_integration_test_env
        return 1
    fi

    local cache_mtime_1
    cache_mtime_1=$(stat -c %Y "$PROFILE_CACHE")

    # Operation 2: get_cached_profiles again (warm cache - should use cache)
    sleep 1
    local second_list
    second_list=$(get_cached_profiles 2> /dev/null | wc -l)

    local cache_mtime_2
    cache_mtime_2=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_1" != "$cache_mtime_2" ]]; then
        fail_test "Cache was rebuilt when it should have been reused"
        cleanup_integration_test_env
        return 1
    fi

    # Operation 3: find_profiles_by_country (should use cache)
    local se_profiles
    se_profiles=$(find_profiles_by_country "se" 2> /dev/null | wc -l)

    local cache_mtime_3
    cache_mtime_3=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_2" != "$cache_mtime_3" ]]; then
        fail_test "Cache was rebuilt during country filter operation"
        cleanup_integration_test_env
        return 1
    fi

    # Operation 4: get_available_countries (should use cache)
    local countries
    countries=$(get_available_countries 2> /dev/null | wc -l)

    local cache_mtime_4
    cache_mtime_4=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_3" != "$cache_mtime_4" ]]; then
        fail_test "Cache was rebuilt during country enumeration"
        cleanup_integration_test_env
        return 1
    fi

    # Verify consistency
    if [[ "$first_list" -ne 23 ]] || [[ "$second_list" -ne 23 ]]; then
        fail_test "Inconsistent profile counts: $first_list vs $second_list"
        cleanup_integration_test_env
        return 1
    fi

    if [[ "$se_profiles" -ne 10 ]]; then
        fail_test "Expected 10 SE profiles, got $se_profiles"
        cleanup_integration_test_env
        return 1
    fi

    if [[ "$countries" -ne 3 ]]; then
        fail_test "Expected 3 countries, got $countries"
        cleanup_integration_test_env
        return 1
    fi

    pass_test
    cleanup_integration_test_env
    return 0
}

# ============================================================================
# INTEGRATION TEST 2: Cache Invalidation on Profile Changes
# ============================================================================

test_cache_invalidation_on_profile_changes() {
    start_test "Cache invalidates when profiles added or removed"

    setup_integration_test_env

    # Phase 1: Initial setup with 10 profiles
    create_test_profiles 10 "initial"

    # Build cache
    list_profiles > /dev/null 2>&1

    local cache_mtime_1
    cache_mtime_1=$(stat -c %Y "$PROFILE_CACHE")

    local initial_count
    initial_count=$(grep -v "^#" "$PROFILE_CACHE" | wc -l)

    if [[ "$initial_count" -ne 10 ]]; then
        fail_test "Initial cache should have 10 profiles, got $initial_count"
        cleanup_integration_test_env
        return 1
    fi

    # Phase 2: Add new profiles (should invalidate cache)
    sleep 2 # Ensure mtime changes
    create_test_profiles 5 "added"

    # Next operation should detect stale cache and rebuild
    list_profiles > /dev/null 2>&1

    local cache_mtime_2
    cache_mtime_2=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_1" == "$cache_mtime_2" ]]; then
        fail_test "Cache mtime unchanged after adding profiles"
        cleanup_integration_test_env
        return 1
    fi

    local updated_count
    updated_count=$(grep -v "^#" "$PROFILE_CACHE" | wc -l)

    if [[ "$updated_count" -ne 15 ]]; then
        fail_test "Cache should have 15 profiles after addition, got $updated_count"
        cleanup_integration_test_env
        return 1
    fi

    # Phase 3: Remove profiles (should invalidate cache again)
    sleep 2
    rm -f "$LOCATIONS_DIR"/added-profile-{1,2,3}.ovpn

    # Next operation should rebuild
    get_available_countries > /dev/null 2>&1

    local cache_mtime_3
    cache_mtime_3=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_2" == "$cache_mtime_3" ]]; then
        fail_test "Cache mtime unchanged after removing profiles"
        cleanup_integration_test_env
        return 1
    fi

    local final_count
    final_count=$(grep -v "^#" "$PROFILE_CACHE" | wc -l)

    if [[ "$final_count" -ne 12 ]]; then
        fail_test "Cache should have 12 profiles after removal, got $final_count"
        cleanup_integration_test_env
        return 1
    fi

    pass_test
    cleanup_integration_test_env
    return 0
}

# ============================================================================
# INTEGRATION TEST 3: Cache Reuse Validation
# ============================================================================
# Note: Detailed performance benchmarking is in tests/benchmark_profile_cache.sh
# This test validates cache is reused (structural validation)

test_cache_performance_improvement() {
    start_test "Cache is reused across operations (no rebuilds)"

    setup_integration_test_env

    # Create realistic profile set (100 profiles)
    create_country_profiles "se" 40
    create_country_profiles "dk" 30
    create_country_profiles "nl" 20
    create_country_profiles "us" 10

    # Operation 1: Build cache
    rm -f "$PROFILE_CACHE"
    get_cached_profiles > /dev/null 2>&1

    if [[ ! -f "$PROFILE_CACHE" ]]; then
        fail_test "Cache not created"
        cleanup_integration_test_env
        return 1
    fi

    local cache_mtime_1
    cache_mtime_1=$(stat -c %Y "$PROFILE_CACHE")

    # Operation 2-4: Multiple operations should NOT rebuild cache
    sleep 1
    get_cached_profiles > /dev/null 2>&1
    local cache_mtime_2
    cache_mtime_2=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_1" != "$cache_mtime_2" ]]; then
        fail_test "Cache rebuilt on operation 2 (should reuse)"
        cleanup_integration_test_env
        return 1
    fi

    sleep 1
    find_profiles_by_country "se" > /dev/null 2>&1
    local cache_mtime_3
    cache_mtime_3=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_2" != "$cache_mtime_3" ]]; then
        fail_test "Cache rebuilt on operation 3 (should reuse)"
        cleanup_integration_test_env
        return 1
    fi

    sleep 1
    get_available_countries > /dev/null 2>&1
    local cache_mtime_4
    cache_mtime_4=$(stat -c %Y "$PROFILE_CACHE")

    if [[ "$cache_mtime_3" != "$cache_mtime_4" ]]; then
        fail_test "Cache rebuilt on operation 4 (should reuse)"
        cleanup_integration_test_env
        return 1
    fi

    # Verify all operations returned correct data
    local final_count
    final_count=$(get_cached_profiles 2> /dev/null | wc -l)

    if [[ "$final_count" -ne 100 ]]; then
        fail_test "Cache corrupted: expected 100 profiles, got $final_count"
        cleanup_integration_test_env
        return 1
    fi

    pass_test
    cleanup_integration_test_env
    return 0
}

# ============================================================================
# INTEGRATION TEST 4: Output Consistency (Cached vs Uncached)
# ============================================================================

test_cache_output_consistency() {
    start_test "Cache returns identical output to uncached operations"

    setup_integration_test_env

    # Create diverse profile set
    create_country_profiles "se" 15
    create_country_profiles "dk" 10
    create_country_profiles "nl" 8

    # Create secure core profiles
    cat > "$LOCATIONS_DIR/is-se-01.ovpn" << 'EOF'
remote 192.168.1.100 1194
proto udp
dev tun
EOF

    cat > "$LOCATIONS_DIR/ch-us-01.ovpn" << 'EOF'
remote 192.168.1.101 1194
proto udp
dev tun
EOF

    # Test 1: list_profiles consistency
    rm -f "$PROFILE_CACHE"
    local uncached_list
    uncached_list=$(list_profiles 2> /dev/null | grep -E "^\s+[0-9]+\." | sort)

    # Build cache
    get_cached_profiles > /dev/null 2>&1

    local cached_list
    cached_list=$(list_profiles 2> /dev/null | grep -E "^\s+[0-9]+\." | sort)

    if [[ "$uncached_list" != "$cached_list" ]]; then
        fail_test "list_profiles output differs between cached and uncached"
        cleanup_integration_test_env
        return 1
    fi

    # Test 2: find_profiles_by_country consistency
    rm -f "$PROFILE_CACHE"
    local uncached_se
    uncached_se=$(find_profiles_by_country "se" 2> /dev/null | sort)

    get_cached_profiles > /dev/null 2>&1
    local cached_se
    cached_se=$(find_profiles_by_country "se" 2> /dev/null | sort)

    if [[ "$uncached_se" != "$cached_se" ]]; then
        fail_test "find_profiles_by_country output differs"
        cleanup_integration_test_env
        return 1
    fi

    # Test 3: get_available_countries consistency
    rm -f "$PROFILE_CACHE"
    local uncached_countries
    uncached_countries=$(get_available_countries 2> /dev/null | sort)

    get_cached_profiles > /dev/null 2>&1
    local cached_countries
    cached_countries=$(get_available_countries 2> /dev/null | sort)

    if [[ "$uncached_countries" != "$cached_countries" ]]; then
        fail_test "get_available_countries output differs"
        cleanup_integration_test_env
        return 1
    fi

    # Test 4: detect_secure_core_profiles consistency
    rm -f "$PROFILE_CACHE"
    local uncached_secure
    uncached_secure=$(detect_secure_core_profiles 2> /dev/null | sort)

    get_cached_profiles > /dev/null 2>&1
    local cached_secure
    cached_secure=$(detect_secure_core_profiles 2> /dev/null | sort)

    if [[ "$uncached_secure" != "$cached_secure" ]]; then
        fail_test "detect_secure_core_profiles output differs"
        cleanup_integration_test_env
        return 1
    fi

    pass_test
    cleanup_integration_test_env
    return 0
}

# ============================================================================
# INTEGRATION TEST 5: Recovery from Cache Corruption
# ============================================================================

test_cache_corruption_recovery() {
    start_test "System recovers gracefully from cache corruption"

    setup_integration_test_env

    # Setup: 20 test profiles (use country code pattern for compatibility)
    create_country_profiles "se" 20

    # Build initial valid cache
    get_cached_profiles > /dev/null 2>&1

    # Attack 1: Corrupt cache file (truncate)
    echo "CORRUPTED GARBAGE DATA" > "$PROFILE_CACHE"

    local recovered_1
    recovered_1=$(list_profiles 2> /dev/null | grep -c "se-" || echo 0)

    if [[ "$recovered_1" -ne 20 ]]; then
        fail_test "Failed to recover from corrupted cache: got $recovered_1 profiles"
        cleanup_integration_test_env
        return 1
    fi

    # Attack 2: Delete cache file
    rm -f "$PROFILE_CACHE"

    local recovered_2
    recovered_2=$(find_profiles_by_country "se" 2> /dev/null | wc -l)

    if [[ "$recovered_2" -ne 20 ]]; then
        fail_test "Failed to recover from missing cache: got $recovered_2 profiles"
        cleanup_integration_test_env
        return 1
    fi

    # Attack 3: Replace cache with symlink (security attack)
    rm -f "$PROFILE_CACHE"
    local fake_cache
    fake_cache=$(mktemp)
    echo "# FAKE CACHE" > "$fake_cache"
    ln -s "$fake_cache" "$PROFILE_CACHE"

    local recovered_3
    recovered_3=$(get_cached_profiles 2> /dev/null | grep -c "se-" || echo 0)

    # Should reject symlink and rebuild
    if [[ ! -f "$PROFILE_CACHE" ]] || [[ -L "$PROFILE_CACHE" ]]; then
        fail_test "Failed to reject symlink attack"
        rm -f "$fake_cache"
        cleanup_integration_test_env
        return 1
    fi

    rm -f "$fake_cache"

    if [[ "$recovered_3" -ne 20 ]]; then
        fail_test "Failed to recover from symlink attack: got $recovered_3 profiles"
        cleanup_integration_test_env
        return 1
    fi

    # Attack 4: Unreadable cache (permission denied)
    chmod 000 "$PROFILE_CACHE" 2> /dev/null || true

    local recovered_4
    recovered_4=$(get_cached_profiles 2> /dev/null | grep -c "se-" || echo 0)

    if [[ "$recovered_4" -ne 20 ]]; then
        fail_test "Failed to recover from unreadable cache: got $recovered_4 profiles"
        cleanup_integration_test_env
        return 1
    fi

    # Verify cache was rebuilt with correct permissions
    local cache_perms
    cache_perms=$(stat -c %a "$PROFILE_CACHE" 2> /dev/null)

    if [[ "$cache_perms" != "600" ]]; then
        fail_test "Cache rebuilt with incorrect permissions: $cache_perms"
        cleanup_integration_test_env
        return 1
    fi

    pass_test
    cleanup_integration_test_env
    return 0
}

# ============================================================================
# Run all integration tests
# ============================================================================

echo "========================================="
echo "Profile Cache Integration Tests"
echo "========================================="
echo ""
echo "These tests validate end-to-end cache behavior"
echo "across multiple VPN operations and real-world scenarios."
echo ""

# Run all 5 required integration tests
test_cache_persists_across_operations || true
test_cache_invalidation_on_profile_changes || true
test_cache_performance_improvement || true
test_cache_output_consistency || true
test_cache_corruption_recovery || true

# Summary
echo ""
echo "========================================="
echo "Integration Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All integration tests passed!"
    exit 0
else
    echo "✗ Some integration tests failed"
    exit 1
fi

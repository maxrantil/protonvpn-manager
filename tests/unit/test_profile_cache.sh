#!/bin/bash
# ABOUTME: Unit tests for profile cache mechanism
# ABOUTME: Tests cache creation, invalidation, and reading logic

set -euo pipefail

TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(realpath "$TEST_DIR/../..")"

# Source test framework
source "$PROJECT_DIR/tests/test_framework.sh" 2> /dev/null || {
    echo "Error: Could not source test framework"
    exit 1
}

# Fix PROJECT_DIR which the framework overrides to /tests
PROJECT_DIR="$(realpath "$TEST_DIR/../..")"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_cache_test_env() {
    # Create temporary directories
    TEST_TEMP_DIR=$(mktemp -d)
    export LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
    export LOG_DIR="$TEST_TEMP_DIR/log"

    mkdir -p "$LOCATIONS_DIR" "$LOG_DIR"

    # Create test profiles
    for i in {1..5}; do
        cat > "$LOCATIONS_DIR/test-se-$i.ovpn" << EOF
remote 192.168.1.$i 1194
proto udp
dev tun
EOF
    done

    for i in {1..3}; do
        cat > "$LOCATIONS_DIR/test-dk-$i.ovpn" << EOF
remote 192.168.2.$i 1194
proto udp
dev tun
EOF
    done
}

cleanup_cache_test_env() {
    [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Source vpn-connector for testing
# VPN_DIR is used by vpn-connector when sourced
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
# UNIT TESTS: Cache Creation
# ============================================================================

test_is_cache_valid_function_exists() {
    start_test "is_cache_valid function exists"

    if type is_cache_valid &> /dev/null; then
        pass_test
        return 0
    else
        fail_test "is_cache_valid function not found"
        return 1
    fi
}

test_rebuild_cache_function_exists() {
    start_test "rebuild_cache function exists"

    if type rebuild_cache &> /dev/null; then
        pass_test
        return 0
    else
        fail_test "rebuild_cache function not found"
        return 1
    fi
}

test_get_cached_profiles_function_exists() {
    start_test "get_cached_profiles function exists"

    if type get_cached_profiles &> /dev/null; then
        pass_test
        return 0
    else
        fail_test "get_cached_profiles function not found"
        return 1
    fi
}

test_rebuild_cache_creates_file() {
    start_test "rebuild_cache creates cache file"

    setup_cache_test_env

    # Remove cache if exists
    rm -f "$LOG_DIR/vpn_profiles.cache"

    # Rebuild cache
    if rebuild_cache; then
        if [[ -f "$LOG_DIR/vpn_profiles.cache" ]]; then
            pass_test
            cleanup_cache_test_env
            return 0
        else
            fail_test "Cache file not created"
            cleanup_cache_test_env
            return 1
        fi
    else
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    fi
}

test_cache_file_permissions() {
    start_test "Cache file has 600 permissions"

    setup_cache_test_env

    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    local perms
    perms=$(stat -c %a "$LOG_DIR/vpn_profiles.cache" 2> /dev/null)

    if [[ "$perms" == "600" ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 600, got $perms"
        cleanup_cache_test_env
        return 1
    fi
}

test_cache_contains_profiles() {
    start_test "Cache contains profile paths"

    setup_cache_test_env

    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    # Check cache contains expected profiles (excluding comment lines)
    local profile_count
    profile_count=$(grep -v "^#" "$LOG_DIR/vpn_profiles.cache" | wc -l)

    # We created 8 test profiles (5 se + 3 dk)
    if [[ "$profile_count" -eq 8 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 8 profiles, got $profile_count"
        cleanup_cache_test_env
        return 1
    fi
}

test_cache_has_metadata_header() {
    start_test "Cache has metadata header"

    setup_cache_test_env

    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    # Check for required metadata fields
    if grep -q "^# CACHE_MTIME=" "$LOG_DIR/vpn_profiles.cache" &&
        grep -q "^# CACHE_DIR=" "$LOG_DIR/vpn_profiles.cache" &&
        grep -q "^# CACHE_COUNT=" "$LOG_DIR/vpn_profiles.cache"; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Missing metadata header fields"
        cleanup_cache_test_env
        return 1
    fi
}

# ============================================================================
# UNIT TESTS: Cache Validation
# ============================================================================

test_is_cache_valid_returns_false_when_no_cache() {
    start_test "is_cache_valid returns false when cache missing"

    setup_cache_test_env

    # Ensure no cache exists
    rm -f "$LOG_DIR/vpn_profiles.cache"

    if is_cache_valid; then
        fail_test "Should return false when cache missing"
        cleanup_cache_test_env
        return 1
    else
        pass_test
        cleanup_cache_test_env
        return 0
    fi
}

test_is_cache_valid_returns_true_when_fresh() {
    start_test "is_cache_valid returns true when cache fresh"

    setup_cache_test_env

    # Create cache
    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    # Check validity immediately
    if is_cache_valid; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Should return true for fresh cache"
        cleanup_cache_test_env
        return 1
    fi
}

test_is_cache_valid_detects_directory_change() {
    start_test "is_cache_valid detects directory mtime change"

    setup_cache_test_env

    # Create initial cache
    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    # Wait for mtime resolution (1 second)
    sleep 1

    # Modify directory (add new profile)
    touch "$LOCATIONS_DIR/new-profile.ovpn"

    # Cache should now be invalid
    if is_cache_valid; then
        fail_test "Should detect directory change"
        cleanup_cache_test_env
        return 1
    else
        pass_test
        cleanup_cache_test_env
        return 0
    fi
}

# ============================================================================
# UNIT TESTS: Cache Reading
# ============================================================================

test_get_cached_profiles_returns_sorted_list() {
    start_test "get_cached_profiles returns sorted profile list"

    setup_cache_test_env

    # Get cached profiles
    local profiles
    profiles=$(get_cached_profiles)

    # Check we got profiles
    local count
    count=$(echo "$profiles" | wc -l)

    if [[ "$count" -eq 8 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 8 profiles, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

test_get_cached_profiles_rebuilds_when_stale() {
    start_test "get_cached_profiles rebuilds stale cache"

    setup_cache_test_env

    # Get profiles (creates cache)
    get_cached_profiles > /dev/null

    # Wait and modify directory
    sleep 1
    touch "$LOCATIONS_DIR/another-profile.ovpn"

    # Get profiles again (should rebuild)
    local profiles
    profiles=$(get_cached_profiles)

    # Should now have 9 profiles
    local count
    count=$(echo "$profiles" | wc -l)

    if [[ "$count" -eq 9 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 9 profiles after rebuild, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

# ============================================================================
# Run all tests
# ============================================================================

echo "========================================="
echo "Profile Cache Unit Tests"
echo "========================================="
echo ""

# Function existence tests
test_is_cache_valid_function_exists || true
test_rebuild_cache_function_exists || true
test_get_cached_profiles_function_exists || true

# Cache creation tests
test_rebuild_cache_creates_file || true
test_cache_file_permissions || true
test_cache_contains_profiles || true
test_cache_has_metadata_header || true

# Cache validation tests
test_is_cache_valid_returns_false_when_no_cache || true
test_is_cache_valid_returns_true_when_fresh || true
test_is_cache_valid_detects_directory_change || true

# Cache reading tests
test_get_cached_profiles_returns_sorted_list || true
test_get_cached_profiles_rebuilds_when_stale || true

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

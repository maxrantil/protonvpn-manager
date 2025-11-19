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
    export PROFILE_CACHE="$LOG_DIR/vpn_profiles.cache"

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
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name ... "
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS"
}

fail_test() {
    local message="${1:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
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
# UNIT TESTS: Cache Security (Issue #143)
# ============================================================================

test_get_cached_profiles_filters_malicious_entries() {
    start_test "get_cached_profiles filters malicious cache entries"

    setup_cache_test_env

    # Create additional valid test files for this test
    cat > "$LOCATIONS_DIR/test-se-3.ovpn" << EOF
remote 192.168.1.3 1194
proto udp
dev tun
EOF
    cat > "$LOCATIONS_DIR/test-se-4.ovpn" << EOF
remote 192.168.1.4 1194
proto udp
dev tun
EOF

    # Get current directory mtime
    local dir_mtime
    dir_mtime=$(stat -c %Y "$LOCATIONS_DIR")

    # Create a poisoned cache file with mix of valid and malicious entries
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# CACHE_MTIME=$dir_mtime
# CACHE_DIR=$LOCATIONS_DIR
# CACHE_COUNT=12
$LOCATIONS_DIR/test-se-1.ovpn
$LOCATIONS_DIR/test-se-2.ovpn
../../etc/passwd
$LOCATIONS_DIR/../../../etc/shadow
$LOCATIONS_DIR/test-dk-1.ovpn
/tmp/malicious.ovpn
$LOCATIONS_DIR/test.txt
$LOCATIONS_DIR/test-dk-2.ovpn
symlink-attack.ovpn
$LOCATIONS_DIR/test-se-3.ovpn
$LOCATIONS_DIR/test\$injection.ovpn
$LOCATIONS_DIR/test-se-4.ovpn
EOF

    # Set proper permissions
    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # Set directory mtime to match cache to prevent rebuild
    touch -d "@$dir_mtime" "$LOCATIONS_DIR"

    # Get cached profiles - should filter malicious entries
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Count valid profiles (6 valid .ovpn files in cache)
    local count=0
    if [[ -n "$profiles" ]]; then
        count=$(echo "$profiles" | grep -c "\.ovpn$")
    fi

    # Check that malicious entries were filtered out
    if echo "$profiles" | grep -q "etc/passwd"; then
        fail_test "Path traversal not filtered: etc/passwd"
        cleanup_cache_test_env
        return 1
    fi

    if echo "$profiles" | grep -q "etc/shadow"; then
        fail_test "Path traversal not filtered: etc/shadow"
        cleanup_cache_test_env
        return 1
    fi

    if echo "$profiles" | grep -q "/tmp/malicious"; then
        fail_test "Outside path not filtered: /tmp/malicious.ovpn"
        cleanup_cache_test_env
        return 1
    fi

    if echo "$profiles" | grep -q "test.txt"; then
        fail_test "Invalid extension not filtered: test.txt"
        cleanup_cache_test_env
        return 1
    fi

    if echo "$profiles" | grep -q 'test$injection'; then
        fail_test "Unsafe characters not filtered: test\$injection.ovpn"
        cleanup_cache_test_env
        return 1
    fi

    # Only 6 valid entries should remain from cache
    # (test-se-1, test-se-2, test-dk-1, test-dk-2, test-se-3, test-se-4)
    if [[ "$count" -eq 6 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 6 valid profiles, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

test_get_cached_profiles_filters_symlinks() {
    start_test "get_cached_profiles filters symlink attacks"

    setup_cache_test_env

    # Create a symlink to sensitive file
    ln -s /etc/passwd "$LOCATIONS_DIR/symlink.ovpn"

    # Get current directory mtime
    local dir_mtime
    dir_mtime=$(stat -c %Y "$LOCATIONS_DIR")

    # Create cache with symlink entry
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# CACHE_MTIME=$dir_mtime
# CACHE_DIR=$LOCATIONS_DIR
# CACHE_COUNT=2
$LOCATIONS_DIR/test-se-1.ovpn
$LOCATIONS_DIR/symlink.ovpn
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # Set directory mtime to match cache to prevent rebuild
    touch -d "@$dir_mtime" "$LOCATIONS_DIR"

    # Get cached profiles - should filter symlink
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Check symlink was filtered
    if echo "$profiles" | grep -q "symlink.ovpn"; then
        fail_test "Symlink not filtered"
        cleanup_cache_test_env
        return 1
    fi

    # Should only have 1 valid profile
    local count
    count=$(echo "$profiles" | wc -l)

    if [[ "$count" -eq 1 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 1 valid profile, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

test_get_cached_profiles_filters_nonexistent_files() {
    start_test "get_cached_profiles filters non-existent files"

    setup_cache_test_env

    # Get current directory mtime
    local dir_mtime
    dir_mtime=$(stat -c %Y "$LOCATIONS_DIR")

    # Create cache with non-existent file entry
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# CACHE_MTIME=$dir_mtime
# CACHE_DIR=$LOCATIONS_DIR
# CACHE_COUNT=3
$LOCATIONS_DIR/test-se-1.ovpn
$LOCATIONS_DIR/does-not-exist.ovpn
$LOCATIONS_DIR/test-se-2.ovpn
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # Set directory mtime to match cache to prevent rebuild
    touch -d "@$dir_mtime" "$LOCATIONS_DIR"

    # Get cached profiles - should filter non-existent file
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Check non-existent file was filtered
    if echo "$profiles" | grep -q "does-not-exist"; then
        fail_test "Non-existent file not filtered"
        cleanup_cache_test_env
        return 1
    fi

    # Should only have 2 valid profiles
    local count=0
    if [[ -n "$profiles" ]]; then
        count=$(echo "$profiles" | grep -c "\.ovpn$")
    fi

    if [[ "$count" -eq 2 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 2 valid profiles, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

# ============================================================================
# UNIT TESTS: Metadata Validation (Issue #155)
# ============================================================================

test_validate_cache_metadata_rejects_non_numeric_mtime() {
    start_test "validate_cache_metadata rejects non-numeric MTIME"

    setup_cache_test_env

    # Create cache with invalid (non-numeric) MTIME
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# VPN Profile Cache
# CACHE_MTIME=invalid_not_numeric
# CACHE_DIR=$LOCATIONS_DIR
# GENERATED=2025-11-18T12:00:00Z
# CACHE_COUNT=3
$LOCATIONS_DIR/test-se-1.ovpn
$LOCATIONS_DIR/test-se-2.ovpn
$LOCATIONS_DIR/test-dk-1.ovpn
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # Should fail validation
    if validate_cache_metadata "$LOG_DIR/vpn_profiles.cache" 2>/dev/null; then
        fail_test "Should reject non-numeric MTIME"
        cleanup_cache_test_env
        return 1
    else
        pass_test
        cleanup_cache_test_env
        return 0
    fi
}

test_validate_cache_metadata_rejects_mismatched_count() {
    start_test "validate_cache_metadata rejects mismatched COUNT"

    setup_cache_test_env

    # Get current directory mtime
    local dir_mtime
    dir_mtime=$(stat -c %Y "$LOCATIONS_DIR")

    # Create cache where COUNT doesn't match actual entries
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# VPN Profile Cache
# CACHE_MTIME=$dir_mtime
# CACHE_DIR=$LOCATIONS_DIR
# GENERATED=2025-11-18T12:00:00Z
# CACHE_COUNT=100
$LOCATIONS_DIR/test-se-1.ovpn
$LOCATIONS_DIR/test-se-2.ovpn
$LOCATIONS_DIR/test-dk-1.ovpn
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # Should fail validation (claims 100 entries but only has 3)
    if validate_cache_metadata "$LOG_DIR/vpn_profiles.cache" 2>/dev/null; then
        fail_test "Should reject mismatched COUNT"
        cleanup_cache_test_env
        return 1
    else
        pass_test
        cleanup_cache_test_env
        return 0
    fi
}

test_validate_cache_metadata_accepts_valid_metadata() {
    start_test "validate_cache_metadata accepts valid metadata"

    setup_cache_test_env

    # Create valid cache
    rebuild_cache || {
        fail_test "rebuild_cache failed"
        cleanup_cache_test_env
        return 1
    }

    # get_cached_profiles should use cache without rebuilding (validation passes)
    # If metadata validation fails, it would rebuild and we'd see warning
    local profiles
    profiles=$(get_cached_profiles 2>&1)

    # Check that we didn't see "metadata invalid" warning
    if echo "$profiles" | grep -q "metadata invalid"; then
        fail_test "Valid metadata was rejected"
        cleanup_cache_test_env
        return 1
    fi

    # Should successfully return profiles
    local count
    count=$(echo "$profiles" | grep -v "metadata invalid" | wc -l)

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

test_get_cached_profiles_rebuilds_on_invalid_metadata() {
    start_test "get_cached_profiles rebuilds when metadata invalid"

    setup_cache_test_env

    # Create cache with invalid metadata
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
# VPN Profile Cache
# CACHE_MTIME=not_numeric
# CACHE_DIR=$LOCATIONS_DIR
# GENERATED=2025-11-18T12:00:00Z
# CACHE_COUNT=50
$LOCATIONS_DIR/test-se-1.ovpn
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # get_cached_profiles should detect invalid metadata and rebuild
    local profiles
    profiles=$(get_cached_profiles 2>/dev/null)

    # Should successfully return profiles after rebuild
    local count
    count=$(echo "$profiles" | wc -l)

    if [[ "$count" -eq 8 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 8 profiles after rebuild, got $count"
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

# Cache security tests (Issue #143)
test_get_cached_profiles_filters_malicious_entries || true
test_get_cached_profiles_filters_symlinks || true
test_get_cached_profiles_filters_nonexistent_files || true

# Metadata validation tests (Issue #155)
test_validate_cache_metadata_rejects_non_numeric_mtime || true
test_validate_cache_metadata_rejects_mismatched_count || true
test_validate_cache_metadata_accepts_valid_metadata || true
test_get_cached_profiles_rebuilds_on_invalid_metadata || true

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

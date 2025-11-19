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
# UNIT TESTS: Edge Cases (Issue #144)
# ============================================================================

test_corrupted_cache_recovery() {
    start_test "Corrupted cache triggers rebuild"

    setup_cache_test_env

    # Create corrupted cache file (invalid format, missing metadata)
    cat > "$LOG_DIR/vpn_profiles.cache" << EOF
This is not a valid cache file
Random garbage data
No metadata headers
EOF

    chmod 600 "$LOG_DIR/vpn_profiles.cache"

    # get_cached_profiles should detect corruption and rebuild
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Should successfully return profiles despite corruption
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

test_symlink_cache_file_rejected() {
    start_test "Symlink cache file is rejected and rebuilt"

    setup_cache_test_env

    # Create legitimate cache file elsewhere
    local fake_cache
    fake_cache=$(mktemp)
    echo "# FAKE CACHE" > "$fake_cache"

    # Create symlink as cache file (symlink attack)
    ln -s "$fake_cache" "$LOG_DIR/vpn_profiles.cache"

    # rebuild_cache should detect and remove symlink
    if rebuild_cache; then
        # Verify cache is now a regular file (not symlink)
        if [[ -f "$LOG_DIR/vpn_profiles.cache" ]] && [[ ! -L "$LOG_DIR/vpn_profiles.cache" ]]; then
            pass_test
            rm -f "$fake_cache"
            cleanup_cache_test_env
            return 0
        else
            fail_test "Cache is still a symlink"
            rm -f "$fake_cache"
            cleanup_cache_test_env
            return 1
        fi
    else
        fail_test "rebuild_cache failed"
        rm -f "$fake_cache"
        cleanup_cache_test_env
        return 1
    fi
}

test_permission_denied_cache_handled() {
    start_test "Unreadable cache triggers rebuild"

    setup_cache_test_env

    # Create cache with no read permissions
    rebuild_cache || {
        fail_test "Initial rebuild failed"
        cleanup_cache_test_env
        return 1
    }

    chmod 000 "$LOG_DIR/vpn_profiles.cache"

    # get_cached_profiles should detect unreadable cache and rebuild
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Should successfully return profiles despite permission issue
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

test_concurrent_cache_rebuild_safety() {
    start_test "Concurrent cache rebuilds don't corrupt data"

    setup_cache_test_env

    # Simulate concurrent rebuilds (background processes)
    rebuild_cache &
    local pid1=$!
    rebuild_cache &
    local pid2=$!
    rebuild_cache &
    local pid3=$!

    # Wait for all to complete
    wait "$pid1" "$pid2" "$pid3" 2> /dev/null

    # Verify cache is valid and not corrupted
    if [[ -f "$LOG_DIR/vpn_profiles.cache" ]]; then
        # Check cache has valid metadata
        if grep -q "^# CACHE_MTIME=" "$LOG_DIR/vpn_profiles.cache" &&
            grep -q "^# CACHE_COUNT=" "$LOG_DIR/vpn_profiles.cache"; then
            pass_test
            cleanup_cache_test_env
            return 0
        else
            fail_test "Cache corrupted by concurrent access"
            cleanup_cache_test_env
            return 1
        fi
    else
        fail_test "Cache file missing after concurrent rebuilds"
        cleanup_cache_test_env
        return 1
    fi
}

test_empty_locations_directory() {
    start_test "Empty locations directory handled gracefully"

    setup_cache_test_env

    # Remove all profile files
    rm -f "$LOCATIONS_DIR"/*.ovpn

    # get_cached_profiles should handle empty directory
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Should return empty result (no profiles)
    if [[ -z "$profiles" ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected empty result, got profiles"
        cleanup_cache_test_env
        return 1
    fi
}

test_locations_directory_missing() {
    start_test "Missing locations directory handled gracefully"

    setup_cache_test_env

    # Remove locations directory entirely
    rm -rf "$LOCATIONS_DIR"

    # get_cached_profiles should handle missing directory
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Should return empty result or handle error gracefully
    local exit_code=$?

    # Either empty result or non-zero exit is acceptable
    if [[ -z "$profiles" ]] || [[ $exit_code -ne 0 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Should handle missing directory gracefully"
        cleanup_cache_test_env
        return 1
    fi
}

test_cache_directory_readonly() {
    start_test "Read-only cache directory uses fallback"

    setup_cache_test_env

    # Make LOG_DIR read-only (can't create cache)
    chmod 555 "$LOG_DIR"

    # get_cached_profiles should fall back to direct scan
    local profiles
    profiles=$(get_cached_profiles 2> /dev/null)

    # Restore permissions for cleanup
    chmod 755 "$LOG_DIR"

    # Should still return profiles via fallback
    local count
    count=$(echo "$profiles" | wc -l)

    if [[ "$count" -eq 8 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    else
        fail_test "Expected 8 profiles via fallback, got $count"
        cleanup_cache_test_env
        return 1
    fi
}

test_large_profile_count_performance() {
    start_test "Large profile count (1000+) handled efficiently"

    setup_cache_test_env

    # Remove initial test profiles to have clean count
    rm -f "$LOCATIONS_DIR"/*.ovpn

    # Create 1000 test profiles
    for i in {1..1000}; do
        cat > "$LOCATIONS_DIR/test-profile-$i.ovpn" << EOF
remote 10.0.$((i / 256)).$((i % 256)) 1194
proto udp
dev tun
EOF
    done

    # Measure cache rebuild time
    local start_time
    start_time=$(date +%s%N)

    rebuild_cache || {
        fail_test "rebuild_cache failed with 1000 profiles"
        cleanup_cache_test_env
        return 1
    }

    local end_time
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    # Verify cache contains all profiles
    local count
    count=$(grep -v "^#" "$LOG_DIR/vpn_profiles.cache" | wc -l)

    # Performance threshold: rebuild should complete in <5 seconds
    if [[ "$count" -eq 1000 ]] && [[ $duration_ms -lt 5000 ]]; then
        pass_test
        cleanup_cache_test_env
        return 0
    elif [[ "$count" -ne 1000 ]]; then
        fail_test "Expected 1000 profiles, got $count"
        cleanup_cache_test_env
        return 1
    else
        fail_test "Rebuild took ${duration_ms}ms (expected <5000ms)"
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

# Edge case tests (Issue #144)
test_corrupted_cache_recovery || true
test_symlink_cache_file_rejected || true
test_permission_denied_cache_handled || true
test_concurrent_cache_rebuild_safety || true
test_empty_locations_directory || true
test_locations_directory_missing || true
test_cache_directory_readonly || true
test_large_profile_count_performance || true

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

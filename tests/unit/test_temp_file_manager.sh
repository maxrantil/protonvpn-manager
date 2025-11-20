#!/bin/bash
# ABOUTME: Unit tests for temp file manager
# ABOUTME: Tests temp file registry, crash cleanup, and coordinated cleanup

# Note: Not using set -euo pipefail here due to interaction with trap handlers
# set -e

TEST_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(realpath "$TEST_DIR/../..")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test temp directory
TEST_TEMP_DIR=$(mktemp -d)

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

print_test_summary() {
    echo ""
    echo "========================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ All tests passed!"
        return 0
    else
        echo "✗ Some tests failed"
        return 1
    fi
}

# Cleanup on exit
cleanup_test_env() {
    [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
}

trap cleanup_test_env EXIT

# Source temp file manager
export TEMP_FILE_REGISTRY="$TEST_TEMP_DIR/registry"
export TEMP_FILE_LOCK="$TEST_TEMP_DIR/registry.lock"

# shellcheck source=src/temp-file-manager
source "$PROJECT_DIR/src/temp-file-manager" || {
    echo "Error: Could not source temp-file-manager"
    exit 1
}

# ============================================================================
# UNIT TESTS
# ============================================================================

test_init_creates_registry() {
    start_test "init_temp_file_manager creates registry file"

    rm -f "$TEMP_FILE_REGISTRY" # Clean slate
    init_temp_file_manager

    if [[ -f "$TEMP_FILE_REGISTRY" ]]; then
        pass_test
    else
        fail_test "Registry file not created"
    fi
}

test_register_file() {
    start_test "register_temp_file adds file to registry"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local test_file="$TEST_TEMP_DIR/test-file-1"
    touch "$test_file"
    register_temp_file "$test_file"

    if grep -qxF "$test_file" "$TEMP_FILE_REGISTRY"; then
        pass_test
    else
        fail_test "File not found in registry"
    fi
}

test_register_multiple_files() {
    start_test "register_temp_file handles multiple files"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local file1="$TEST_TEMP_DIR/file1"
    local file2="$TEST_TEMP_DIR/file2"
    local file3="$TEST_TEMP_DIR/file3"

    touch "$file1" "$file2" "$file3"
    register_temp_file "$file1"
    register_temp_file "$file2"
    register_temp_file "$file3"

    local count
    count=$(wc -l < "$TEMP_FILE_REGISTRY")

    if [[ $count -eq 3 ]]; then
        pass_test
    else
        fail_test "Expected 3 files, found $count"
    fi
}

test_unregister_file() {
    start_test "unregister_temp_file removes from registry"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local test_file="$TEST_TEMP_DIR/unreg-file"
    touch "$test_file"

    register_temp_file "$test_file"
    unregister_temp_file "$test_file"

    if ! grep -qxF "$test_file" "$TEMP_FILE_REGISTRY"; then
        pass_test
    else
        fail_test "File still in registry"
    fi
}

test_cleanup_removes_files() {
    start_test "cleanup_temp_files removes registered files"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local file1="$TEST_TEMP_DIR/cleanup1"
    local file2="$TEST_TEMP_DIR/cleanup2"

    touch "$file1" "$file2"
    register_temp_file "$file1"
    register_temp_file "$file2"

    cleanup_temp_files

    if [[ ! -f "$file1" ]] && [[ ! -f "$file2" ]]; then
        pass_test
    else
        fail_test "Files still exist after cleanup"
    fi
}

test_cleanup_empties_registry() {
    start_test "cleanup_temp_files empties registry"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local test_file="$TEST_TEMP_DIR/reg-test"
    touch "$test_file"
    register_temp_file "$test_file"

    cleanup_temp_files

    local count
    count=$(wc -l < "$TEMP_FILE_REGISTRY")

    if [[ $count -eq 0 ]]; then
        pass_test
    else
        fail_test "Registry has $count entries"
    fi
}

test_cleanup_handles_missing_files() {
    start_test "cleanup handles missing files gracefully"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local missing="$TEST_TEMP_DIR/missing"
    local exists="$TEST_TEMP_DIR/exists"

    touch "$exists"
    # Register missing without creating it
    register_temp_file "$missing"
    register_temp_file "$exists"

    if cleanup_temp_files; then
        pass_test
    else
        fail_test "Cleanup failed with missing file"
    fi
}

test_concurrent_registration() {
    start_test "concurrent registration is thread-safe"

    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    # Register 10 files concurrently
    # shellcheck disable=SC2030  # Intentional export to subshells
    for i in {1..10}; do
        (
            export TEMP_FILE_REGISTRY="$TEMP_FILE_REGISTRY"
            export TEMP_FILE_LOCK="$TEMP_FILE_LOCK"
            source "$PROJECT_DIR/src/temp-file-manager"
            local file="$TEST_TEMP_DIR/concurrent-$i"
            touch "$file"
            register_temp_file "$file"
        ) &
    done

    wait

    local count
    # shellcheck disable=SC2031  # Variable set in parent scope above
    count=$(wc -l < "$TEMP_FILE_REGISTRY")

    if [[ $count -eq 10 ]]; then
        pass_test
    else
        fail_test "Expected 10, found $count (race condition?)"
    fi
}

test_create_temp_file_helper() {
    start_test "create_temp_file creates and registers file"

    # shellcheck disable=SC2031  # Variable set in parent scope
    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local new_file
    # shellcheck disable=SC2119  # Function has optional parameter with default
    new_file=$(create_temp_file)

    # shellcheck disable=SC2031  # Variable set in parent scope
    if [[ -f "$new_file" ]] && grep -qxF "$new_file" "$TEMP_FILE_REGISTRY"; then
        pass_test
        rm -f "$new_file"
    else
        fail_test "File not created or not registered"
    fi
}

test_list_temp_files() {
    start_test "list_temp_files shows registered files"

    # shellcheck disable=SC2031  # Variable set in parent scope
    rm -f "$TEMP_FILE_REGISTRY"
    init_temp_file_manager

    local file1="$TEST_TEMP_DIR/list1"
    local file2="$TEST_TEMP_DIR/list2"

    touch "$file1" "$file2"
    register_temp_file "$file1"
    register_temp_file "$file2"

    local output
    output=$(list_temp_files)

    if echo "$output" | grep -q "$file1" && echo "$output" | grep -q "$file2"; then
        pass_test
    else
        fail_test "Not all files shown"
    fi
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

test_init_creates_registry
test_register_file
test_register_multiple_files
test_unregister_file
test_cleanup_removes_files
test_cleanup_empties_registry
test_cleanup_handles_missing_files
test_concurrent_registration
test_create_temp_file_helper
test_list_temp_files

# Summary
print_test_summary
exit $TESTS_FAILED

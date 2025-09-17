#!/usr/bin/env bash
# ABOUTME: TDD tests for ProtonVPN config download engine module
# RED phase tests defining expected behavior for download automation

set -euo pipefail

# Test configuration
TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_SCRIPT_DIR")"
DOWNLOAD_ENGINE="$PROJECT_ROOT/src/download-engine"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
}

# Test framework functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BLUE}Running: $test_name${NC}"
    log "INFO" "$test_name"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if $test_function; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS" "$test_name"
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL" "$test_name"
        echo -e "${RED}✗ FAIL: $test_name${NC}"
    fi
}

# Setup and teardown
setup_test_environment() {
    log "INFO" "Setting up download engine test environment"
    # Create test directories if needed
    mkdir -p "$PROJECT_ROOT/locations/.test-downloads"
    mkdir -p "$PROJECT_ROOT/locations/.download-metadata"
}

cleanup_test_environment() {
    log "INFO" "Cleaning up download engine test environment"
    # Remove test files
    rm -rf "$PROJECT_ROOT/locations/.test-downloads" 2>/dev/null || true
    rm -f "$PROJECT_ROOT/locations/.download-metadata/test-"* 2>/dev/null || true
}

# Test 1: Module existence and help functionality
test_download_engine_exists() {
    # RED: This should fail initially - module doesn't exist yet
    if [[ ! -f "$DOWNLOAD_ENGINE" ]]; then
        log "FAIL" "Download engine module does not exist at $DOWNLOAD_ENGINE"
        return 1
    fi

    if [[ ! -x "$DOWNLOAD_ENGINE" ]]; then
        log "FAIL" "Download engine is not executable"
        return 1
    fi

    # Test help command
    if ! "$DOWNLOAD_ENGINE" help >/dev/null 2>&1; then
        log "FAIL" "Download engine help command failed"
        return 1
    fi

    # Verify expected commands are documented
    local help_output
    help_output=$("$DOWNLOAD_ENGINE" help 2>&1)

    if ! echo "$help_output" | grep -q "download-all"; then
        log "FAIL" "Help missing download-all command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "download-country"; then
        log "FAIL" "Help missing download-country command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "check-updates"; then
        log "FAIL" "Help missing check-updates command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "status"; then
        log "FAIL" "Help missing status command"
        return 1
    fi

    log "PASS" "Download engine exists with proper help"
    return 0
}

# Test 2: Authentication integration with Phase 1
test_authentication_integration() {
    setup_test_environment

    # RED: Should fail initially - authentication integration not implemented

    # Verify download engine can detect authentication status
    if ! "$DOWNLOAD_ENGINE" status 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -qi "authentication"; then
        log "FAIL" "Download engine doesn't check authentication status"
        cleanup_test_environment
        return 1
    fi

    # Verify integration with Phase 1 proton-auth module
    # The command should run successfully (even if no session exists)
    local auth_output
    auth_output=$("$DOWNLOAD_ENGINE" check-auth 2>&1)
    if [[ $? -ne 0 && $? -ne 1 ]]; then
        log "FAIL" "Download engine cannot integrate with proton-auth"
        cleanup_test_environment
        return 1
    fi

    # Should return meaningful authentication status
    if ! echo "$auth_output" | grep -qi "authentication"; then
        log "FAIL" "Download engine doesn't provide authentication status"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Authentication integration working"
    cleanup_test_environment
    return 0
}

# Test 3: ProtonVPN downloads page scraping capability
test_downloads_page_scraping() {
    setup_test_environment

    # RED: Should fail initially - scraping not implemented

    # Test mock scraping (should work without real authentication)
    if ! "$DOWNLOAD_ENGINE" list-available --dry-run 2>/dev/null; then
        log "FAIL" "Download engine cannot list available configs"
        cleanup_test_environment
        return 1
    fi

    # Verify it can parse country codes and server names
    local available_list
    available_list=$("$DOWNLOAD_ENGINE" list-available --dry-run 2>/dev/null)

    if ! echo "$available_list" | grep -q "dk-"; then
        log "FAIL" "Cannot parse Danish server configs"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Downloads page scraping working"
    cleanup_test_environment
    return 0
}

# Test 4: Config file downloading and storage
test_config_downloading() {
    setup_test_environment

    # RED: Should fail initially - downloading not implemented

    # Test single country download (using test mode)
    if ! "$DOWNLOAD_ENGINE" download-country dk --test-mode 2>/dev/null; then
        log "FAIL" "Cannot download specific country configs"
        cleanup_test_environment
        return 1
    fi

    # Verify files are stored in correct location
    if [[ ! -d "$PROJECT_ROOT/locations/.test-downloads/dk" ]]; then
        log "FAIL" "Test download directory not created"
        cleanup_test_environment
        return 1
    fi

    # Verify config files have proper format
    local config_count
    config_count=$(find "$PROJECT_ROOT/locations/.test-downloads/dk" -name "*.ovpn" | wc -l)
    if [[ $config_count -eq 0 ]]; then
        log "FAIL" "No config files downloaded"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Config downloading and storage working"
    cleanup_test_environment
    return 0
}

# Test 5: Change detection with hash comparison
test_change_detection() {
    setup_test_environment

    # RED: Should fail initially - change detection not implemented

    # Clear rate limiting for this test
    rm -f "$PROJECT_ROOT/locations/.download-metadata/rate-limit.lock" 2>/dev/null || true

    # Create initial download state
    "$DOWNLOAD_ENGINE" download-country dk --test-mode 2>/dev/null || true

    # Test hash generation and comparison
    if ! "$DOWNLOAD_ENGINE" generate-hashes "$PROJECT_ROOT/locations/.test-downloads/dk" 2>/dev/null; then
        log "FAIL" "Cannot generate config hashes"
        cleanup_test_environment
        return 1
    fi

    # Verify hash file created
    if [[ ! -f "$PROJECT_ROOT/locations/.download-metadata/test-dk-hashes.db" ]]; then
        log "FAIL" "Hash database not created"
        cleanup_test_environment
        return 1
    fi

    # Test change detection
    if ! "$DOWNLOAD_ENGINE" check-changes dk --test-mode 2>/dev/null; then
        log "FAIL" "Change detection not working"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Change detection with hashing working"
    cleanup_test_environment
    return 0
}

# Test 6: Rate limiting enforcement
test_rate_limiting() {
    # RED: Should fail initially - rate limiting not implemented

    # Test rate limit status
    if ! "$DOWNLOAD_ENGINE" rate-limit-status 2>/dev/null | grep -q "Rate limit"; then
        log "FAIL" "Rate limiting status not available"
        return 1
    fi

    # Test rate limit enforcement (should prevent rapid requests)
    "$DOWNLOAD_ENGINE" download-country dk --test-mode 2>/dev/null || true
    if "$DOWNLOAD_ENGINE" download-country dk --test-mode 2>/dev/null; then
        log "FAIL" "Rate limiting not enforced - second request allowed immediately"
        return 1
    fi

    log "PASS" "Rate limiting enforcement working"
    return 0
}

# Test 7: Network error handling and retry logic
test_network_error_handling() {
    setup_test_environment

    # RED: Should fail initially - error handling not implemented

    # Test network error simulation
    if "$DOWNLOAD_ENGINE" download-country invalid --test-mode 2>/dev/null; then
        log "FAIL" "Network error handling not implemented"
        cleanup_test_environment
        return 1
    fi

    # Test retry mechanism
    if ! "$DOWNLOAD_ENGINE" retry-failed 2>/dev/null; then
        log "FAIL" "Retry mechanism not available"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Network error handling working"
    cleanup_test_environment
    return 0
}

# Test 8: Integration with existing file structure
test_file_structure_integration() {
    setup_test_environment

    # RED: Should fail initially - integration not implemented

    # Test integration with existing locations directory
    if ! "$DOWNLOAD_ENGINE" sync-with-existing 2>/dev/null; then
        log "FAIL" "Cannot sync with existing file structure"
        cleanup_test_environment
        return 1
    fi

    # Verify existing configs are preserved
    if [[ -f "$PROJECT_ROOT/locations/dk-134.protonvpn.udp.ovpn" ]]; then
        if ! "$DOWNLOAD_ENGINE" verify-existing "$PROJECT_ROOT/locations/dk-134.protonvpn.udp.ovpn" 2>/dev/null; then
            log "FAIL" "Cannot verify existing config files"
            cleanup_test_environment
            return 1
        fi
    fi

    log "PASS" "File structure integration working"
    cleanup_test_environment
    return 0
}

# Main test execution
main() {
    echo "=== RED PHASE: ProtonVPN Config Download Engine TDD Tests ==="
    echo "These tests SHOULD FAIL initially - they define expected behavior"
    echo

    # Run all tests
    run_test "Download engine module exists and shows help" test_download_engine_exists
    run_test "Authentication integration with Phase 1" test_authentication_integration
    run_test "ProtonVPN downloads page scraping capability" test_downloads_page_scraping
    run_test "Config file downloading and storage" test_config_downloading
    run_test "Change detection with hash comparison" test_change_detection
    run_test "Rate limiting enforcement" test_rate_limiting
    run_test "Network error handling and retry logic" test_network_error_handling
    run_test "Integration with existing file structure" test_file_structure_integration

    # Test summary
    echo
    echo "=== Download Engine TDD Test Results ==="
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "✓ EXPECTED: Some tests failed in RED phase"
        echo "This is normal - tests define behavior before implementation"
        return 0
    else
        echo "⚠️  UNEXPECTED: All tests passed in RED phase"
        echo "This suggests implementation already exists"
        return 1
    fi
}

# Execute main function
main "$@"

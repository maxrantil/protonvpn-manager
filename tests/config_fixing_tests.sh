#!/bin/bash
# ABOUTME: TDD tests for .ovpn configuration fixing functionality
# ABOUTME: Validates fix-ovpn-configs utility and config reliability patterns

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly FIX_TOOL="$PROJECT_ROOT/src/fix-ovpn-configs"
readonly LOCATIONS_DIR="$PROJECT_ROOT/locations"
readonly TEST_DIR="$PROJECT_ROOT/tests/test_configs"
readonly TEST_LOG="/tmp/config_fixing_tests.log"

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

# Required stability settings
readonly REQUIRED_SETTINGS=(
    "auth-user-pass vpn-credentials.txt"
    "auth-nocache"
    "mute-replay-warnings"
    "replay-window 128 30"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

print_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Config Fixing TDD Tests           ║${NC}"
    echo -e "${BLUE}║       Phase 5.6 Implementation        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BLUE}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log "PASS: $test_name"
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log "FAIL: $test_name"
    fi
    echo
}

setup_test_configs() {
    # Create test config directory
    mkdir -p "$TEST_DIR"

    # Create test configs with different states
    create_broken_config
    create_partial_config
    create_complete_config
    create_malformed_config
}

create_broken_config() {
    # Config missing all stability settings
    cat > "$TEST_DIR/test-broken.ovpn" << 'EOF'
client
dev tun
proto udp
remote 192.0.2.1 1194
resolv-retry infinite
nobind
cipher AES-256-GCM
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
<ca>
-----BEGIN CERTIFICATE-----
MIIB1DCCAT0CAQAwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL0sAMI=
-----END CERTIFICATE-----
</ca>
EOF
}

create_partial_config() {
    # Config with some but not all stability settings
    cat > "$TEST_DIR/test-partial.ovpn" << 'EOF'
client
dev tun
proto udp
remote 192.0.2.2 1194
resolv-retry infinite
nobind
cipher AES-256-GCM
persist-key
persist-tun
remote-cert-tls server
auth-user-pass vpn-credentials.txt
auth-nocache
<ca>
-----BEGIN CERTIFICATE-----
MIIB1DCCAT0CAQAwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL0sAMI=
-----END CERTIFICATE-----
</ca>
EOF
}

create_complete_config() {
    # Config with all stability settings
    cat > "$TEST_DIR/test-complete.ovpn" << 'EOF'
client
dev tun
proto udp
remote 192.0.2.3 1194
resolv-retry infinite
nobind
cipher AES-256-GCM
persist-key
persist-tun
remote-cert-tls server
auth-user-pass vpn-credentials.txt
auth-nocache
mute-replay-warnings
replay-window 128 30
<ca>
-----BEGIN CERTIFICATE-----
MIIB1DCCAT0CAQAwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL0sAMI=
-----END CERTIFICATE-----
</ca>
EOF
}

create_malformed_config() {
    # Invalid config file
    cat > "$TEST_DIR/test-malformed.ovpn" << 'EOF'
# This is not a valid OpenVPN config
invalid-directive
no-client-directive
EOF
}

cleanup_test_configs() {
    # Remove test configs
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# TEST 1: Fix tool executable and accessible
test_fix_tool_exists() {
    log "Testing fix-ovpn-configs tool accessibility"

    if [[ -x "$FIX_TOOL" ]]; then
        log "SUCCESS: Fix tool is executable"
        return 0
    else
        log "ERROR: Fix tool not found or not executable: $FIX_TOOL"
        return 1
    fi
}

# TEST 2: Check command works on test configs
test_check_command_functionality() {
    log "Testing fix-ovpn-configs --check functionality"

    setup_test_configs

    # Run check command on test directory using environment override
    if env env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" --check >/dev/null 2>&1; then
        log "SUCCESS: Check command runs without errors"
        cleanup_test_configs
        return 0
    else
        log "ERROR: Check command failed"
        cleanup_test_configs
        return 1
    fi
}

# TEST 3: Detect broken config correctly
test_detect_broken_config() {
    log "Testing detection of configs needing fixes"

    setup_test_configs

    # Check that broken config is detected as needing fix
    local check_output
    check_output=$(env env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" --check 2>/dev/null)

    if echo "$check_output" | grep -q "test-broken.ovpn" && echo "$check_output" | grep -q "NEEDS FIX"; then
        log "SUCCESS: Broken config correctly detected as needing fix"
        cleanup_test_configs
        return 0
    else
        log "ERROR: Broken config not detected as needing fix"
        cleanup_test_configs
        return 1
    fi
}

# TEST 4: Detect complete config correctly
test_detect_complete_config() {
    log "Testing detection of configs already fixed"

    setup_test_configs

    # Check that complete config is detected as already OK
    local check_output
    check_output=$(env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" --check 2>/dev/null)

    if echo "$check_output" | grep -q "test-complete.ovpn" && echo "$check_output" | grep -q "ALREADY OK"; then
        log "SUCCESS: Complete config correctly detected as already OK"
        cleanup_test_configs
        return 0
    else
        log "ERROR: Complete config not detected as already OK"
        cleanup_test_configs
        return 1
    fi
}

# TEST 5: Fix broken config correctly
test_fix_broken_config() {
    log "Testing fixing of broken config"

    setup_test_configs

    # Fix the configs
    if env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" --no-backup >/dev/null 2>&1; then
        # Check that all required settings are now present in broken config
        local all_present=true
        for setting in "${REQUIRED_SETTINGS[@]}"; do
            if ! grep -q "^$setting" "$TEST_DIR/test-broken.ovpn"; then
                log "ERROR: Missing required setting after fix: $setting"
                all_present=false
            fi
        done

        if [[ "$all_present" == "true" ]]; then
            log "SUCCESS: All required settings added to broken config"
            cleanup_test_configs
            return 0
        else
            log "ERROR: Not all settings were added during fix"
            cleanup_test_configs
            return 1
        fi
    else
        log "ERROR: Fix command failed"
        cleanup_test_configs
        return 1
    fi
}

# TEST 6: Don't break already complete configs
test_preserve_complete_config() {
    log "Testing preservation of already complete configs"

    setup_test_configs

    # Get original content
    local original_content
    original_content=$(cat "$TEST_DIR/test-complete.ovpn")

    # Run fix command
    if env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" --no-backup >/dev/null 2>&1; then
        # Check that complete config wasn't modified
        local new_content
        new_content=$(cat "$TEST_DIR/test-complete.ovpn")

        if [[ "$original_content" == "$new_content" ]]; then
            log "SUCCESS: Complete config preserved unchanged"
            cleanup_test_configs
            return 0
        else
            log "ERROR: Complete config was modified unnecessarily"
            cleanup_test_configs
            return 1
        fi
    else
        log "ERROR: Fix command failed"
        cleanup_test_configs
        return 1
    fi
}

# TEST 7: Validate real config reliability patterns
test_real_config_patterns() {
    log "Testing real config reliability patterns"

    if [[ ! -d "$LOCATIONS_DIR" ]]; then
        log "SKIP: No locations directory found for real config testing"
        return 0
    fi

    # Test known working configs (should show ALREADY OK)
    local working_configs=("se-65.protonvpn.udp.ovpn" "se-66.protonvpn.udp.ovpn")
    local check_output
    check_output=$("$FIX_TOOL" --check 2>/dev/null)

    local all_detected=true
    for config in "${working_configs[@]}"; do
        if [[ -f "$LOCATIONS_DIR/$config" ]]; then
            # Remove color codes and check for ALREADY OK pattern
            if ! echo "$check_output" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "ALREADY OK.*$config"; then
                log "ERROR: Working config $config not detected as ALREADY OK"
                all_detected=false
            fi
        fi
    done

    # Test se-au-01 (known working but detected as NEEDS FIX - this is expected)
    if [[ -f "$LOCATIONS_DIR/se-au-01.protonvpn.udp.ovpn" ]]; then
        if echo "$check_output" | grep -q "se-au-01.*NEEDS FIX"; then
            log "INFO: se-au-01 detected as NEEDS FIX (expected - works without stability settings)"
        fi
    fi

    if [[ "$all_detected" == "true" ]]; then
        log "SUCCESS: Real config patterns detected correctly"
        return 0
    else
        log "ERROR: Real config pattern detection failed"
        return 1
    fi
}

# TEST 8: Backup functionality
test_backup_functionality() {
    log "Testing backup creation functionality"

    setup_test_configs

    # Run fix with backup enabled (default)
    if env LOCATIONS_DIR="$TEST_DIR" "$FIX_TOOL" >/dev/null 2>&1; then
        # Check if backup directory was created
        local backup_dir="$TEST_DIR/backups"
        if [[ -d "$backup_dir" ]] && [[ -n "$(find "$backup_dir" -name "*.backup.*" 2>/dev/null)" ]]; then
            log "SUCCESS: Backup files created successfully"
            cleanup_test_configs
            return 0
        else
            log "ERROR: Backup files not created"
            cleanup_test_configs
            return 1
        fi
    else
        log "ERROR: Fix command with backup failed"
        cleanup_test_configs
        return 1
    fi
}

print_test_summary() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Test Summary                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo -e "Tests Run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED - Config fixing functionality verified${NC}"
        log "All config fixing tests passed"
        return 0
    else
        echo -e "${RED}✗ TESTS FAILED - Config fixing needs attention${NC}"
        log "Some config fixing tests failed"
        return 1
    fi
}

main() {
    # Initialize test log
    echo "Starting Config Fixing Tests - $(date)" > "$TEST_LOG"

    print_banner

    # Run all tests
    run_test "Fix Tool Accessibility" "test_fix_tool_exists"
    run_test "Check Command Functionality" "test_check_command_functionality"
    run_test "Detect Broken Config" "test_detect_broken_config"
    run_test "Detect Complete Config" "test_detect_complete_config"
    run_test "Fix Broken Config" "test_fix_broken_config"
    run_test "Preserve Complete Config" "test_preserve_complete_config"
    run_test "Real Config Patterns" "test_real_config_patterns"
    run_test "Backup Functionality" "test_backup_functionality"

    # Print summary and exit with appropriate code
    print_test_summary
}

# Only run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

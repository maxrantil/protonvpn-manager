#!/bin/bash
# ABOUTME: GREEN phase tests for 2FA TOTP authenticator - tests should PASS
# Test-driven development for ProtonVPN Config Downloader 2FA authentication

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/tests/test_framework.sh"

# Component under test
TOTP_AUTHENTICATOR="$PROJECT_ROOT/src/security/totp-authenticator"
CREDENTIAL_MANAGER="$PROJECT_ROOT/src/security/secure-credential-manager"

# Test data setup
TEST_CACHE_DIR="/tmp/vpn_test_totp_green_$$"
TEST_GPG_HOME="$TEST_CACHE_DIR/gnupg"
TEST_SECRET="JBSWY3DPEHPK3PXP"  # Valid Base32 TOTP secret
TEST_INVALID_SECRET="INVALID!@#$%"

setup_test_environment() {
    log_test "INFO" "Setting up GREEN phase 2FA TOTP test environment"
    mkdir -p "$TEST_CACHE_DIR" "$TEST_GPG_HOME"
    chmod 700 "$TEST_GPG_HOME"
    export GNUPGHOME="$TEST_GPG_HOME"
    export HOME="$TEST_CACHE_DIR"

    # Generate test GPG key for testing
    cat > "$TEST_GPG_HOME/key-gen-params" << EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: VPN Test User
Name-Email: test@vpn-manager.local
Expire-Date: 1y
Passphrase: test-passphrase-123
%commit
EOF

    gpg --batch --generate-key "$TEST_GPG_HOME/key-gen-params" 2>/dev/null
    TEST_KEY_ID=$(gpg --list-secret-keys --with-colons | grep '^sec' | cut -d: -f5)

    # Initialize credential manager
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1
}

cleanup_test_environment() {
    log_test "INFO" "Cleaning up GREEN phase 2FA TOTP test environment"
    rm -rf "$TEST_CACHE_DIR"
    unset GNUPGHOME HOME
}

# GREEN: Test 1 - Generate TOTP code successfully
test_generate_totp_code() {
    start_test "Generate TOTP code from secret"

    # This should succeed now (GREEN phase)
    local output
    output=$("$TOTP_AUTHENTICATOR" generate "$TEST_SECRET" 2>/dev/null)

    # Verify we got a 6-digit code
    if [[ "$output" =~ [0-9]{6} ]]; then
        log_test "PASS" "Generated valid 6-digit TOTP code: $output"
    else
        log_test "FAIL" "Invalid TOTP code format: $output"
        return 1
    fi
}

# GREEN: Test 2 - Validate TOTP secret format
test_totp_secret_validation() {
    start_test "Validate TOTP secret format (Base32 RFC 4648)"

    # Valid secret should pass
    assert_command_succeeds "$TOTP_AUTHENTICATOR validate-secret $TEST_SECRET" \
        "Valid TOTP secret should pass validation"
}

# GREEN: Test 3 - Store TOTP secret securely
test_store_totp_secret() {
    start_test "Store TOTP secret using secure credential manager"

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$TOTP_AUTHENTICATOR store-secret $TEST_SECRET" \
        "TOTP secret storage should succeed"

    # Verify the secret was stored in credential manager
    assert_command_succeeds "$CREDENTIAL_MANAGER get-totp" \
        "Stored TOTP secret should be retrievable"
}

# GREEN: Test 4 - TOTP code validation with timing
test_validate_totp_timing() {
    start_test "Validate TOTP code with 30-second time windows"

    # Generate a current code
    local current_code
    current_code=$("$TOTP_AUTHENTICATOR" generate "$TEST_SECRET" 2>/dev/null | tail -1)

    # Validate the same code (should pass within the time window)
    assert_command_succeeds "$TOTP_AUTHENTICATOR validate $TEST_SECRET $current_code" \
        "Current TOTP code should validate successfully"

    # Test invalid code
    assert_command_fails "$TOTP_AUTHENTICATOR validate $TEST_SECRET 000000" \
        "Invalid TOTP code should fail validation"
}

# GREEN: Test 5 - TOTP expiration timing check
test_totp_expiration() {
    start_test "Handle TOTP code expiration and timing windows"

    # This should succeed now (GREEN phase)
    local output
    output=$("$TOTP_AUTHENTICATOR" check-expiration 2>/dev/null)

    assert_contains "$output" "Current TOTP window" "Output should contain timing information"
    assert_contains "$output" "Seconds until next code" "Output should contain expiration info"
}

# GREEN: Test 6 - Error handling for invalid secrets
test_invalid_secret_handling() {
    start_test "Error handling for invalid TOTP secrets"

    # Invalid secret should fail gracefully
    assert_command_fails "$TOTP_AUTHENTICATOR validate-secret $TEST_INVALID_SECRET" \
        "Invalid TOTP secret should fail validation"

    assert_command_fails "$TOTP_AUTHENTICATOR generate $TEST_INVALID_SECRET" \
        "Invalid TOTP secret should fail code generation"
}

# GREEN: Test 7 - TOTP backup codes generation
test_totp_backup_codes() {
    start_test "TOTP backup codes for recovery"

    # This should succeed now (GREEN phase)
    local output
    output=$("$TOTP_AUTHENTICATOR" generate-backup-codes 2>/dev/null)

    assert_contains "$output" "TOTP Backup Codes" "Output should contain backup codes header"
    assert_contains "$output" "Store these codes securely" "Output should contain security warning"

    # Count the backup codes (should be 10)
    local code_count
    code_count=$(echo "$output" | grep -c "^[[:space:]]*[0-9]*\.")

    if [[ $code_count -eq 10 ]]; then
        log_test "PASS" "Generated correct number of backup codes: $code_count"
    else
        log_test "FAIL" "Wrong number of backup codes: $code_count (expected 10)"
        return 1
    fi
}

# GREEN: Test 8 - Full integration test
test_full_integration() {
    start_test "Full TOTP integration with credential manager"

    # Store secret via TOTP authenticator
    "$TOTP_AUTHENTICATOR" store-secret "$TEST_SECRET" >/dev/null 2>&1

    # Generate code from stored secret
    local stored_code
    if stored_code=$("$TOTP_AUTHENTICATOR" generate-from-stored 2>/dev/null | tail -1); then
        log_test "PASS" "Successfully generated code from stored secret: $stored_code"
    else
        log_test "FAIL" "Failed to generate code from stored secret"
        return 1
    fi

    # Verify the code format
    if [[ "$stored_code" =~ ^[0-9]{6}$ ]]; then
        log_test "PASS" "Generated code has correct format"
    else
        log_test "FAIL" "Generated code has invalid format: $stored_code"
        return 1
    fi
}

# Main test execution
main() {
    log_test "INFO" "Starting TDD GREEN phase tests for 2FA TOTP Authenticator"
    log_test "INFO" "Phase: GREEN - All tests should pass (component implemented)"

    setup_test_environment

    # Run all GREEN phase tests
    test_generate_totp_code
    test_totp_secret_validation
    test_store_totp_secret
    test_validate_totp_timing
    test_totp_expiration
    test_invalid_secret_handling
    test_totp_backup_codes
    test_full_integration

    cleanup_test_environment

    show_test_summary
    log_test "INFO" "TDD GREEN Phase Complete: 2FA TOTP authenticator implementation verified"
    log_test "INFO" "Next: REFACTOR phase - Improve code while keeping tests green"
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

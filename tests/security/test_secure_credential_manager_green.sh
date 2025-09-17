#!/bin/bash
# ABOUTME: GREEN phase tests for secure credential manager - tests should PASS
# Test-driven development for ProtonVPN Config Downloader security foundation

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/tests/test_framework.sh"

# Component under test
CREDENTIAL_MANAGER="$PROJECT_ROOT/src/security/secure-credential-manager"

# Test data setup
TEST_CACHE_DIR="/tmp/vpn_test_credentials_green_$$"
TEST_GPG_HOME="$TEST_CACHE_DIR/gnupg"

setup_test_environment() {
    log_test "INFO" "Setting up GREEN phase test environment"
    mkdir -p "$TEST_CACHE_DIR" "$TEST_GPG_HOME"
    chmod 700 "$TEST_GPG_HOME"
    export GNUPGHOME="$TEST_GPG_HOME"
    export HOME="$TEST_CACHE_DIR"  # Override HOME for credential storage

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
}

cleanup_test_environment() {
    log_test "INFO" "Cleaning up GREEN phase test environment"
    rm -rf "$TEST_CACHE_DIR"
    unset GNUPGHOME HOME
}

# GREEN: Test 1 - Initialize secure storage
test_init_secure_storage() {
    start_test "Initialize secure storage successfully"

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$CREDENTIAL_MANAGER init" "Initialization should succeed"

    # Verify directories were created
    assert_file_exists "$HOME/.cache/vpn/credentials" "Credentials directory should exist"
    assert_file_exists "$HOME/.cache/vpn/migration-backup" "Backup directory should exist"
}

# GREEN: Test 2 - Store ProtonVPN credentials successfully
test_store_protonvpn_credentials() {
    start_test "Store ProtonVPN account credentials with GPG encryption"

    # Initialize first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$CREDENTIAL_MANAGER store-protonvpn test-user test-password" \
        "Storing ProtonVPN credentials should succeed"

    # Verify encrypted file was created
    assert_file_exists "$HOME/.cache/vpn/credentials/proton-account.gpg" \
        "Encrypted ProtonVPN credentials file should exist"
}

# GREEN: Test 3 - Store TOTP secret successfully
test_store_totp_secret() {
    start_test "Store TOTP secret with Base32 validation"

    local test_secret="JBSWY3DPEHPK3PXP"  # Valid Base32 TOTP secret

    # Initialize first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$CREDENTIAL_MANAGER store-totp $test_secret" \
        "Storing TOTP secret should succeed"

    # Verify encrypted file was created
    assert_file_exists "$HOME/.cache/vpn/credentials/totp-secret.gpg" \
        "Encrypted TOTP secret file should exist"
}

# GREEN: Test 4 - Retrieve credentials successfully
test_retrieve_credentials() {
    start_test "Retrieve encrypted credentials with authentication"

    # Initialize and store credentials first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1
    "$CREDENTIAL_MANAGER" store-protonvpn "testuser" "testpass" >/dev/null 2>&1

    # This should succeed now (GREEN phase)
    local output
    output=$("$CREDENTIAL_MANAGER" get-protonvpn 2>/dev/null)

    assert_contains "$output" "USERNAME=testuser" "Output should contain username"
    assert_contains "$output" "PASSWORD=testpass" "Output should contain password"
}

# GREEN: Test 5 - Validate credential security
test_credential_security() {
    start_test "Validate credential file permissions and encryption"

    # Initialize storage first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$CREDENTIAL_MANAGER security-check" \
        "Security check should pass with proper setup"
}

# GREEN: Test 6 - Input validation works correctly
test_input_validation() {
    start_test "Validate input sanitization and credential format"

    # Initialize first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1

    # Test valid TOTP secret
    local valid_secret="JBSWY3DPEHPK3PXP"
    assert_command_succeeds "$CREDENTIAL_MANAGER validate-totp $valid_secret" \
        "Valid TOTP secret should pass validation"

    # Test invalid TOTP secret
    local invalid_secret="INVALID!@#$%"
    assert_command_fails "$CREDENTIAL_MANAGER validate-totp $invalid_secret" \
        "Invalid TOTP secret should fail validation"
}

# GREEN: Test 7 - Backup functionality
test_credential_backup() {
    start_test "Create secure backup and rollback capability"

    # Initialize and store some credentials first
    "$CREDENTIAL_MANAGER" init >/dev/null 2>&1
    "$CREDENTIAL_MANAGER" store-protonvpn "backup-user" "backup-pass" >/dev/null 2>&1

    # This should succeed now (GREEN phase)
    assert_command_succeeds "$CREDENTIAL_MANAGER create-backup" \
        "Creating backup should succeed"

    # Verify backup file was created
    local backup_files
    backup_files=$(find "$HOME/.cache/vpn/migration-backup" -name "credentials_backup_*.tar.gz.gpg" 2>/dev/null || true)

    if [[ -n "$backup_files" ]]; then
        log_test "PASS" "Backup file created successfully"
    else
        log_test "FAIL" "No backup file found"
        return 1
    fi
}

# Main test execution
main() {
    log_test "INFO" "Starting TDD GREEN phase tests for Secure Credential Manager"
    log_test "INFO" "Phase: GREEN - All tests should pass (component implemented)"

    setup_test_environment

    # Run all GREEN phase tests
    test_init_secure_storage
    test_store_protonvpn_credentials
    test_store_totp_secret
    test_retrieve_credentials
    test_credential_security
    test_input_validation
    test_credential_backup

    cleanup_test_environment

    show_test_summary
    log_test "INFO" "TDD GREEN Phase Complete: Secure credential manager implementation verified"
    log_test "INFO" "Next: REFACTOR phase - Improve code while keeping tests green"
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash
# ABOUTME: TDD tests for ProtonVPN OpenVPN config validator module
# RED phase tests defining expected behavior for config validation

set -euo pipefail

# Test configuration
TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_SCRIPT_DIR")"
CONFIG_VALIDATOR="$PROJECT_ROOT/src/config-validator"

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
    log "INFO" "Setting up config validator test environment"
    mkdir -p "$PROJECT_ROOT/test-configs"
}

cleanup_test_environment() {
    log "INFO" "Cleaning up config validator test environment"
    rm -rf "$PROJECT_ROOT/test-configs" 2> /dev/null || true
}

# Test config creation helpers
create_valid_ovpn_config() {
    local filepath="$1"
    cat > "$filepath" << 'EOF'
client
dev tun
proto udp
remote 185.159.158.228 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
verb 3
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
reneg-sec 0
remote-cert-tls server
auth-nocache

<ca>
-----BEGIN CERTIFICATE-----
MIIFozCCA4ugAwIBAgIBATANBgkqhkiG9w0BAQ0FADBAMQswCQYDVQQGEwJDSDEV
MBMGA1UEChMMUHJvdG9uVlBOIEFHMRowGAYDVQQDExFQcm90b25WUE4gUm9vdCBD
QTAeFw0xNzAyMTUxNDM4MDBaFw0yNzAyMTUxNDM4MDBaMEAxCzAJBgNVBAYTAkNI
MRUwEwYDVQQKEwxQcm90b25WUE4gQUcxGjAYBgNVBAMTEVByb3RvblZQTiBSb290
IENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt+BsSsZg7+AuqTq7
vDbPzfygtl9f8fLJqO4amsyOXlI7pquL5IsEZhpWyJIIvYybqS4s1/T7BbvHPLVE
wlrq8A5DBIXcfuXrBbKoYkmpICGc2u1KYVGOZ9A+PH9z4Tr6OXFfXRnsbZToie8t
2Xjv/dZDdUDAqeW89I/mNQ6FzBQbJQ1lmF/D+L/HmK4lz5Kg8Uqiob7Nv7eW2u7K
uHF6fVmx2Lfn
-----END CERTIFICATE-----
</ca>

<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
6acef03f62675b4b1bbd03e53b187727423cea36360d25b686e3a1b2c7e25c3a
a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890
1234567890123456789012345678901234567890123456789012345678901234567890
-----END OpenVPN Static key V1-----
</tls-crypt>
EOF
}

create_malformed_ovpn_config() {
    local filepath="$1"
    cat > "$filepath" << 'EOF'
# Missing required fields
client
dev tun
proto udp
# Missing remote server
nobind
persist-key
# Invalid cipher
cipher INVALID-CIPHER
verb 3

# Missing certificates
# Missing tls-crypt
EOF
}

create_invalid_certificate_config() {
    local filepath="$1"
    cat > "$filepath" << 'EOF'
client
dev tun
proto udp
remote 185.159.158.228 1194
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
verb 3

<ca>
-----BEGIN CERTIFICATE-----
INVALID_CERTIFICATE_DATA_HERE_NOT_VALID_BASE64
-----END CERTIFICATE-----
</ca>
EOF
}

# Test 1: Module existence and help functionality
test_config_validator_exists() {
    # RED: This should fail initially - module doesn't exist yet
    if [[ ! -f "$CONFIG_VALIDATOR" ]]; then
        log "FAIL" "Config validator module does not exist at $CONFIG_VALIDATOR"
        return 1
    fi

    if [[ ! -x "$CONFIG_VALIDATOR" ]]; then
        log "FAIL" "Config validator is not executable"
        return 1
    fi

    # Test help command
    if ! "$CONFIG_VALIDATOR" help > /dev/null 2>&1; then
        log "FAIL" "Config validator help command failed"
        return 1
    fi

    # Verify expected commands are documented
    local help_output
    help_output=$("$CONFIG_VALIDATOR" help 2>&1)

    if ! echo "$help_output" | grep -q "validate-file"; then
        log "FAIL" "Help missing validate-file command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "validate-dir"; then
        log "FAIL" "Help missing validate-dir command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "check-integrity"; then
        log "FAIL" "Help missing check-integrity command"
        return 1
    fi

    log "PASS" "Config validator exists with proper help"
    return 0
}

# Test 2: Valid OpenVPN config file validation
test_valid_config_validation() {
    setup_test_environment

    # Create a valid OpenVPN config
    local valid_config="$PROJECT_ROOT/test-configs/valid.ovpn"
    create_valid_ovpn_config "$valid_config"

    # RED: Should fail initially - validation not implemented
    if ! "$CONFIG_VALIDATOR" validate-file "$valid_config" 2> /dev/null; then
        log "FAIL" "Cannot validate valid OpenVPN config"
        cleanup_test_environment
        return 1
    fi

    # Check validation output contains expected information
    local validation_output
    validation_output=$("$CONFIG_VALIDATOR" validate-file "$valid_config" 2>&1)

    if ! echo "$validation_output" | grep -q "VALID"; then
        log "FAIL" "Valid config not marked as VALID"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Valid config validation working"
    cleanup_test_environment
    return 0
}

# Test 3: Required fields checking
test_required_fields_checking() {
    setup_test_environment

    # Create config missing required fields
    local malformed_config="$PROJECT_ROOT/test-configs/malformed.ovpn"
    create_malformed_ovpn_config "$malformed_config"

    # RED: Should fail initially - field checking not implemented
    if "$CONFIG_VALIDATOR" validate-file "$malformed_config" 2> /dev/null; then
        log "FAIL" "Malformed config incorrectly validated as valid"
        cleanup_test_environment
        return 1
    fi

    # Check that specific missing fields are identified
    local validation_output
    validation_output=$("$CONFIG_VALIDATOR" validate-file "$malformed_config" 2>&1)

    if ! echo "$validation_output" | grep -qi "remote"; then
        log "FAIL" "Missing remote server not detected"
        cleanup_test_environment
        return 1
    fi

    if ! echo "$validation_output" | grep -qi "cipher"; then
        log "FAIL" "Invalid cipher not detected"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Required fields checking working"
    cleanup_test_environment
    return 0
}

# Test 4: Certificate validation
test_certificate_validation() {
    setup_test_environment

    # Create config with invalid certificate
    local invalid_cert_config="$PROJECT_ROOT/test-configs/invalid-cert.ovpn"
    create_invalid_certificate_config "$invalid_cert_config"

    # RED: Should fail initially - certificate validation not implemented
    if "$CONFIG_VALIDATOR" validate-file "$invalid_cert_config" 2> /dev/null; then
        log "FAIL" "Invalid certificate config incorrectly validated"
        cleanup_test_environment
        return 1
    fi

    # Check that certificate issues are identified
    local validation_output
    validation_output=$("$CONFIG_VALIDATOR" validate-file "$invalid_cert_config" 2>&1)

    if ! echo "$validation_output" | grep -q "certificate.*invalid"; then
        log "FAIL" "Invalid certificate not detected"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Certificate validation working"
    cleanup_test_environment
    return 0
}

# Test 5: Directory batch validation
test_directory_batch_validation() {
    setup_test_environment

    # Create multiple config files
    create_valid_ovpn_config "$PROJECT_ROOT/test-configs/valid1.ovpn"
    create_valid_ovpn_config "$PROJECT_ROOT/test-configs/valid2.ovpn"
    create_malformed_ovpn_config "$PROJECT_ROOT/test-configs/invalid1.ovpn"

    # RED: Should fail initially - directory validation not implemented
    if ! "$CONFIG_VALIDATOR" validate-dir "$PROJECT_ROOT/test-configs" 2> /dev/null; then
        log "FAIL" "Cannot validate directory of configs"
        cleanup_test_environment
        return 1
    fi

    # Check validation summary
    local validation_output
    validation_output=$("$CONFIG_VALIDATOR" validate-dir "$PROJECT_ROOT/test-configs" 2>&1)

    if ! echo "$validation_output" | grep -q "2.*valid"; then
        log "FAIL" "Directory validation doesn't count valid configs correctly"
        cleanup_test_environment
        return 1
    fi

    if ! echo "$validation_output" | grep -q "1.*invalid"; then
        log "FAIL" "Directory validation doesn't count invalid configs correctly"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Directory batch validation working"
    cleanup_test_environment
    return 0
}

# Test 6: Hash integrity verification
test_hash_integrity_verification() {
    setup_test_environment

    # Create valid config and generate hash
    local valid_config="$PROJECT_ROOT/test-configs/hashtest.ovpn"
    create_valid_ovpn_config "$valid_config"

    # RED: Should fail initially - hash checking not implemented
    if ! "$CONFIG_VALIDATOR" check-integrity "$PROJECT_ROOT/test-configs" 2> /dev/null; then
        log "FAIL" "Cannot perform integrity checking"
        cleanup_test_environment
        return 1
    fi

    # Verify hash database is created/updated
    if ! "$CONFIG_VALIDATOR" generate-hashes "$PROJECT_ROOT/test-configs" 2> /dev/null; then
        log "FAIL" "Cannot generate config hashes"
        cleanup_test_environment
        return 1
    fi

    # Check that hash verification works
    local integrity_output
    integrity_output=$("$CONFIG_VALIDATOR" check-integrity "$PROJECT_ROOT/test-configs" 2>&1)

    if ! echo "$integrity_output" | grep -q "integrity.*verified"; then
        log "FAIL" "Hash integrity verification not working"
        cleanup_test_environment
        return 1
    fi

    log "PASS" "Hash integrity verification working"
    cleanup_test_environment
    return 0
}

# Main test execution
main() {
    echo "=== RED PHASE: ProtonVPN Config Validator TDD Tests ==="
    echo "These tests SHOULD FAIL initially - they define expected behavior"
    echo

    # Run all tests
    run_test "Config validator module exists and shows help" test_config_validator_exists
    run_test "Valid OpenVPN config file validation" test_valid_config_validation
    run_test "Required fields checking" test_required_fields_checking
    run_test "Certificate validation" test_certificate_validation
    run_test "Directory batch validation" test_directory_batch_validation
    run_test "Hash integrity verification" test_hash_integrity_verification

    # Test summary
    echo
    echo "=== Config Validator TDD Test Results ==="
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

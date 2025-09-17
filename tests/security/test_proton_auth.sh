#!/bin/bash
# ABOUTME: TDD tests for ProtonVPN authentication module (RED phase)
# SECURITY: Tests critical authentication flows and security boundaries

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly TEST_SUITE_NAME="ProtonVPN Authentication Module"
readonly AUTH_MODULE="${PROJECT_ROOT}/src/proton-auth"
readonly TEST_CREDENTIALS_DIR="/tmp/vpn-test-credentials"
readonly TEST_SESSION_DIR="/tmp/vpn-test-sessions"

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

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BLUE}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

pass() {
    local message="$1"
    log_message "PASS" "$message"
    return 0
}

fail() {
    local message="$1"
    log_message "FAIL" "$message"
    return 1
}

# Test setup
setup_auth_test_environment() {
    log_message "INFO" "Setting up authentication test environment"

    # Create test directories
    mkdir -p "$TEST_CREDENTIALS_DIR" "$TEST_SESSION_DIR"
    chmod 700 "$TEST_CREDENTIALS_DIR" "$TEST_SESSION_DIR"

    # Clear any existing sessions and rate limiting for clean tests
    rm -f "$HOME/.cache/vpn/sessions/proton-session.state"*
    rm -f "$HOME/.cache/vpn/sessions/csrf-token"*
    rm -f "$HOME/.cache/vpn/rate-limit.log"
    rm -f "$HOME/.cache/vpn/rate-limit-state"
    rm -f "$HOME/.cache/vpn/totp-used-codes"
    rm -rf "$HOME/.cache/vpn/locks"

    # Mock test credentials
    export TEST_PROTON_USERNAME="testuser@example.com"
    export TEST_PROTON_PASSWORD="testpassword123"
    export TEST_TOTP_SECRET="JBSWY3DPEHPK3PXP"

    # Create mock credential files for testing
    echo "USERNAME=$TEST_PROTON_USERNAME" > "$TEST_CREDENTIALS_DIR/proton-test.creds"
    echo "PASSWORD=$TEST_PROTON_PASSWORD" >> "$TEST_CREDENTIALS_DIR/proton-test.creds"
    chmod 600 "$TEST_CREDENTIALS_DIR/proton-test.creds"

    # Set short rate limit for testing
    export PROTON_AUTH_RATE_LIMIT=1
}

# Test cleanup
cleanup_auth_test_environment() {
    rm -rf "$TEST_CREDENTIALS_DIR" "$TEST_SESSION_DIR"
    unset TEST_PROTON_USERNAME TEST_PROTON_PASSWORD TEST_TOTP_SECRET
}

# TDD RED PHASE: These tests should FAIL initially
# They define the expected behavior before implementation

# Test 1: Basic authentication module existence and help
test_proton_auth_module_exists() {
    log_message "INFO" "ProtonVPN auth module exists and shows help"

    # This should fail initially - module doesn't exist yet
    if [[ ! -f "$AUTH_MODULE" ]]; then
        fail "ProtonVPN auth module not found at $AUTH_MODULE"
        return 1
    fi

    # Test executable permissions
    if [[ ! -x "$AUTH_MODULE" ]]; then
        fail "ProtonVPN auth module is not executable"
        return 1
    fi

    # Test help command
    local help_output
    help_output=$("$AUTH_MODULE" help 2>&1) || {
        fail "Failed to get help from ProtonVPN auth module"
        return 1
    }

    # Verify help contains expected commands
    if ! echo "$help_output" | grep -q "authenticate"; then
        fail "Help output missing 'authenticate' command"
        return 1
    fi

    if ! echo "$help_output" | grep -q "validate-session"; then
        fail "Help output missing 'validate-session' command"
        return 1
    fi

    pass "ProtonVPN auth module exists and shows proper help"
}

# Test 2: Authentication with valid credentials
test_proton_authentication_success() {
    log_message "INFO" "ProtonVPN authentication with valid credentials"

    setup_auth_test_environment

    # This should fail initially - authentication not implemented
    local auth_result
    auth_result=$("$AUTH_MODULE" authenticate "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "Authentication failed with exit code $exit_code: $auth_result"
        cleanup_auth_test_environment
        return 1
    fi

    # Verify encrypted session file created (GPG or OpenSSL)
    local session_file_base="$HOME/.cache/vpn/sessions/proton-session.state"
    local session_found=false

    if [[ -f "$session_file_base.gpg" ]]; then
        session_found=true
        # Verify GPG session file permissions
        local file_perms
        file_perms=$(stat -c %a "$session_file_base.gpg")
        if [[ "$file_perms" != "600" ]]; then
            fail "GPG session file has incorrect permissions: $file_perms (expected 600)"
            cleanup_auth_test_environment
            return 1
        fi
    elif [[ -f "$session_file_base.enc" ]]; then
        session_found=true
        # Verify OpenSSL session file permissions
        local file_perms
        file_perms=$(stat -c %a "$session_file_base.enc")
        if [[ "$file_perms" != "600" ]]; then
            fail "OpenSSL session file has incorrect permissions: $file_perms (expected 600)"
            cleanup_auth_test_environment
            return 1
        fi
    elif [[ -f "$session_file_base" ]]; then
        session_found=true
        # Verify plaintext session file permissions (legacy support)
        local file_perms
        file_perms=$(stat -c %a "$session_file_base")
        if [[ "$file_perms" != "600" ]]; then
            fail "Session file has incorrect permissions: $file_perms (expected 600)"
            cleanup_auth_test_environment
            return 1
        fi
    fi

    if [[ "$session_found" != "true" ]]; then
        fail "No session file created (checked .gpg, .enc, and plaintext)"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
    pass "Authentication succeeded and created secure session file"
}

# Test 3: 2FA TOTP integration
test_proton_2fa_authentication() {
    log_message "INFO" "ProtonVPN 2FA TOTP authentication"

    setup_auth_test_environment

    # Generate TOTP code using existing authenticator
    local totp_code
    totp_code=$("${PROJECT_ROOT}/src/security/totp-authenticator" generate "$TEST_TOTP_SECRET" 2>/dev/null | tail -1)

    if [[ -z "$totp_code" ]]; then
        fail "Failed to generate TOTP code for testing"
        cleanup_auth_test_environment
        return 1
    fi

    # Test 2FA authentication (should fail initially - not implemented)
    local auth_result
    auth_result=$("$AUTH_MODULE" authenticate-2fa "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" "$totp_code" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "2FA authentication failed with exit code $exit_code: $auth_result"
        cleanup_auth_test_environment
        return 1
    fi

    # Verify 2FA session contains TOTP validation
    local session_file="$HOME/.cache/vpn/sessions/proton-session.state"
    if [[ -f "$session_file" ]]; then
        if ! grep -q "2FA_VALIDATED=true" "$session_file"; then
            fail "Session does not indicate 2FA validation"
            cleanup_auth_test_environment
            return 1
        fi
    fi

    cleanup_auth_test_environment
    pass "2FA authentication succeeded with TOTP validation"
}

# Test 4: Session validation and CSRF token handling
test_session_validation() {
    log_message "INFO" "Session validation and CSRF token handling"

    setup_auth_test_environment

    # First authenticate to create a session (this should fail initially)
    "$AUTH_MODULE" authenticate "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" >/dev/null 2>&1 || {
        fail "Cannot test session validation without successful authentication"
        cleanup_auth_test_environment
        return 1
    }

    # Test session validation
    local validation_result
    validation_result=$("$AUTH_MODULE" validate-session 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "Session validation failed with exit code $exit_code: $validation_result"
        cleanup_auth_test_environment
        return 1
    fi

    # Verify CSRF token is present
    if ! echo "$validation_result" | grep -q "CSRF_TOKEN="; then
        fail "Session validation output missing CSRF token"
        cleanup_auth_test_environment
        return 1
    fi

    # Verify session expiry information
    if ! echo "$validation_result" | grep -q "EXPIRES_AT="; then
        fail "Session validation output missing expiry information"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
    pass "Session validation succeeded with CSRF token"
}

# Test 5: Rate limiting enforcement
test_rate_limiting() {
    log_message "INFO" "Rate limiting enforcement"

    # Setup environment but don't clear rate limit state
    mkdir -p "$TEST_CREDENTIALS_DIR" "$TEST_SESSION_DIR" "$HOME/.cache/vpn"
    chmod 700 "$TEST_CREDENTIALS_DIR" "$TEST_SESSION_DIR"

    # Clear only session files, keep rate limit state for this test
    rm -f "$HOME/.cache/vpn/sessions/proton-session.state"*
    rm -f "$HOME/.cache/vpn/sessions/csrf-token"*

    # Set test credentials and short rate limit
    export TEST_PROTON_USERNAME="testuser@example.com"
    export TEST_PROTON_PASSWORD="testpassword123"
    export PROTON_AUTH_RATE_LIMIT=1

    # First authentication attempt
    "$AUTH_MODULE" authenticate "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" >/dev/null 2>&1

    # Immediate second attempt should be rate limited
    local rate_limit_result
    rate_limit_result=$("$AUTH_MODULE" authenticate "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" 2>&1)
    local exit_code=$?

    # Should fail with rate limit error code
    if [[ $exit_code -ne 3 ]]; then
        fail "Rate limiting not enforced - expected exit code 3, got $exit_code"
        cleanup_auth_test_environment
        return 1
    fi

    # Check for rate limiting message
    if echo "$rate_limit_result" | grep -q -i "rate.limit\|too.many\|wait\|violation"; then
        pass "Rate limiting properly enforced with user feedback"
    else
        fail "Rate limiting message not found: $rate_limit_result"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
}

# Test 6: Error handling for invalid credentials
test_invalid_credentials_handling() {
    log_message "INFO" "Invalid credentials error handling"

    setup_auth_test_environment

    # Test with invalid credentials (short password)
    local auth_result
    auth_result=$("$AUTH_MODULE" authenticate "invalid@user.com" "bad" 2>&1)
    local exit_code=$?

    # Should fail with specific error code
    if [[ $exit_code -ne 1 ]]; then
        fail "Invalid credentials should return exit code 1, got $exit_code"
        cleanup_auth_test_environment
        return 1
    fi

    # Should not contain actual credentials in error message
    if echo "$auth_result" | grep -q "bad"; then
        fail "Error message contains password - security issue"
        cleanup_auth_test_environment
        return 1
    fi

    # Should provide helpful error message
    if ! echo "$auth_result" | grep -q -i "error\|password\|short\|invalid"; then
        fail "Error message not helpful for user: $auth_result"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
    pass "Invalid credentials handled securely with helpful error"
}

# Test 7: Integration with Phase 0 security components
test_security_integration() {
    log_message "INFO" "Integration with Phase 0 security components"

    setup_auth_test_environment

    # Test credential manager integration
    local cred_manager="${PROJECT_ROOT}/src/security/secure-credential-manager"
    if [[ ! -x "$cred_manager" ]]; then
        fail "Secure credential manager not available for integration"
        cleanup_auth_test_environment
        return 1
    fi

    # Test TOTP authenticator integration
    local totp_auth="${PROJECT_ROOT}/src/security/totp-authenticator"
    if [[ ! -x "$totp_auth" ]]; then
        fail "TOTP authenticator not available for integration"
        cleanup_auth_test_environment
        return 1
    fi

    # Test that auth module can call these components
    local integration_result
    integration_result=$("$AUTH_MODULE" test-integration 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "Security component integration test failed: $integration_result"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
    pass "Successfully integrated with Phase 0 security components"
}

# Test 8: Session persistence across process restarts
test_session_persistence() {
    log_message "INFO" "Session persistence across process restarts"

    setup_auth_test_environment

    # Create a session
    "$AUTH_MODULE" authenticate "$TEST_PROTON_USERNAME" "$TEST_PROTON_PASSWORD" >/dev/null 2>&1 || {
        fail "Cannot test persistence without successful authentication"
        cleanup_auth_test_environment
        return 1
    }

    # Get initial session info
    local initial_session
    initial_session=$("$AUTH_MODULE" get-session-info 2>&1)

    # Simulate process restart by checking session again
    local restored_session
    restored_session=$("$AUTH_MODULE" get-session-info 2>&1)

    if [[ "$initial_session" != "$restored_session" ]]; then
        fail "Session not properly persisted across calls"
        cleanup_auth_test_environment
        return 1
    fi

    cleanup_auth_test_environment
    pass "Session properly persisted across process restarts"
}

# Test Runner
run_proton_auth_tests() {
    echo "=== RED PHASE: ProtonVPN Authentication Module TDD Tests ==="
    echo "These tests SHOULD FAIL initially - they define expected behavior"
    echo

    # Initialize test counters
    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Core functionality tests
    run_test "ProtonVPN auth module exists and shows help" test_proton_auth_module_exists
    run_test "ProtonVPN authentication with valid credentials" test_proton_authentication_success
    run_test "ProtonVPN 2FA TOTP authentication" test_proton_2fa_authentication

    # Security and session tests
    run_test "Session validation and CSRF token handling" test_session_validation
    run_test "Rate limiting enforcement" test_rate_limiting

    # Error handling tests
    run_test "Invalid credentials error handling" test_invalid_credentials_handling

    # Integration tests
    run_test "Integration with Phase 0 security components" test_security_integration
    run_test "Session persistence across process restarts" test_session_persistence

    total_tests=$TESTS_RUN
    passed_tests=$TESTS_PASSED
    failed_tests=$TESTS_FAILED

    # Test summary
    echo
    echo "=== ProtonVPN Authentication TDD Test Results ==="
    echo "Total tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo

    if [[ $failed_tests -eq $total_tests ]]; then
        echo "✅ RED PHASE SUCCESS: All tests failed as expected"
        echo "Ready to proceed to GREEN phase (minimal implementation)"
        return 0
    elif [[ $passed_tests -gt 0 ]]; then
        echo "⚠️  UNEXPECTED: Some tests passed in RED phase"
        echo "This suggests partial implementation already exists"
        return 1
    else
        echo "❌ TEST FRAMEWORK ERROR: Unexpected test results"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_proton_auth_tests
fi

#!/bin/bash
# ABOUTME: TDD tests for VPN connection functionality to prevent regressions
# ABOUTME: These tests MUST pass for any changes to be merged - no exceptions

set -euo pipefail

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/test_framework.sh"

# CRITICAL: Tests that prevent connection regressions
test_vpn_connect_basic_functionality() {
    start_test "VPN Connect Basic Functionality"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test basic connection attempt doesn't crash with unbound variables
    local connection_output
    connection_output=$(timeout 10s "$vpn_script" connect se 2>&1 || echo "TIMEOUT_OR_ERROR")

    # CRITICAL: Must not contain unbound variable errors
    if echo "$connection_output" | grep -q "unbound variable"; then
        log_test "FAIL" "$CURRENT_TEST: Unbound variable error detected"
        FAILED_TESTS+=("$CURRENT_TEST: unbound variable regression")
        ((TESTS_FAILED++))
        echo "ERROR OUTPUT:"
        echo "$connection_output"
        return 1
    fi

    # CRITICAL: Must not crash on basic connection attempt
    if echo "$connection_output" | grep -q "TIMEOUT_OR_ERROR"; then
        log_test "FAIL" "$CURRENT_TEST: Connection command crashed or timed out"
        FAILED_TESTS+=("$CURRENT_TEST: command crash")
        ((TESTS_FAILED++))
        echo "ERROR OUTPUT:"
        echo "$connection_output"
        return 1
    fi

    # CRITICAL: Must attempt to find profiles
    if ! echo "$connection_output" | grep -q -E "(Selected profile|profile.*se|se.*profile)"; then
        log_test "FAIL" "$CURRENT_TEST: No profile selection attempted"
        FAILED_TESTS+=("$CURRENT_TEST: profile selection failure")
        ((TESTS_FAILED++))
        echo "OUTPUT:"
        echo "$connection_output"
        return 1
    fi

    log_test "PASS" "$CURRENT_TEST: Basic connection functionality works"
    ((TESTS_PASSED++))
}

test_vpn_connector_parameter_handling() {
    start_test "VPN Connector Parameter Handling"

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test various parameter combinations that caused the regression
    local test_commands=(
        "list_profiles se"
        "list_profiles se detailed"
        "list_profiles dk"
        "connect se"
    )

    for cmd in "${test_commands[@]}"; do
        echo "Testing: $cmd"

        # Source the connector and test the function (if it exists)
        if grep -q "list_profiles" "$connector_script"; then
            # Test in isolation to catch unbound variable issues
            local test_output
            test_output=$(bash -c "
                set -euo pipefail
                source '$connector_script' 2>&1 || echo 'SOURCE_FAILED'
                if declare -f list_profiles >/dev/null; then
                    list_profiles ${cmd#list_profiles } 2>&1 || echo 'FUNCTION_FAILED'
                else
                    echo 'FUNCTION_NOT_FOUND'
                fi
            " 2>&1 || echo "BASH_FAILED")

            if echo "$test_output" | grep -q -E "(SOURCE_FAILED|FUNCTION_FAILED|BASH_FAILED|unbound variable)"; then
                log_test "FAIL" "$CURRENT_TEST: Parameter handling failed for '$cmd'"
                FAILED_TESTS+=("$CURRENT_TEST: parameter handling '$cmd'")
                ((TESTS_FAILED++))
                echo "ERROR OUTPUT for '$cmd':"
                echo "$test_output"
                return 1
            fi
        fi
    done

    log_test "PASS" "$CURRENT_TEST: Parameter handling works correctly"
    ((TESTS_PASSED++))
}

test_variable_consistency_across_scripts() {
    start_test "Variable Consistency Across Scripts"

    # Check for variable name inconsistencies that cause unbound variable errors
    local scripts=(
        "$PROJECT_DIR/src/vpn"
        "$PROJECT_DIR/src/vpn-connector"
        "$PROJECT_DIR/src/vpn-manager"
    )

    local inconsistencies_found=0

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            # Check for undefined variable references
            local undefined_vars
            # shellcheck disable=SC2016
            undefined_vars=$(grep -n '\\$[A-Z_][A-Z_]*' "$script" | grep -v '${.*}' | grep -v '"\\$' | grep -v "'\$" || true)

            if [[ -n "$undefined_vars" ]]; then
                echo "Potential undefined variables in $(basename "$script"):"
                echo "$undefined_vars"

                # Specifically check for the VPN_LOCATIONS vs LOCATIONS_DIR issue
                if grep -q 'VPN_LOCATIONS' "$script" && ! grep -q 'VPN_LOCATIONS=' "$script"; then
                    log_test "FAIL" "$CURRENT_TEST: VPN_LOCATIONS used but not defined in $(basename "$script")"
                    FAILED_TESTS+=("$CURRENT_TEST: VPN_LOCATIONS undefined in $(basename "$script")")
                    ((TESTS_FAILED++))
                    inconsistencies_found=1
                fi
            fi
        fi
    done

    if [[ $inconsistencies_found -eq 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Variable definitions are consistent"
        ((TESTS_PASSED++))
    fi
}

test_integration_library_compatibility() {
    start_test "Integration Library Compatibility"

    local integration_lib="$PROJECT_DIR/src/vpn-integration"
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Test that sourcing the integration library doesn't break other scripts
    if [[ -f "$integration_lib" && -f "$connector_script" ]]; then
        local test_output
        test_output=$(bash -c "
            # Test strict mode compatibility
            source '$integration_lib' 2>&1 || echo 'INTEGRATION_SOURCE_FAILED'
            source '$connector_script' 2>&1 || echo 'CONNECTOR_SOURCE_FAILED'
            echo 'SUCCESS'
        " 2>&1 || echo "BASH_FAILED")

        if echo "$test_output" | grep -q -E "(FAILED|unbound variable|command not found)"; then
            log_test "FAIL" "$CURRENT_TEST: Integration library breaks other scripts"
            FAILED_TESTS+=("$CURRENT_TEST: integration incompatibility")
            ((TESTS_FAILED++))
            echo "ERROR OUTPUT:"
            echo "$test_output"
            return 1
        fi

        log_test "PASS" "$CURRENT_TEST: Integration library is compatible"
        ((TESTS_PASSED++))
    else
        log_test "SKIP" "$CURRENT_TEST: Integration files not found"
    fi
}

test_profile_discovery_functionality() {
    start_test "Profile Discovery Functionality"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test that profile listing works without errors
    local list_output
    list_output=$(timeout 10s "$vpn_script" list 2>&1 || echo "LIST_FAILED")

    if echo "$list_output" | grep -q "LIST_FAILED"; then
        log_test "FAIL" "$CURRENT_TEST: Profile listing failed"
        FAILED_TESTS+=("$CURRENT_TEST: list command failure")
        ((TESTS_FAILED++))
        return 1
    fi

    if echo "$list_output" | grep -q -E "(unbound variable|command not found)"; then
        log_test "FAIL" "$CURRENT_TEST: Profile listing has script errors"
        FAILED_TESTS+=("$CURRENT_TEST: list command errors")
        ((TESTS_FAILED++))
        echo "ERROR OUTPUT:"
        echo "$list_output"
        return 1
    fi

    # Should show some profiles or appropriate message
    if echo "$list_output" | grep -q -E "(\.ovpn|\.conf|Available.*Profiles|No profiles found)"; then
        log_test "PASS" "$CURRENT_TEST: Profile discovery works correctly"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Profile discovery shows unexpected output"
        FAILED_TESTS+=("$CURRENT_TEST: unexpected list output")
        ((TESTS_FAILED++))
        echo "OUTPUT:"
        echo "$list_output"
    fi
}

test_connection_retry_logic() {
    start_test "Connection Retry Logic"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # Test connection retry without causing real connections
    # Use a non-existent profile to trigger retry logic safely
    local retry_output
    retry_output=$(timeout 20s "$vpn_script" connect nonexistent-profile-12345 2>&1 || echo "RETRY_TEST_COMPLETED")

    # Should not crash on retry attempts
    if echo "$retry_output" | grep -q -E "(unbound variable|command not found)"; then
        log_test "FAIL" "$CURRENT_TEST: Retry logic has script errors"
        FAILED_TESTS+=("$CURRENT_TEST: retry logic errors")
        ((TESTS_FAILED++))
        echo "ERROR OUTPUT:"
        echo "$retry_output"
        return 1
    fi

    # Should show retry attempts or profile not found message
    if echo "$retry_output" | grep -q -E "(Attempt [0-9]|not found|Failed to connect|No profile)"; then
        log_test "PASS" "$CURRENT_TEST: Retry logic functions correctly"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Retry logic shows unexpected behavior"
        FAILED_TESTS+=("$CURRENT_TEST: retry logic unexpected behavior")
        ((TESTS_FAILED++))
        echo "OUTPUT:"
        echo "$retry_output"
    fi
}

test_cleanup_doesnt_interfere_with_connections() {
    start_test "Cleanup Doesn't Interfere With Connections"

    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Check that mid-attempt cleanup isn't too aggressive
    if grep -q "Mid-attempt.*cleanup" "$connector_script"; then
        # Look for cleanup during connection attempts that might interfere
        local cleanup_lines
        cleanup_lines=$(grep -n -A5 -B5 "Mid-attempt.*cleanup" "$connector_script" || true)

        echo "Found mid-attempt cleanup:"
        echo "$cleanup_lines"

        # Check if cleanup happens without proper process validation
        if echo "$cleanup_lines" | grep -q "cleanup" && ! echo "$cleanup_lines" | grep -q -E "(validate|check.*process|if.*process)"; then
            log_test "FAIL" "$CURRENT_TEST: Mid-attempt cleanup may interfere with connections"
            FAILED_TESTS+=("$CURRENT_TEST: cleanup interference risk")
            ((TESTS_FAILED++))
            return 1
        fi
    fi

    log_test "PASS" "$CURRENT_TEST: Cleanup logic appears safe"
    ((TESTS_PASSED++))
}

# CRITICAL: Connection acceptance test - must pass for any PR merge
test_connection_acceptance_criteria() {
    start_test "Connection Acceptance Criteria (CRITICAL)"

    local vpn_script="$PROJECT_DIR/src/vpn"

    # This test defines the minimum acceptable behavior for VPN connections
    echo "Running critical acceptance test..."

    local start_time
    start_time=$(date +%s)

    # Test basic connection command doesn't fail immediately
    local connection_result
    connection_result=$(timeout 10s "$vpn_script" connect se 2>&1 || echo "CONNECTION_COMMAND_FAILED")

    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - start_time))

    # CRITICAL CHECKS - ALL MUST PASS
    local critical_failures=0

    # 1. Command must not fail with script errors
    if echo "$connection_result" | grep -q "CONNECTION_COMMAND_FAILED"; then
        echo "❌ CRITICAL: Connection command failed completely"
        critical_failures=$((critical_failures + 1))
    fi

    # 2. Must not have unbound variable errors
    if echo "$connection_result" | grep -q "unbound variable"; then
        echo "❌ CRITICAL: Unbound variable errors detected"
        critical_failures=$((critical_failures + 1))
    fi

    # 3. Must not crash immediately (should take at least 5 seconds for real attempt)
    if [[ $duration -lt 5 ]]; then
        echo "❌ CRITICAL: Connection attempt ended too quickly ($duration seconds) - likely crashed"
        critical_failures=$((critical_failures + 1))
    fi

    # 4. Should attempt profile selection
    if ! echo "$connection_result" | grep -q -E "(Selected profile|profile.*se|Finding.*profile)"; then
        echo "❌ CRITICAL: No profile selection attempted"
        critical_failures=$((critical_failures + 1))
    fi

    # 5. Should not show bash errors
    if echo "$connection_result" | grep -q -E "(line [0-9]+:|command not found|Permission denied)"; then
        echo "❌ CRITICAL: Bash script errors detected"
        critical_failures=$((critical_failures + 1))
    fi

    if [[ $critical_failures -gt 0 ]]; then
        log_test "FAIL" "$CURRENT_TEST: $critical_failures critical failures - BLOCK MERGE"
        FAILED_TESTS+=("$CURRENT_TEST: CRITICAL - $critical_failures failures")
        ((TESTS_FAILED++))
        echo ""
        echo "🚨 MERGE BLOCKED: Connection functionality is broken"
        echo "Full output:"
        echo "$connection_result"
        return 1
    fi

    log_test "PASS" "$CURRENT_TEST: All critical acceptance criteria met"
    ((TESTS_PASSED++))
    echo "✅ Connection acceptance criteria PASSED"
}

# Run all connection regression tests
run_connection_regression_tests() {
    log_test "INFO" "Starting Connection Regression Tests (CRITICAL FOR MERGE)"
    echo "=================================================================="
    echo "    CONNECTION REGRESSION PREVENTION TESTS"
    echo "=================================================================="
    echo "These tests MUST PASS before any changes can be merged."
    echo "If any test fails, the connection functionality is broken."
    echo ""

    # Run critical acceptance test first
    test_connection_acceptance_criteria

    # Run supporting regression tests
    test_vpn_connect_basic_functionality
    test_vpn_connector_parameter_handling
    test_variable_consistency_across_scripts
    test_integration_library_compatibility
    test_profile_discovery_functionality
    test_connection_retry_logic
    test_cleanup_doesnt_interfere_with_connections

    echo ""
    echo "=================================================================="
    echo "CONNECTION REGRESSION TESTS COMPLETE"
    echo "=================================================================="

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo "🚨 MERGE BLOCKED: Connection functionality issues detected"
        echo "These failures indicate broken VPN connection capability."
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        echo ""
        echo "Action required: Fix all connection issues before merge"
        return 1
    else
        echo "✅ All connection regression tests PASSED"
        echo "Connection functionality is preserved."
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_connection_regression_tests
    show_test_summary
fi

#!/bin/bash
# ABOUTME: Tests to ensure proper separation between emergency reset and regular cleanup
# ABOUTME: Prevents confusion and ensures users know which command disrupts networking

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
source "$TEST_DIR/test_framework.sh"

test_emergency_reset_command_exists() {
    start_test "Emergency reset command exists and is documented"

    local help_output
    help_output=$("$PROJECT_DIR/src/vpn" help 2>&1)

    if echo "$help_output" | grep -q "emergency-reset.*Emergency network reset.*restarts NetworkManager"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset documented in help"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset not properly documented"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_vs_emergency_help_distinction() {
    start_test "Help clearly distinguishes between cleanup and emergency reset"

    local help_output
    help_output=$("$PROJECT_DIR/src/vpn" help 2>&1)

    # Check cleanup is marked as safe
    local cleanup_safe=false
    local emergency_warning=false

    if echo "$help_output" | grep -q "cleanup.*safe"; then
        cleanup_safe=true
    fi

    if echo "$help_output" | grep -q "emergency-reset.*restarts NetworkManager"; then
        emergency_warning=true
    fi

    if [[ "$cleanup_safe" == true && "$emergency_warning" == true ]]; then
        log_test "PASS" "$CURRENT_TEST: Help clearly distinguishes safe cleanup from disruptive emergency reset"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Help doesn't clearly distinguish commands (cleanup_safe: $cleanup_safe, emergency_warning: $emergency_warning)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_emergency_reset_warns_user() {
    start_test "Emergency reset command warns user about network disruption"

    # We'll test the warning without actually restarting NetworkManager
    local emergency_output
    emergency_output=$("$PROJECT_DIR/src/vpn-manager" emergency-reset 2>&1 || true)

    if echo "$emergency_output" | grep -q "EMERGENCY NETWORK RESET.*disrupt internet temporarily"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset properly warns about disruption"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset doesn't warn about disruption: $emergency_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_regular_cleanup_no_warning() {
    start_test "Regular cleanup doesn't warn about network disruption"

    local cleanup_output
    cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1)

    # Should NOT contain emergency or disruption warnings
    if ! echo "$cleanup_output" | grep -iq "emergency\|disrupt\|restart.*network"; then
        log_test "PASS" "$CURRENT_TEST: Regular cleanup doesn't warn about disruption"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Regular cleanup contains disruption warnings: $cleanup_output"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_emergency_reset_includes_regular_cleanup() {
    start_test "Emergency reset includes regular cleanup functionality"

    # Check that emergency_network_reset function calls full_cleanup
    if grep -A 10 "^emergency_network_reset()" "$PROJECT_DIR/src/vpn-manager" | grep -q "full_cleanup"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset includes regular cleanup"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset doesn't include regular cleanup"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_emergency_reset_has_networkmanager_restart() {
    start_test "Emergency reset actually contains NetworkManager restart code"

    # Check that emergency_network_reset function contains NetworkManager restart
    local emergency_function
    emergency_function=$(grep -A 20 "^emergency_network_reset()" "$PROJECT_DIR/src/vpn-manager")

    if echo "$emergency_function" | grep -q "sv restart NetworkManager\|systemctl restart NetworkManager\|service NetworkManager restart"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset contains NetworkManager restart"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset doesn't contain NetworkManager restart"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_cleanup_marked_safe_in_output() {
    start_test "Cleanup output explicitly mentions it's safe (NetworkManager intact)"

    local cleanup_output
    cleanup_output=$("$PROJECT_DIR/src/vpn" cleanup 2>&1)

    if echo "$cleanup_output" | grep -q "NetworkManager left intact"; then
        log_test "PASS" "$CURRENT_TEST: Cleanup output mentions NetworkManager is left intact"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Cleanup output doesn't mention NetworkManager safety"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_emergency_reset_accessible_via_main_script() {
    start_test "Emergency reset is accessible via main VPN script"

    # Test that the command routes correctly (we'll catch the warning before it executes)
    local emergency_result
    emergency_result=$("$PROJECT_DIR/src/vpn" emergency-reset 2>&1 || true)

    if echo "$emergency_result" | grep -q "EMERGENCY NETWORK RESET"; then
        log_test "PASS" "$CURRENT_TEST: Emergency reset accessible via main script"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Emergency reset not accessible or not working: $emergency_result"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_command_separation_in_code() {
    start_test "Regular cleanup and emergency reset are separate functions"

    # Check that full_cleanup and emergency_network_reset are separate functions
    local cleanup_func_exists emergency_func_exists

    cleanup_func_exists=$(grep -c "^full_cleanup()" "$PROJECT_DIR/src/vpn-manager")
    emergency_func_exists=$(grep -c "^emergency_network_reset()" "$PROJECT_DIR/src/vpn-manager")

    if [[ $cleanup_func_exists -eq 1 && $emergency_func_exists -eq 1 ]]; then
        log_test "PASS" "$CURRENT_TEST: Cleanup and emergency reset are separate functions"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Functions not properly separated (cleanup: $cleanup_func_exists, emergency: $emergency_func_exists)"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

test_no_accidental_emergency_calls() {
    start_test "Regular VPN commands don't accidentally call emergency functions"

    # Check that regular commands (kill, cleanup) don't call emergency_network_reset
    local kill_section cleanup_section

    kill_section=$(sed -n '/^kill_all_vpn()/,/^}/p' "$PROJECT_DIR/src/vpn-manager")
    cleanup_section=$(sed -n '/^full_cleanup()/,/^emergency_network_reset()/p' "$PROJECT_DIR/src/vpn-manager")

    if ! echo "$kill_section" | grep -q "emergency_network_reset" && ! echo "$cleanup_section" | grep -q "emergency_network_reset"; then
        log_test "PASS" "$CURRENT_TEST: Regular commands don't call emergency functions"
        ((TESTS_PASSED++))
    else
        log_test "FAIL" "$CURRENT_TEST: Regular commands may accidentally call emergency functions"
        FAILED_TESTS+=("$CURRENT_TEST")
        ((TESTS_FAILED++))
    fi
}

# Run all emergency reset vs cleanup tests
main() {
    log_test "INFO" "Starting Emergency Reset vs Cleanup Tests"
    echo "================================================="
    echo "      EMERGENCY RESET VS CLEANUP TESTS"
    echo "================================================="

    test_emergency_reset_command_exists
    test_cleanup_vs_emergency_help_distinction
    test_emergency_reset_warns_user
    test_regular_cleanup_no_warning
    test_emergency_reset_includes_regular_cleanup
    test_emergency_reset_has_networkmanager_restart
    test_cleanup_marked_safe_in_output
    test_emergency_reset_accessible_via_main_script
    test_command_separation_in_code
    test_no_accidental_emergency_calls

    show_test_summary

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

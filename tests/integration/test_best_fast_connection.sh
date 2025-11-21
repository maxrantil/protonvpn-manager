#!/bin/bash
# ABOUTME: Integration tests for vpn best and vpn fast connection modes
# ABOUTME: Tests that best_server_connect() actually connects to VPN, not just simulates

# Source the test framework
TEST_DIR="$(dirname "$(realpath "$0")")"
# shellcheck source=tests/test_framework.sh
source "$TEST_DIR/../test_framework.sh"

test_vpn_best_connects() {
    start_test "vpn best actually connects to VPN"

    setup_test_env

    # First ensure we're disconnected
    "$PROJECT_DIR/src/vpn" disconnect > /dev/null 2>&1 || true

    # Mock best-vpn-profile to return a known test profile
    local mock_best_profile="$TEST_TEMP_DIR/best-vpn-profile"
    cat > "$mock_best_profile" << 'EOF'
#!/bin/bash
# Mock best-vpn-profile that returns a test profile
echo "se-test"
exit 0
EOF
    chmod +x "$mock_best_profile"

    # Mock connect_to_profile to track if it was called
    local connection_tracker="$TEST_TEMP_DIR/connection_tracker"

    # Source vpn-connector to test best_server_connect() function directly
    local connector_script="$PROJECT_DIR/src/vpn-connector"

    # Call best_server_connect with "full" mode
    local output
    output=$(VPN_DIR="$PROJECT_DIR/src" bash -c "
        source '$connector_script'
        # Override best-vpn-profile command
        best-vpn-profile() {
            echo 'se-test'
            return 0
        }
        # Track if connect_to_profile is called
        original_connect_to_profile=\$(declare -f connect_to_profile)
        connect_to_profile() {
            echo 'connect_to_profile_called' >> '$connection_tracker'
            echo 'Connected to: \$1' >> '$connection_tracker'
            return 0
        }
        best_server_connect 'full' ''
    " 2>&1)

    # Check that connect_to_profile was called
    if [[ -f "$connection_tracker" ]]; then
        local tracker_content
        tracker_content=$(cat "$connection_tracker")

        if echo "$tracker_content" | grep -q "connect_to_profile_called"; then
            log_test "PASS" "$CURRENT_TEST: connect_to_profile was called"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "FAIL" "$CURRENT_TEST: connect_to_profile was NOT called (simulation only)"
            FAILED_TESTS+=("$CURRENT_TEST: Function only simulated connection")
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: connect_to_profile was NOT called - no tracker file"
        FAILED_TESTS+=("$CURRENT_TEST: best_server_connect didn't call connect_to_profile")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Check output doesn't contain "simulation" messaging
    if echo "$output" | grep -qi "simulation"; then
        log_test "FAIL" "$CURRENT_TEST: Output still contains 'simulation' stub messaging"
        FAILED_TESTS+=("$CURRENT_TEST: Stub code not removed")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_test "PASS" "$CURRENT_TEST: No simulation messaging in output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    cleanup_test_env
}

test_vpn_fast_connects() {
    start_test "vpn fast (cached mode) actually connects to VPN"

    setup_test_env

    # Mock get_cached_best_profile to return a valid profile
    local connection_tracker="$TEST_TEMP_DIR/fast_connection_tracker"

    local output
    output=$(VPN_DIR="$PROJECT_DIR/src" bash -c "
        source '$PROJECT_DIR/src/vpn-connector'
        # Mock get_cached_best_profile to succeed
        get_cached_best_profile() {
            echo 'dk-test'
            return 0
        }
        # Track if connect_to_profile is called
        connect_to_profile() {
            echo 'connect_to_profile_called' >> '$connection_tracker'
            echo 'Connected to: \$1' >> '$connection_tracker'
            return 0
        }
        best_server_connect 'fast' ''
    " 2>&1)

    # Check that connect_to_profile was called
    if [[ -f "$connection_tracker" ]]; then
        local tracker_content
        tracker_content=$(cat "$connection_tracker")

        if echo "$tracker_content" | grep -q "connect_to_profile_called"; then
            log_test "PASS" "$CURRENT_TEST: connect_to_profile was called for fast mode"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "FAIL" "$CURRENT_TEST: Fast mode only simulated connection"
            FAILED_TESTS+=("$CURRENT_TEST: Fast mode didn't connect")
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "FAIL" "$CURRENT_TEST: Fast mode didn't call connect_to_profile"
        FAILED_TESTS+=("$CURRENT_TEST: fast mode simulation only")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Check output doesn't contain "simulation" messaging
    if echo "$output" | grep -qi "simulation"; then
        log_test "FAIL" "$CURRENT_TEST: Fast mode still has simulation messaging"
        FAILED_TESTS+=("$CURRENT_TEST: Fast mode stub code not removed")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_test "PASS" "$CURRENT_TEST: No simulation messaging in fast mode"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    cleanup_test_env
}

test_vpn_best_error_handling() {
    start_test "vpn best handles errors when profile not found"

    setup_test_env

    local output
    local exit_code
    output=$(VPN_DIR="$PROJECT_DIR/src" bash -c "
        source '$PROJECT_DIR/src/vpn-connector'
        # Mock best-vpn-profile to fail
        best-vpn-profile() {
            return 1
        }
        best_server_connect 'full' ''
    " 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -ne 0 ]]; then
        log_test "PASS" "$CURRENT_TEST: Returns non-zero on failure"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "FAIL" "$CURRENT_TEST: Should return non-zero when profile not found"
        FAILED_TESTS+=("$CURRENT_TEST: Missing error handling")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Run all tests
test_vpn_best_connects
test_vpn_fast_connects
test_vpn_best_error_handling

# Print summary
echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed:${NC}"
    for failed_test in "${FAILED_TESTS[@]}"; do
        echo "  - $failed_test"
    done
    exit 1
fi

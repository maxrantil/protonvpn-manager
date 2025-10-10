#!/bin/bash
# ABOUTME: Phase 6.2 Status Bar Integration comprehensive TDD test suite
# ABOUTME: Tests multi-window manager status bar integration with signal handling and content formatting

# Source test framework
source "$(dirname "$0")/test_framework.sh"

# Test configuration
VPN_DIR="$(dirname "$(dirname "$(realpath "$0")")")/src"

# Test initialization
echo "=================================="
echo "Phase 6.2 Status Bar Integration Tests"
echo "Testing multi-window manager status bar system"
echo "Expected Status: ALL TESTS SHOULD FAIL (RED PHASE)"
echo "=================================="

setup_test_env

# =============================================================================
# CYCLE 1: Window Manager Detection Tests (8 tests)
# These tests WILL FAIL - vpn-statusbar script doesn't exist yet
# =============================================================================

start_test "vpn_statusbar_script_exists"
assert_file_exists "$VPN_DIR/vpn-statusbar" "vpn-statusbar script should exist"

start_test "vpn_statusbar_executable"
assert_command_succeeds "test -x '$VPN_DIR/vpn-statusbar'" "vpn-statusbar should be executable"

start_test "dwmblocks_detection"
# This will fail because vpn-statusbar doesn't exist
# Mock dwmblocks process
mock_command "pgrep" "12345"
result=$("$VPN_DIR/vpn-statusbar" --detect-wm 2> /dev/null)
assert_contains "$result" "dwmblocks" "Should detect dwmblocks window manager"

start_test "polybar_detection"
# This will fail because vpn-statusbar doesn't exist
# Mock polybar process
mock_command "pgrep" "12346"
result=$("$VPN_DIR/vpn-statusbar" --detect-wm --force-polybar 2> /dev/null)
assert_contains "$result" "polybar" "Should detect polybar window manager"

start_test "waybar_detection"
# This will fail because vpn-statusbar doesn't exist
# Mock waybar process
mock_command "pgrep" "12347"
result=$("$VPN_DIR/vpn-statusbar" --detect-wm --force-waybar 2> /dev/null)
assert_contains "$result" "waybar" "Should detect waybar window manager"

start_test "i3status_detection"
# This will fail because vpn-statusbar doesn't exist
# Mock i3status process
mock_command "pgrep" "12348"
result=$("$VPN_DIR/vpn-statusbar" --detect-wm --force-i3status 2> /dev/null)
assert_contains "$result" "i3status" "Should detect i3status window manager"

start_test "multiple_status_bar_priority"
# This will fail because vpn-statusbar doesn't exist
# Mock multiple processes - should prioritize based on detection order
mock_command "pgrep" "12345
12346"
result=$("$VPN_DIR/vpn-statusbar" --detect-wm 2> /dev/null)
assert_contains "$result" "dwmblocks\|polybar" "Should detect and prioritize status bar systems"

start_test "no_status_bar_graceful_handling"
# This will fail because vpn-statusbar doesn't exist
# Mock no status bar processes
mock_command "pgrep" ""
"$VPN_DIR/vpn-statusbar" update "connected" "test" "1.1.1.1" 2> /dev/null
assert_equals "0" "$?" "Should handle absence of status bar systems gracefully"

# =============================================================================
# CYCLE 2: Signal Management Tests (6 tests)
# These tests WILL FAIL - signal handling doesn't exist yet
# =============================================================================

start_test "dwmblocks_signal_sending"
# This will fail because vpn-statusbar doesn't exist
# Mock dwmblocks process
mock_command "pgrep" "12345"
mock_command "pkill" ""
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --dry-run 2> /dev/null)
assert_contains "$result" "pkill.*RTMIN+4.*dwmblocks" "Should send RTMIN+4 signal to dwmblocks"

start_test "signal_debouncing"
# This will fail because vpn-statusbar doesn't exist
# Test rapid status updates don't flood signals
start_time=$(date +%s)
for i in {1..5}; do
    "$VPN_DIR/vpn-statusbar" update "connecting" "test-$i" "0.0.0.0" --quiet 2> /dev/null
done
end_time=$(date +%s)
duration=$((end_time - start_time))
assert_command_succeeds "test $duration -ge 2" "Should debounce rapid status updates"

start_test "signal_failure_graceful_handling"
# This will fail because vpn-statusbar doesn't exist
# Mock pkill failure
mock_command "pkill" "" "1" # Exit code 1 (failure)
"$VPN_DIR/vpn-statusbar" update "connected" "test" "1.1.1.1" 2> /dev/null
assert_equals "0" "$?" "Should handle signal sending failures gracefully"

start_test "signal_timing_validation"
# This will fail because vpn-statusbar doesn't exist
# Test that signals aren't sent too frequently
"$VPN_DIR/vpn-statusbar" update "connected" "test1" "1.1.1.1" 2> /dev/null
"$VPN_DIR/vpn-statusbar" update "connected" "test2" "1.1.1.2" 2> /dev/null
result=$("$VPN_DIR/vpn-statusbar" --get-last-signal-time 2> /dev/null)
assert_not_equals "" "$result" "Should track signal timing to prevent flooding"

start_test "concurrent_signal_handling"
# This will fail because vpn-statusbar doesn't exist
# Test concurrent status updates don't conflict
"$VPN_DIR/vpn-statusbar" update "connected" "test1" "1.1.1.1" &
"$VPN_DIR/vpn-statusbar" update "disconnected" "" "" &
wait
assert_equals "0" "$?" "Should handle concurrent status updates safely"

start_test "signal_queue_management"
# This will fail because vpn-statusbar doesn't exist
# Test signal queueing during rapid changes
for i in {1..10}; do
    "$VPN_DIR/vpn-statusbar" update "state$i" "profile$i" "1.1.1.$i" --queue 2> /dev/null &
done
wait
result=$("$VPN_DIR/vpn-statusbar" --check-queue-health 2> /dev/null)
assert_contains "$result" "healthy\|processed" "Should manage signal queue properly"

# =============================================================================
# CYCLE 3: Status Content Formatting Tests (7 tests)
# These tests WILL FAIL - content formatting doesn't exist yet
# =============================================================================

start_test "connected_status_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "192.168.1.100" --show-format 2> /dev/null)
assert_contains "$result" "se-65.*192.168.1.100" "Should format connected status with profile and IP"

start_test "disconnected_status_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "disconnected" "" "" --show-format 2> /dev/null)
assert_contains "$result" "disconnected\|offline" "Should format disconnected status appropriately"

start_test "connecting_status_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connecting" "dk-23" "" --show-format 2> /dev/null)
assert_contains "$result" "connecting.*dk-23" "Should format connecting status with profile name"

start_test "status_content_length_limits"
# This will fail because vpn-statusbar doesn't exist
long_profile="very-long-profile-name-that-exceeds-status-bar-width-limits"
result=$("$VPN_DIR/vpn-statusbar" update "connected" "$long_profile" "1.1.1.1" --show-format 2> /dev/null)
assert_command_succeeds "test ${#result} -le 50" "Should limit status content length for status bar display"

start_test "country_code_extraction"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --show-format 2> /dev/null)
assert_contains "$result" "SE\|🇸🇪" "Should extract and format country codes"

start_test "ip_address_privacy_option"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "192.168.1.100" --privacy-mode --show-format 2> /dev/null)
assert_not_contains "$result" "192.168.1.100" "Should support privacy mode hiding IP addresses"

start_test "status_icons_unicode_support"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --show-format --unicode 2> /dev/null)
assert_contains "$result" "🔒\|🌐\|✅" "Should support unicode icons in status"

# =============================================================================
# CYCLE 4: Multi-Window Manager Support Tests (8 tests)
# These tests WILL FAIL - multi-WM support doesn't exist yet
# =============================================================================

start_test "dwmblocks_specific_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --format-for=dwmblocks --show-format 2> /dev/null)
assert_contains "$result" "^c#" "Should use dwmblocks-specific color formatting"

start_test "polybar_specific_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --format-for=polybar --show-format 2> /dev/null)
assert_contains "$result" "%{F#" "Should use polybar-specific color formatting"

start_test "waybar_json_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --format-for=waybar --show-format 2> /dev/null)
assert_contains "$result" "\"text\":" "Should use waybar JSON formatting"

start_test "i3status_plain_formatting"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --format-for=i3status --show-format 2> /dev/null)
assert_not_contains "$result" "%{F#\|^c#\|\"text\":" "Should use plain text for i3status"

start_test "automatic_format_detection"
# This will fail because vpn-statusbar doesn't exist
mock_command "pgrep" "12345" # Mock dwmblocks
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --auto-format --show-format 2> /dev/null)
assert_contains "$result" "^c#" "Should auto-detect and use appropriate formatting"

start_test "fallback_format_handling"
# This will fail because vpn-statusbar doesn't exist
mock_command "pgrep" "" # No status bars detected
result=$("$VPN_DIR/vpn-statusbar" update "connected" "se-65" "1.1.1.1" --show-format 2> /dev/null)
assert_not_contains "$result" "%{F#\|^c#\|\"text\":" "Should use plain format when no status bar detected"

start_test "custom_status_bar_support"
# This will fail because vpn-statusbar doesn't exist
result=$("$VPN_DIR/vpn-statusbar" --add-custom-statusbar "custom-bar" "custom-signal" --test 2> /dev/null)
assert_contains "$result" "registered\|added" "Should support adding custom status bar systems"

start_test "status_bar_configuration_file"
# This will fail because configuration doesn't exist
assert_file_exists "$PROJECT_DIR/config/statusbar.conf" "Should have status bar configuration file"

# =============================================================================
# CYCLE 5: Integration with Existing Scripts Tests (6 tests)
# These tests WILL FAIL - integration doesn't exist yet
# =============================================================================

start_test "vpn_connector_statusbar_integration"
# This will fail because vpn-connector doesn't use vpn-statusbar yet
result=$(grep -c "vpn-statusbar\|update_statusbar" "$VPN_DIR/vpn-connector" 2> /dev/null || echo "0")
assert_not_equals "0" "$result" "vpn-connector should integrate with status bar system"

start_test "vpn_manager_statusbar_integration"
# This will fail because vpn-manager doesn't use vpn-statusbar yet
result=$(grep -c "vpn-statusbar\|update_statusbar" "$VPN_DIR/vpn-manager" 2> /dev/null || echo "0")
assert_not_equals "0" "$result" "vpn-manager should integrate with status bar system"

start_test "status_bar_integration_library_function"
# This will fail because vpn-integration doesn't have status bar functions
result=$(grep -c "update_statusbar\|statusbar_update" "$VPN_DIR/vpn-integration" 2> /dev/null || echo "0")
assert_not_equals "0" "$result" "Integration library should provide status bar functions"

start_test "legacy_dwmblocks_signal_removal"
# This will fail because legacy pkill calls still exist
legacy_count=$(grep -r "pkill.*RTMIN\|pkill.*dwmblocks" "$VPN_DIR"/*.sh "$VPN_DIR"/vpn-* 2> /dev/null | grep -v "vpn-statusbar" | wc -l || echo "0")
assert_equals "0" "$legacy_count" "Should remove legacy dwmblocks signal calls"

start_test "status_consistency_across_scripts"
# This will fail because status updates aren't centralized yet
status_updates=$(grep -r "Connected\|Disconnected\|Connecting" "$VPN_DIR"/vpn-* 2> /dev/null | grep -v echo | wc -l || echo "0")
assert_not_equals "0" "$status_updates" "Should have consistent status update patterns"

start_test "status_state_synchronization"
# This will fail because state sync doesn't exist
result=$("$VPN_DIR/vpn-statusbar" --sync-with-vpn-state 2> /dev/null)
assert_contains "$result" "synchronized\|current" "Should synchronize status bar with actual VPN state"

# =============================================================================
# End-to-End Status Bar Tests (5 tests)
# These tests WILL FAIL - full integration doesn't exist yet
# =============================================================================

start_test "end_to_end_connection_status_flow"
# This will fail because full integration doesn't exist
# Mock connection process
result=$("$VPN_DIR/vpn" connect test-profile --dry-run 2>&1 | grep -i "status\|statusbar" || echo "")
assert_not_equals "" "$result" "Connection process should update status bar"

start_test "end_to_end_disconnection_status_flow"
# This will fail because full integration doesn't exist
result=$("$VPN_DIR/vpn" disconnect --dry-run 2>&1 | grep -i "status\|statusbar" || echo "")
assert_not_equals "" "$result" "Disconnection process should update status bar"

start_test "status_bar_health_monitoring"
# This will fail because health monitoring doesn't exist
"$VPN_DIR/vpn-statusbar" --health-check 2> /dev/null
assert_equals "0" "$?" "Status bar system should pass health check"

start_test "status_bar_reset_function"
# This will fail because reset function doesn't exist
"$VPN_DIR/vpn-statusbar" --reset 2> /dev/null
assert_equals "0" "$?" "Should be able to reset status bar to default state"

start_test "status_bar_configuration_validation"
# This will fail because configuration validation doesn't exist
"$VPN_DIR/vpn-statusbar" --validate-config 2> /dev/null
assert_equals "0" "$?" "Should validate status bar configuration"

cleanup_test_env

echo
echo "=================================="
echo "Phase 6.2 Status Bar Integration Test Results"
echo "Expected: ALL TESTS FAILED (RED PHASE)"
echo "Next Step: Implement vpn-statusbar script to make tests pass (GREEN PHASE)"
echo "=================================="

show_test_summary

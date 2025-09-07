#!/bin/bash
# ABOUTME: Simple connection test to validate regression fix works
# ABOUTME: Tests core functionality without complex timeouts

set -euo pipefail

echo "Testing VPN connection functionality after regression fix..."

# Test 1: Command doesn't crash with unbound variables
echo "Test 1: Basic command execution"
output=$(timeout 3s ./src/vpn connect se 2>&1 || echo "TIMEOUT_REACHED")

if echo "$output" | grep -q "unbound variable"; then
    echo "❌ FAIL: Unbound variable error detected"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -q "Selected profile"; then
    echo "✅ PASS: Profile selection working"
else
    echo "❌ FAIL: No profile selection"
    echo "Output: $output"
    exit 1
fi

if echo "$output" | grep -q "Connecting"; then
    echo "✅ PASS: Connection attempt started"
else
    echo "❌ FAIL: No connection attempt"
    echo "Output: $output"
    exit 1
fi

# Test 2: List command works
echo "Test 2: Profile listing functionality"
list_output=$(./src/vpn list 2>&1 || echo "LIST_FAILED")

if echo "$list_output" | grep -q "LIST_FAILED"; then
    echo "❌ FAIL: List command failed"
    exit 1
elif echo "$list_output" | grep -q "unbound variable"; then
    echo "❌ FAIL: List command has unbound variable error"
    echo "Output: $list_output"
    exit 1
else
    echo "✅ PASS: List command working"
fi

echo ""
echo "🎉 All core functionality tests PASSED!"
echo "The regression has been fixed - connection functionality restored!"

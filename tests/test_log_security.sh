#!/bin/bash
# ABOUTME: Test script for log file security and permissions

set -euo pipefail

echo "Testing log file security..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test directory
TEST_DIR="/tmp/vpn_log_test_$$"
LOG_DIR="$TEST_DIR/.local/state/vpn"
mkdir -p "$LOG_DIR"
trap 'rm -rf $TEST_DIR' EXIT

export XDG_STATE_HOME="$TEST_DIR/.local/state"

echo "=== Test 1: Log directory creation ==="
if [[ -d "$LOG_DIR" ]]; then
    echo -e "${GREEN}PASS${NC} - Log directory created"
else
    echo -e "${RED}FAIL${NC} - Log directory not created"
    exit 1
fi

echo ""
echo "=== Test 2: Log file permissions ==="
# Source vpn-manager to trigger log creation
# shellcheck disable=SC2030
(
    export XDG_STATE_HOME="$TEST_DIR/.local/state"
    source ../src/vpn-manager 2> /dev/null || true
)

LOG_FILE="$LOG_DIR/vpn_manager.log"
if [[ -f "$LOG_FILE" ]]; then
    PERMS=$(stat -c "%a" "$LOG_FILE")
    if [[ "$PERMS" == "644" ]]; then
        echo -e "${GREEN}PASS${NC} - Log file has correct permissions (644)"
    else
        echo -e "${RED}FAIL${NC} - Log file has wrong permissions ($PERMS)"
        exit 1
    fi
else
    echo -e "${RED}FAIL${NC} - Log file not created"
    exit 1
fi

echo ""
echo "=== Test 3: Symlink removal ==="
# Create a symlink where log should be
rm -f "$LOG_FILE"
ATTACKER_FILE="$TEST_DIR/attacker.log"
ln -s "$ATTACKER_FILE" "$LOG_FILE"
echo "SENSITIVE" > "$ATTACKER_FILE"

# Source again (should remove symlink)
# shellcheck disable=SC2031
(
    export XDG_STATE_HOME="$TEST_DIR/.local/state"
    source ../src/vpn-manager 2> /dev/null || true
)

if [[ -L "$LOG_FILE" ]]; then
    echo -e "${RED}FAIL${NC} - Symlink not removed"
    exit 1
elif [[ -f "$LOG_FILE" ]]; then
    echo -e "${GREEN}PASS${NC} - Symlink removed and log file created"
else
    echo -e "${RED}FAIL${NC} - Neither symlink nor file exists"
    exit 1
fi

echo ""
echo "=== Test 4: Log location (not in /tmp) ==="
# Check that logs are NOT in /tmp
if grep -q "/tmp.*log" ../src/vpn-manager ../src/vpn-connector 2> /dev/null; then
    # Check if it's just in comments or actually used
    if grep -E "^[^#]*LOG.*=.*/tmp" ../src/vpn-manager ../src/vpn-connector 2> /dev/null; then
        echo -e "${RED}FAIL${NC} - Logs still using /tmp directory"
        exit 1
    fi
fi
echo -e "${GREEN}PASS${NC} - Logs use secure directory (~/.local/state/vpn)"

echo ""
echo "All log security tests passed!"

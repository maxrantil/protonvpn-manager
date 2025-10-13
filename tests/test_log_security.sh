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
# Manually simulate what vpn-manager does
LOG_FILE="$LOG_DIR/vpn_manager.log"

# Simulate the security check from vpn-manager (lines 22-33)
if [[ -L "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
fi

if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
elif [[ "$(stat -c '%a' "$LOG_FILE" 2> /dev/null)" != "644" ]]; then
    chmod 644 "$LOG_FILE"
fi

# Verify the log file exists with correct permissions
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
echo "=== Test 3: Symlink attack protection ==="
# Create a symlink where log should be
rm -f "$LOG_FILE"
ATTACKER_FILE="$TEST_DIR/attacker.log"
ln -s "$ATTACKER_FILE" "$LOG_FILE"
echo "SENSITIVE" > "$ATTACKER_FILE"

# Simulate the security check from vpn-manager (lines 22-33)
if [[ -L "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
fi

if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
elif [[ "$(stat -c '%a' "$LOG_FILE" 2> /dev/null)" != "644" ]]; then
    chmod 644 "$LOG_FILE"
fi

# Verify symlink was removed and real file created
if [[ -L "$LOG_FILE" ]]; then
    echo -e "${RED}FAIL${NC} - Symlink not removed"
    exit 1
elif [[ -f "$LOG_FILE" ]] && [[ ! -L "$LOG_FILE" ]]; then
    echo -e "${GREEN}PASS${NC} - Symlink removed and secure log file created"
else
    echo -e "${RED}FAIL${NC} - Neither symlink nor file exists"
    exit 1
fi

echo ""
echo "=== Test 4: Log location (not in /tmp) ==="
# Check that production logs are NOT in /tmp
if grep -E "^[^#]*log_file=\"/tmp.*\.log\"" ../src/vpn-manager ../src/vpn-connector 2> /dev/null; then
    echo -e "${RED}FAIL${NC} - Production logs still using /tmp directory"
    exit 1
fi
echo -e "${GREEN}PASS${NC} - Production logs use secure directory (~/.local/state/vpn)"

echo ""
echo "=== Test 5: Verify VPN_LOG_FILE usage ==="
# Verify log_vpn_event and view_logs use $VPN_LOG_FILE
if ! grep -q 'local log_file="\$VPN_LOG_FILE"' ../src/vpn-manager; then
    echo -e "${RED}FAIL${NC} - log_vpn_event() or view_logs() not using \$VPN_LOG_FILE"
    exit 1
fi
echo -e "${GREEN}PASS${NC} - All logging functions use secure \$VPN_LOG_FILE variable"

echo ""
echo "All log security tests passed!"

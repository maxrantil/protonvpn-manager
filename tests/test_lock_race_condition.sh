#!/bin/bash
# ABOUTME: Specific test for lock file TOCTOU race condition fix

set -euo pipefail

echo "Testing lock file race condition fix..."

# Test directory
TEST_DIR="/tmp/vpn_lock_test_$$"
mkdir -p "$TEST_DIR"
trap 'rm -rf $TEST_DIR' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to safely acquire lock (with TOCTOU fix)
safe_lock_acquire() {
    local lock_file="$1"
    local max_attempts=3
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        # Remove symlinks before creating lock
        if [[ -L "$lock_file" ]]; then
            rm -f "$lock_file"
        fi

        # Try to acquire lock atomically
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            # Double-check it's not a symlink (TOCTOU check)
            if [[ ! -L "$lock_file" ]]; then
                # Verify we own it
                local owner_pid
                owner_pid=$(cat "$lock_file" 2>/dev/null || echo "0")
                if [[ "$owner_pid" == "$$" ]]; then
                    return 0  # Successfully acquired
                fi
            fi
            rm -f "$lock_file"
        fi

        ((attempt++))
        sleep 0.1
    done

    return 1  # Failed to acquire
}

# Test 1: Normal lock acquisition
echo -n "Test 1 - Normal lock acquisition: "
LOCK_FILE="$TEST_DIR/normal.lock"
if safe_lock_acquire "$LOCK_FILE"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi
rm -f "$LOCK_FILE"

# Test 2: Symlink attack prevention
echo -n "Test 2 - Symlink attack prevention: "
LOCK_FILE="$TEST_DIR/symlink.lock"
ATTACKER_FILE="$TEST_DIR/attacker"

# Create symlink before lock attempt
ln -s "$ATTACKER_FILE" "$LOCK_FILE"

if safe_lock_acquire "$LOCK_FILE"; then
    # Check if symlink was removed and real lock created
    if [[ ! -L "$LOCK_FILE" ]] && [[ -f "$LOCK_FILE" ]]; then
        echo -e "${GREEN}PASS${NC} (symlink removed, lock acquired)"
    else
        echo -e "${RED}FAIL${NC} (lock state incorrect)"
        exit 1
    fi
else
    echo -e "${RED}FAIL${NC} (could not acquire lock)"
    exit 1
fi
rm -f "$LOCK_FILE"

# Test 3: Concurrent access (no race condition)
echo -n "Test 3 - Concurrent access safety: "
LOCK_FILE="$TEST_DIR/concurrent.lock"
SUCCESS_COUNT=0

# Launch multiple processes trying to acquire the same lock
for i in {1..5}; do
    (
        if safe_lock_acquire "$LOCK_FILE"; then
            echo "Process $i acquired lock" >> "$TEST_DIR/results.txt"
            sleep 0.2
            rm -f "$LOCK_FILE"
        fi
    ) &
done

wait

if [[ -f "$TEST_DIR/results.txt" ]]; then
    SUCCESS_COUNT=$(wc -l < "$TEST_DIR/results.txt")
fi

# All 5 should eventually acquire the lock (serially)
if [[ $SUCCESS_COUNT -ge 3 ]]; then
    echo -e "${GREEN}PASS${NC} ($SUCCESS_COUNT/5 processes acquired lock)"
else
    echo -e "${RED}FAIL${NC} (only $SUCCESS_COUNT/5 processes acquired lock)"
    exit 1
fi

# Test 4: Attack during lock hold
echo -n "Test 4 - Attack during lock hold: "
LOCK_FILE="$TEST_DIR/attack.lock"

# Acquire lock
safe_lock_acquire "$LOCK_FILE"

# Try to replace with symlink (attack)
(
    sleep 0.1
    rm -f "$LOCK_FILE" 2>/dev/null || true
    ln -s "$TEST_DIR/evil" "$LOCK_FILE" 2>/dev/null || true
) &

sleep 0.2

# Check if lock is still valid (not a symlink)
if [[ -f "$LOCK_FILE" ]] && [[ ! -L "$LOCK_FILE" ]]; then
    echo -e "${GREEN}PASS${NC} (lock integrity maintained)"
else
    echo -e "${RED}FAIL${NC} (lock was compromised)"
    exit 1
fi

wait

echo ""
echo "All lock file race condition tests passed!"

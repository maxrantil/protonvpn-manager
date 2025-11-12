#!/bin/bash
# ABOUTME: Test script for credential file security validations

set -euo pipefail

echo "Testing credential file security..."

# Test directory
TEST_DIR="/tmp/vpn_creds_test_$$"
mkdir -p "$TEST_DIR"
trap 'rm -rf $TEST_DIR' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Create test credentials file
CREDS_FILE="$TEST_DIR/vpn-credentials.txt"

echo "=== Test 1: Normal credentials file ==="
cat >"$CREDS_FILE" <<EOF
testuser
testpass
EOF
chmod 600 "$CREDS_FILE"

if ../src/vpn-manager validate_credentials "$CREDS_FILE" 2>&1 | grep -q "security checks passed"; then
	echo -e "${GREEN}PASS${NC} - Valid credentials accepted"
else
	echo -e "${RED}FAIL${NC} - Valid credentials rejected"
	exit 1
fi

echo ""
echo "=== Test 2: Symlink detection ==="
rm -f "$CREDS_FILE"
ln -s /etc/passwd "$CREDS_FILE"

if ../src/vpn-manager validate_credentials "$CREDS_FILE" 2>&1 | grep -q "symlink"; then
	echo -e "${GREEN}PASS${NC} - Symlink correctly detected"
else
	echo -e "${RED}FAIL${NC} - Symlink not detected"
	exit 1
fi

echo ""
echo "=== Test 3: Wrong ownership detection ==="
rm -f "$CREDS_FILE"
cat >"$CREDS_FILE" <<EOF
testuser
testpass
EOF

# Try to simulate wrong ownership (will fail if not root)
if [[ $EUID -eq 0 ]]; then
	chown nobody:nobody "$CREDS_FILE"
	if ../src/vpn-manager validate_credentials "$CREDS_FILE" 2>&1 | grep -q "not owned by current user"; then
		echo -e "${GREEN}PASS${NC} - Wrong ownership detected"
	else
		echo -e "${RED}FAIL${NC} - Wrong ownership not detected"
		exit 1
	fi
else
	echo -e "${GREEN}SKIP${NC} - Cannot test ownership (not root)"
fi

echo ""
echo "=== Test 4: Insecure permissions auto-fix ==="
rm -f "$CREDS_FILE"
cat >"$CREDS_FILE" <<EOF
testuser
testpass
EOF
chmod 666 "$CREDS_FILE"

# Run validation (should fix permissions)
../src/vpn-manager validate_credentials "$CREDS_FILE" >/dev/null 2>&1

PERMS=$(stat -c "%a" "$CREDS_FILE")
if [[ "$PERMS" == "600" ]]; then
	echo -e "${GREEN}PASS${NC} - Permissions fixed to 600"
else
	echo -e "${RED}FAIL${NC} - Permissions not fixed (currently $PERMS)"
	exit 1
fi

echo ""
echo "All credential security tests passed!"

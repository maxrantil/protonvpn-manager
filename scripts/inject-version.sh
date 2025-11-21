#!/bin/bash
# ABOUTME: Build-time version injection script for release artifacts
# ABOUTME: Replaces version placeholders in source files with actual release version

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.3"
    exit 1
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Invalid version format: $VERSION"
    echo "Expected: X.Y.Z or X.Y.Z-prerelease"
    exit 1
fi

echo "Injecting version $VERSION into source files..."

# Main vpn script - update banner and add version constant
if [[ -f "src/vpn" ]]; then
    # Add version constant at top of file (after shebang and ABOUTME)
    sed -i "/^# ABOUTME:/a\\
\\
# Version information\\
VERSION=\"$VERSION\"" src/vpn

    # Update banner version display
    sed -i "s/VPN Manager v[0-9.]\+\(-[a-zA-Z0-9.]\+\)\?/VPN Manager v$VERSION/" src/vpn

    # Add --version flag handler
    if ! grep -q '"--version"' src/vpn; then
        # Insert version handler before help case
        sed -i '/case "${1:-}" in/a\
    "--version" | "-v")\
        echo "VPN Manager v$VERSION"\
        echo "Artix/Arch Linux Edition"\
        exit 0\
        ;;' src/vpn
    else
        # Update existing version handler
        sed -i 's/echo "VPN Manager v[0-9.]\+\(-[a-zA-Z0-9.]\+\)\?"/echo "VPN Manager v'"$VERSION"'"/' src/vpn
    fi

    echo "✓ Updated src/vpn"
fi

# Update vpn-manager with version info
if [[ -f "src/vpn-manager" ]]; then
    if ! grep -q "^VERSION=" src/vpn-manager; then
        sed -i "/^# ABOUTME:/a\\
\\
# Version information\\
VERSION=\"$VERSION\"" src/vpn-manager
    else
        sed -i "s/^VERSION=.*/VERSION=\"$VERSION\"/" src/vpn-manager
    fi
    echo "✓ Updated src/vpn-manager"
fi

# Update vpn-connector with version info
if [[ -f "src/vpn-connector" ]]; then
    if ! grep -q "^VERSION=" src/vpn-connector; then
        sed -i "/^# ABOUTME:/a\\
\\
# Version information\\
VERSION=\"$VERSION\"" src/vpn-connector
    else
        sed -i "s/^VERSION=.*/VERSION=\"$VERSION\"/" src/vpn-connector
    fi
    echo "✓ Updated src/vpn-connector"
fi

# Update install script with version reference
if [[ -f "install.sh" ]]; then
    if grep -q "# Version:" install.sh; then
        sed -i "s/# Version: .*/# Version: $VERSION/" install.sh
    else
        sed -i "/^# ABOUTME:/a\\
# Version: $VERSION" install.sh
    fi
    echo "✓ Updated install.sh"
fi

echo ""
echo "Version injection complete!"
echo "Version $VERSION has been embedded in:"
echo "  - src/vpn (banner, --version flag, VERSION constant)"
echo "  - src/vpn-manager (VERSION constant)"
echo "  - src/vpn-connector (VERSION constant)"
echo "  - install.sh (version comment)"

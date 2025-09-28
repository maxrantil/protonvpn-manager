# Simple VPN Manager

A focused, lightweight VPN management tool for Artix/Arch Linux. Does one thing and does it right.

## What It Does

- Connects to VPN servers intelligently
- Manages OpenVPN processes safely
- Tests server performance for optimal selection
- Provides simple status monitoring
- Handles connection cleanup properly

## Core Components (2,553 lines total)

- `src/vpn` - Main CLI interface (331 lines)
- `src/vpn-manager` - Process management (875 lines)
- `src/vpn-connector` - Server selection (968 lines)
- `src/best-vpn-profile` - Performance testing (104 lines)
- `src/vpn-error-handler` - Error handling (275 lines)

## Quick Start

```bash
# Connect to best server
./src/vpn best

# Connect to specific country
./src/vpn connect se

# Check status
./src/vpn status

# Disconnect
./src/vpn disconnect
```

## Installation

```bash
git clone <repo>
cd vpn
git checkout vpn-simple
# Place your OpenVPN configs in locations/
./src/vpn connect
```

## What Was Removed

This simplified version removes the enterprise features (10,571 lines):
- API servers and WebSocket endpoints
- Enterprise security frameworks
- Audit logging and compliance features
- WCAG accessibility systems
- Configuration management frameworks
- Health monitoring dashboards
- Background services and timers
- Database encryption systems
- Notification management systems

These features are archived in `src_archive/` and can be restored if needed.

## Philosophy

**"Do one thing and do it right"** - This tool connects you to VPN servers quickly and reliably. Nothing more, nothing less.

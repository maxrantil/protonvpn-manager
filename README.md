# Simple VPN Manager

A focused, lightweight VPN management tool for Artix/Arch Linux systems. **Does one thing and does it right.**

## Philosophy

This project follows the Unix philosophy: **"Do one thing and do it right."** It connects you to VPN servers quickly, reliably, and safely. Nothing more, nothing less.

## What It Does

- **Intelligent Server Selection**: Automatically finds the best performing VPN server
- **Safe Process Management**: Prevents multiple OpenVPN processes, handles cleanup properly
- **Performance Testing**: Tests server latency and speed for optimal connections
- **Clear Status Information**: Shows connection state, external IP, and performance metrics
- **Configuration Management**: Validates and fixes OpenVPN configuration files
- **Simple Logging**: Color-coded event logging for debugging and monitoring (October 2025)

## Quick Start

```bash
# Connect to best server automatically
./src/vpn best

# Connect to specific country (e.g., Sweden)
./src/vpn connect se

# Check current status
./src/vpn status

# Disconnect
./src/vpn disconnect

# Show all available commands
./src/vpn help
```

## Installation

### Prerequisites
- Artix Linux or Arch Linux
- OpenVPN installed (`sudo pacman -S openvpn`)
- ProtonVPN account with OpenVPN configuration files

### Setup
```bash
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager

# Place your OpenVPN configs in locations/ directory
# Then start using:
./src/vpn connect
```

## Core Components (2,891 lines total)

This simplified version contains only essential components:

- **`src/vpn`** - Main CLI interface (307 lines)
- **`src/vpn-manager`** - Process management and safety (949 lines)
- **`src/vpn-connector`** - Server selection logic (977 lines)
- **`src/best-vpn-profile`** - Performance testing engine (104 lines)
- **`src/vpn-error-handler`** - Error handling (275 lines)
- **`src/fix-ovpn-configs`** - Configuration file validation (281 lines)
- **`src/vpn-utils`** - Shared utility functions (logging, notifications)
- **`src/vpn-colors`** - Color management with NO_COLOR support

## Available Commands

### Connection Management
```bash
./src/vpn connect [country]    # Connect to VPN (optional country code)
./src/vpn disconnect          # Disconnect from VPN
./src/vpn reconnect          # Reconnect to current server
./src/vpn status             # Show connection status
```

### Server Selection
```bash
./src/vpn best               # Connect to best performing server
./src/vpn fast [country]     # Quick connect using cached results
./src/vpn list               # List available servers
./src/vpn test               # Test current connection performance
```

### System Management
```bash
./src/vpn cleanup            # Clean up processes and routes
./src/vpn kill               # Force kill VPN processes
./src/vpn health             # Check system health
./src/vpn logs [lines]       # View recent log entries (default: 50)
```

## Recent Enhancements

**October 2025 - Code Quality Improvements:**
- Extracted shared utilities to eliminate duplication (~40 lines saved)
- Centralized color management with NO_COLOR support (accessibility)
- Unified logging functions across all components
- Added comprehensive unit tests for utilities

**October 2025 - Basic Logging System:**
- Added simple event logging to help with debugging
- View logs with: `./src/vpn logs [lines]`
- Color-coded output (green=INFO, yellow=WARN, red=ERROR)
- Automatic log rotation (keeps last 1000 lines)
- Logs stored at: `/tmp/vpn_simple.log`

## What Was Removed

In September 2025, this project was simplified from a complex enterprise system (13,124 lines) to this focused tool (~2,900 lines). The following enterprise features were removed:

- API servers and WebSocket endpoints
- Enterprise security frameworks and audit logging
- WCAG accessibility compliance systems
- Complex configuration management (TOML parsing, inheritance)
- Health monitoring dashboards and alerting
- Background services and automated timers
- Database encryption and backup systems
- Notification management frameworks

**These features were archived** in git history (see commits before October 2025) if needed for reference.

## Development

This project prioritizes simplicity and reliability. See `CLAUDE.md` for development guidelines that prevent feature creep and maintain focus.

### Core Principles
1. **Simplicity First**: Prefer simple solutions over complex ones
2. **Performance Over Features**: Fast, reliable connections matter most
3. **No Feature Creep**: Resist adding "nice to have" features
4. **Maintainability**: Keep code readable and debuggable

## Branch Structure

- **`master`**: Main development branch (simplified version, ~2,900 lines)

The enterprise version (13K+ lines) was removed in October 2025. All development now happens on `master`.

## Contributing

Contributions should align with the project's simplicity philosophy. New features must be:
1. Essential for core VPN functionality
2. Simple to implement and maintain
3. Not duplicating existing functionality

## License

This project is developed for educational and personal use on Artix/Arch Linux systems.

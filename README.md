# Simple VPN Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://github.com/maxrantil/protonvpn-manager/workflows/Run%20Tests/badge.svg)](https://github.com/maxrantil/protonvpn-manager/actions)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20Artix-blue.svg)](https://archlinux.org/)

A focused, lightweight VPN management tool for Artix/Arch Linux systems. **Does one thing and does it right.**

## Philosophy

This project follows the Unix philosophy: **"Do one thing and do it right."** It connects you to VPN servers quickly, reliably, and safely. Nothing more, nothing less.

## What It Does

- **Intelligent Server Selection**: Automatically finds the best performing VPN server
- **Safe Process Management**: Prevents multiple OpenVPN processes, handles cleanup properly
- **Performance Testing**: Tests server latency and speed for optimal connections
- **Clear Status Information**: Shows connection state, external IP, and performance metrics
- **Accessibility Support**: Screen reader mode, NO_COLOR support, WCAG AA compliant (October 2025)
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
./src/vpn status --accessible  # Screen reader friendly output
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

This project prioritizes simplicity and reliability over feature abundance.

### Core Principles
1. **Simplicity First**: Prefer simple solutions over complex ones
2. **Performance Over Features**: Fast, reliable connections matter most
3. **No Feature Creep**: Resist adding "nice to have" features
4. **Maintainability**: Keep code readable and debuggable

### Testing

All features require comprehensive tests before merging:
- Unit tests for individual functions
- Integration tests for component interactions
- End-to-end tests for complete workflows

Run the test suite:
```bash
cd tests
./run_tests.sh
```

## Branch Structure

- **`master`**: Main development branch (simplified version, ~2,900 lines)

The enterprise version (13K+ lines) was removed in October 2025. All development now happens on `master`.

## Contributing

Contributions are welcome! This project values simplicity and quality over quantity.

### Before Contributing

New features must be:
1. **Essential** for core VPN functionality (not "nice to have")
2. **Simple** to implement and maintain
3. **Tested** with comprehensive test coverage
4. **Documented** with clear usage examples

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feat/your-feature`)
3. **Write tests** for your changes (test-driven development required)
4. **Implement** your feature/fix
5. **Test** thoroughly (all tests must pass)
6. **Commit** your changes with clear, descriptive messages
7. **Push** to your fork
8. **Submit** a pull request

### Reporting Issues

Found a bug or have a suggestion?
- Check existing [issues](https://github.com/maxrantil/protonvpn-manager/issues) first
- Create a new issue with clear description and reproduction steps
- For security vulnerabilities, see [SECURITY.md](SECURITY.md)

## Security

Security is a top priority. Please review [SECURITY.md](SECURITY.md) for:
- Reporting vulnerabilities responsibly
- Understanding the security model
- Known security practices
- User security best practices

**Never open a public issue for security vulnerabilities** - report them privately to rantil@pm.me.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Max Rantil

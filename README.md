# VPN Management System

A comprehensive VPN management suite with intelligent server selection, performance testing, and automated connection handling for Artix/Arch Linux systems.

## Status
- **Current Phase**: ProtonVPN Config Auto-Downloader Development - Phase 0 Complete
- **Progress**: Security foundation implemented, ready for Phase 1 authentication
- **Last Updated**: September 17, 2025
- **Latest Achievement**: Issue #39 Phase 0 - Enterprise-grade security foundation with 2FA TOTP
- **Active Work**: Issue #39 Phase 1 - ProtonVPN Authentication Module (Next: `src/proton-auth`)
- **Previous Work**: Core VPN functionality complete (Issues #37, #38 closed)

## Project Structure

This repository contains documentation and implementation planning for the VPN management system:

```
vpn-management/
├── README.md                           # This file
├── CLAUDE.md                          # Development guidelines and workflow
├── docs/                              # All project documentation
│   ├── implementation/                # Implementation plans and phase docs
│   │   ├── VPN_PORTING_IMPLEMENTATION_PLAN.md
│   │   ├── TESTING_IMPLEMENTATION.md
│   │   ├── PHASE_2_COMPLETE.md
│   │   ├── PHASE_3_COMPLETE.md
│   │   ├── SETUP_README.md
│   │   └── SYSTEM_ANALYSIS.md
│   └── templates/                     # GitHub issue templates and guides
│       ├── example_github_issue.md
│       └── github_issue_template_with_tdd.md
├── config/                            # Configuration files
│   └── .pre-commit-config.yaml       # Quality gates and pre-commit hooks
└── tests/                             # Comprehensive testing framework
    ├── test_framework.sh             # Professional testing utilities
    ├── unit_tests.sh                 # 35 unit tests
    ├── integration_tests.sh          # 20 integration tests
    ├── e2e_tests.sh                  # 21+ end-to-end tests
    └── run_tests.sh                  # Test runner with reporting
```

## Quick Start

### Prerequisites
- Artix Linux or Arch Linux system
- Required packages:
  ```bash
  sudo pacman -S openvpn curl bc libnotify iproute2 git
  ```
- ProtonVPN account with OpenVPN configuration files

### Automated Installation

**One-command installation:**
```bash
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
./install.sh
```

The installer will:
- Install required system packages (`openvpn`, `curl`, `bc`, `libnotify`, `iproute2`)
- Set up directory structure
- Create credential template and locations guide
- Make all scripts executable
- Add VPN tools to your PATH
- Run post-installation verification tests

### Manual Installation

1. **Install dependencies**:
   ```bash
   sudo pacman -S openvpn curl bc libnotify iproute2 git
   ```

2. **Clone repository**:
   ```bash
   git clone https://github.com/maxrantil/protonvpn-manager.git
   cd protonvpn-manager
   ```

3. **Set up VPN profiles directory**:
   ```bash
   mkdir -p locations/
   # Copy your ProtonVPN .ovpn files to locations/ directory
   ```

4. **Create credentials file**:
   ```bash
   # Create vpn-credentials.txt with your ProtonVPN username and password
   echo "your-username" > vpn-credentials.txt
   echo "your-password" >> vpn-credentials.txt
   chmod 600 vpn-credentials.txt
   ```

5. **Make scripts executable**:
   ```bash
   chmod +x src/*
   ```

6. **Test installation**:
   ```bash
   ./src/vpn help
   ```

### Uninstallation

To completely remove the VPN Management System:
```bash
./uninstall.sh
```

The uninstaller will:
- Safely disconnect any active VPN connections
- Back up your configuration files and credentials
- Remove all VPN management components
- Clean up temporary files and caches
- Remove PATH modifications
- Provide options for removing system packages

## Development Status

### ✅ Completed Phases

**Phase 1: Foundation & Environment Setup** (Completed: September 2, 2025)
- System requirements analysis and package verification
- Development environment setup with all dependencies

**Phase 2: Core Script Foundation** (Completed: September 2, 2025)
- Main CLI interface and process management
- Basic connection handling and lock file mechanisms

**Phase 3: Connection Management** (Completed: September 2, 2025)
- Profile management and country-based connections
- Performance caching system implementation

### ✅ Recently Completed
**Phase 4: Performance Testing Engine** (Completed: September 3, 2025)
- Multi-server performance testing with intelligent server selection
- Latency and speed testing with automatic ranking
- 10/10 TDD tests passing

**Phase 5: Advanced Features** (Completed: September 4, 2025)
- Fast switching system with cache-based optimization
- Secure core integration and custom profile support
- OpenVPN configuration auto-fixer with stability enhancements

**Phase 6: System Integration** (Completed: September 5, 2025)
- Desktop notifications with multi-environment fallback system
- Status bar integration (dwmblocks) with 58% performance improvement
- Runit service integration for Artix Linux

**Phase 7: Configuration & Utilities** (Completed: September 7, 2025)
- Centralized logging infrastructure with credential sanitization
- Configuration repair system for corrupted OpenVPN files
- 19/19 comprehensive tests passing

**Phase 8: Testing & Validation** (Completed: September 7, 2025)
- Comprehensive test framework with 15/15 tests passing
- Performance validation: 2.0s connection speed (< 30s requirement)
- Edge case testing with graceful error handling

### 🚧 Current Work
**Issue #39: ProtonVPN Config Auto-Downloader** (In Progress)
- **✅ Phase 0**: Security Foundation - COMPLETE (2025-09-17)
  - Secure credential manager with GPG encryption
  - 2FA TOTP authentication system
  - Defense-in-depth security architecture
  - Comprehensive TDD test coverage (70+ tests)
- **🚧 Phase 1**: ProtonVPN Authentication Module - NEXT
  - Triple-credential authentication workflow
  - 2FA integration with ProtonVPN login
  - Session management with CSRF protection

### 📋 Future Phases
- Phase 10: WireGuard Protocol Optimization (Deferred - OpenVPN stable)

## Usage

### Basic Commands

```bash
# Show help and available commands
./src/vpn help

# Connect to VPN (automatic best server)
./src/vpn best

# Connect to specific country (e.g., Sweden)
./src/vpn connect se

# Fast switching with cache
./src/vpn fast

# Check VPN status
./src/vpn status

# Disconnect from VPN
./src/vpn disconnect

# Connect to secure core servers
./src/vpn secure

# Use custom OpenVPN profile
./src/vpn custom /path/to/profile.ovpn
```

### System Integration

- **Desktop Notifications**: Automatic notifications for connection events
- **Status Bar Integration**: Works with dwmblocks and other status bars
- **Service Management**: Integrates with Artix runit services
- **Logging**: Comprehensive logging to `/tmp/vpn_tester.log`

## Testing

This project follows **strict Test-Driven Development (TDD)** practices:

- **100+ comprehensive tests** across all system components
- **Phase-specific test suites** with complete validation
- **Performance benchmarking** with regression detection
- **Edge case coverage** for robust error handling

### Run Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run Phase 8 validation tests
./tests/phase8_complete_validation_tests.sh

# Run performance tests
./tests/phase8_2_performance_validation_tests.sh

# Run edge case tests
./tests/phase8_3_edge_case_tests.sh
```

## Development

This project follows comprehensive development guidelines outlined in [CLAUDE.md](CLAUDE.md):

- **Mandatory GitHub issues** before starting work
- **Test-Driven Development** with RED-GREEN-REFACTOR cycles
- **Pre-commit hooks** for quality assurance
- **Implementation plan tracking** with phase completion

### Workflow

1. **Create GitHub issue** describing the work
2. **Create feature branch** following naming conventions
3. **Setup pre-commit hooks** (if not already done)
4. **Follow TDD practices**: Write failing tests first
5. **Commit frequently** with atomic, logical changes
6. **Update implementation plan** when phases complete

## Contributing

All contributions must follow our established workflow:

1. **GitHub Issues First**: Always create an issue before starting work
2. **TDD Compliance**: Include TDD checklist in every issue and follow RED-GREEN-REFACTOR
3. **Pre-commit Quality**: All commits must pass comprehensive pre-commit hooks
4. **Professional Testing**: Unit, integration, and end-to-end tests required

See [CLAUDE.md](CLAUDE.md) for complete development guidelines and [docs/templates/](docs/templates/) for issue templates.

## System Architecture

### Core Components

- **`src/vpn`**: Main CLI interface with command routing
- **`src/vpn-manager`**: Process management and connection lifecycle
- **`src/vpn-connector`**: Server selection and connection logic
- **`src/best-vpn-profile`**: Performance testing and server ranking
- **`src/connect-vpn-bg`**: Background connection handling

### Utilities

- **`src/vpn-statusbar`**: Status bar integration (dwmblocks)
- **`src/vpn-notify`**: Centralized notification system
- **`src/vpn-service`**: System service integration (runit/systemd)
- **`src/vpn-logger`**: Centralized logging with credential sanitization
- **`src/fix-ovpn-files`**: Configuration repair and enhancement

### Key Features

- **Intelligent Server Selection**: Automatic best server detection
- **Performance Caching**: Fast switching with cached performance data
- **Multi-Protocol Support**: OpenVPN ready, WireGuard infrastructure in place
- **System Integration**: Desktop notifications, status bar, service management
- **Robust Error Handling**: Comprehensive edge case coverage
- **Security**: Credential protection and secure core server support

### Performance

- **Connection Speed**: < 2.0s (requirement: < 30s)
- **Fast Switching**: < 2.0s (requirement: < 20s)
- **Memory Usage**: Stable with < 4KB growth over time
- **Process Safety**: Zero-tolerance for multiple OpenVPN processes

## License

This project is developed for educational and personal use on Artix/Arch Linux systems.

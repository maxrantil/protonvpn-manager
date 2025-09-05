# VPN Management System

A comprehensive VPN management suite with intelligent server selection, performance testing, and automated connection handling for Artix/Arch Linux systems.

## Status
- **Current Phase**: Phase 6: System Integration (Status Bar Integration Complete)
- **Progress**: 6.2/9 phases completed (69%)
- **Last Updated**: September 5, 2025
- **Latest Achievement**: Status bar integration with 58% performance improvement (16/16 tests passing)

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
- Git and GitHub CLI (`gh`) installed
- Pre-commit hooks support

### Setup Development Environment

1. **Clone and setup project**:
   ```bash
   git clone https://github.com/maxrantil/protonvpn-manager.git
   cd protonvpn-manager
   ```

2. **Install pre-commit hooks**:
   ```bash
   pip install pre-commit
   pre-commit install
   ```

3. **Run tests** (comprehensive test suite):
   ```bash
   ./tests/run_tests.sh
   ```

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
**Phase 5: Advanced Features** (Completed: September 4, 2025)
**Phase 6.1: Desktop Notifications** (Completed: September 5, 2025)
- Centralized notification system with desktop environment detection
- Fallback chain for maximum compatibility (notify-send → zenity → kdialog → echo)
- Legacy notification migration completed (12 calls centralized)

### 🚧 Current Work
**Phase 6.2-6.3: System Integration** (Status Bar & Service Integration)
- dwmblocks status bar integration
- Artix/OpenRC system service compatibility

### 📋 Upcoming Phases
- Phase 5: Advanced Features (Fast switching, secure core)
- Phase 6: System Integration (Desktop notifications, status bar)
- Phase 7: Configuration & Utilities
- Phase 8: Testing & Validation
- Phase 9: Documentation & Packaging

## Testing

This project follows **strict Test-Driven Development (TDD)** practices:

- **76+ comprehensive tests** across unit, integration, and end-to-end categories
- **Professional test framework** with mocking, isolation, and reporting
- **Pre-commit quality gates** ensure all commits pass testing standards

### Run Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test types
./tests/run_tests.sh --unit-only
./tests/run_tests.sh --integration-only
./tests/run_tests.sh --e2e-only
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

## Architecture

The VPN management system consists of:

- **CLI Interface**: Main `vpn` command with subcommand routing
- **Process Management**: VPN connection lifecycle and monitoring
- **Connection Logic**: Intelligent server selection and switching
- **Performance Testing**: Multi-server latency and speed testing
- **Caching System**: Performance data caching for fast switching
- **Security Features**: Credential protection and secure core support

## License

This project is developed for educational and personal use on Artix/Arch Linux systems.

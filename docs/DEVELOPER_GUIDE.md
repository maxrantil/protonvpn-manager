# VPN Configuration Management System - Developer Guide

**Version:** 4.2.3
**Last Updated:** September 22, 2025
**Development Status:** Test-Driven Development with Agent-Based Quality Assurance

## Table of Contents

1. [Development Overview](#development-overview)
2. [Development Environment Setup](#development-environment-setup)
3. [Code Standards and Guidelines](#code-standards-and-guidelines)
4. [Test-Driven Development](#test-driven-development)
5. [Agent-Driven Development](#agent-driven-development)
6. [Git Workflow](#git-workflow)
7. [Component Architecture](#component-architecture)
8. [Testing Framework](#testing-framework)
9. [Security Development](#security-development)
10. [Performance Guidelines](#performance-guidelines)
11. [Contributing Guidelines](#contributing-guidelines)
12. [Troubleshooting Development Issues](#troubleshooting-development-issues)

## Development Overview

### Project Philosophy

This project follows **strict engineering discipline** with multiple layers of quality assurance:

- **Test-Driven Development (TDD)**: Every line of production code must be written to make a failing test pass
- **Agent-Driven Development**: Specialized AI agents validate code quality, security, performance, and architecture
- **Security-First Approach**: 17/17 security tests must pass before any code merge
- **Performance Standards**: Sub-2-second response times with comprehensive benchmarking
- **Accessibility Compliance**: WCAG 2.1 Level AA standards for all user-facing components

### Development Principles

1. **RED-GREEN-REFACTOR**: Write failing test → Make it pass → Improve code
2. **Security by Design**: Every component designed with security as primary concern
3. **Performance by Default**: Optimize for speed and resource efficiency
4. **Accessibility First**: Design for screen readers and assistive technologies
5. **Agent Validation**: Use AI agents for comprehensive code review
6. **Zero Tolerance**: No security vulnerabilities, no performance regressions

### Technology Stack

**Core Technologies:**
- **Shell Scripting**: Bash 4.0+ for system components
- **Configuration**: TOML for structured configuration management
- **Database**: SQLite with GPG encryption for data persistence
- **API**: RESTful HTTP API with WebSocket support
- **Service Management**: Runit (Artix) and systemd (Arch) integration
- **Security**: GPG encryption, systemd hardening, privilege separation

**Development Tools:**
- **Testing**: Custom TDD framework with 100+ comprehensive tests
- **Quality Assurance**: Pre-commit hooks with multiple validation layers
- **Agent Integration**: Specialized AI agents for code review
- **Documentation**: Markdown with structured technical writing
- **Version Control**: Git with feature-branch workflow

## Development Environment Setup

### Prerequisites

**System Requirements:**
```bash
# Required system packages
sudo pacman -S openvpn curl bc libnotify iproute2 git sqlite gnupg

# Development tools
sudo pacman -S shellcheck bash-completion make jq

# Documentation tools
sudo pacman -S pandoc  # For documentation generation
```

**Development Dependencies:**
```bash
# Testing framework dependencies
sudo pacman -S expect  # For interactive testing
sudo pacman -S netcat  # For network testing
sudo pacman -S socat   # For advanced network testing
```

### Repository Setup

**1. Clone and Setup:**
```bash
# Clone the repository
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager

# Verify repository integrity
git log --oneline -10
git status

# Check branch structure
git branch -a
```

**2. Development Environment:**
```bash
# Install pre-commit hooks (MANDATORY)
cp config/.pre-commit-config.yaml .pre-commit-config.yaml
pre-commit install

# Setup development configuration
cp config/development.conf.example config/development.conf

# Setup test environment
./scripts/setup-dev-environment.sh
```

**3. Validate Development Setup:**
```bash
# Run development validation
make dev-install
make dev-test

# Verify pre-commit hooks
pre-commit run --all-files

# Run basic test suite
./tests/run_tests.sh --development
```

### IDE Configuration

**VSCode Settings** (`.vscode/settings.json`):
```json
{
    "shellcheck.enable": true,
    "shellcheck.executablePath": "/usr/bin/shellcheck",
    "shellcheck.run": "onSave",
    "files.associations": {
        "*.conf": "toml",
        "**/src/*": "shellscript"
    },
    "editor.rulers": [80, 120],
    "editor.tabSize": 4,
    "editor.insertSpaces": true
}
```

**Vim Configuration** (`.vimrc`):
```vim
" Shell script development
autocmd FileType sh setlocal shiftwidth=4 tabstop=4 expandtab
autocmd FileType sh let g:ale_linters = ['shellcheck']
autocmd FileType sh let g:ale_fixers = ['shfmt']

" TOML configuration files
autocmd BufNewFile,BufRead *.conf set filetype=toml
```

## Code Standards and Guidelines

### Shell Scripting Standards

**1. File Structure:**
```bash
#!/bin/bash
# ABOUTME: Brief description of what this script does
# ABOUTME: Additional context about purpose and functionality

set -euo pipefail

# Security: Follow established patterns
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration and constants
readonly DEFAULT_VALUE="example"
readonly CONFIG_FILE="${CONFIG_DIR:-/etc/protonvpn}/component.conf"

# Main functionality begins here...
```

**2. Naming Conventions:**
```bash
# Variables: lowercase with underscores
local connection_status="connected"
readonly MAX_RETRY_ATTEMPTS=3

# Functions: lowercase with underscores
check_vpn_status() {
    local server_name="$1"
    # Function implementation
}

# Constants: uppercase with underscores
readonly API_SERVER_PORT=8080
readonly LOG_FILE="/var/log/protonvpn/service.log"
```

**3. Error Handling:**
```bash
# Comprehensive error handling
validate_input() {
    local input="$1"

    # Input validation
    if [[ -z "$input" ]]; then
        log_error "Input cannot be empty"
        return 1
    fi

    # Security sanitization
    if [[ "$input" =~ [^a-zA-Z0-9._-] ]]; then
        log_error "Input contains invalid characters"
        return 1
    fi

    return 0
}

# Error handling in main functions
main() {
    if ! validate_input "$1"; then
        exit 1
    fi

    # Main logic with error handling
    if ! perform_operation; then
        log_error "Operation failed"
        cleanup_on_failure
        exit 1
    fi
}
```

### Configuration Management

**TOML Configuration Standards:**
```toml
# Use clear section hierarchies
[component_name]
setting_name = "value"
numeric_setting = 42
boolean_setting = true

[component_name.subsection]
nested_setting = "value"

# Include documentation comments
[dashboard]
# Refresh interval in seconds (1-60)
refresh_interval = 5

# Output format: "json" or "human"
output_format = "json"

# History retention period (e.g., "7d", "30d", "1y")
history_retention = "7d"
```

**Configuration Validation:**
```bash
# Use config-manager for all configuration access
validate_config() {
    local config_file="$1"

    # Check file exists and is readable
    if [[ ! -r "$config_file" ]]; then
        log_error "Configuration file not readable: $config_file"
        return 1
    fi

    # Validate with config-manager
    if ! "$CONFIG_MANAGER" validate "$config_file"; then
        log_error "Configuration validation failed: $config_file"
        return 1
    fi

    return 0
}
```

### Security Coding Standards

**1. Input Validation and Sanitization:**
```bash
# Always validate and sanitize input
sanitize_path() {
    local path="$1"

    # Remove potentially dangerous characters
    path=$(echo "$path" | tr -d '\0')

    # Validate path format
    if [[ ! "$path" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Invalid path format: $path"
        return 1
    fi

    # Prevent directory traversal
    if [[ "$path" == *".."* ]]; then
        log_error "Directory traversal detected: $path"
        return 1
    fi

    echo "$path"
}

# Sanitize log content
sanitize_log_content() {
    local content="$1"

    # Remove sensitive information
    content=$(echo "$content" | sed -E 's/(password|key|secret|token)=[^[:space:]]*/\1=***REDACTED***/gi')
    content=$(echo "$content" | sed -E 's|(/root|/home/[^/]*/\.ssh)[^[:space:]]*|\*\*\*REDACTED\*\*\*|g')

    # Remove ANSI escape sequences for log injection prevention
    content=$(echo "$content" | sed 's/\x1b\[[0-9;]*[mGKH]//g')

    echo "$content"
}
```

**2. Secure File Operations:**
```bash
# Secure file creation with proper permissions
create_secure_file() {
    local file_path="$1"
    local content="$2"
    local owner="${3:-protonvpn}"
    local permissions="${4:-600}"

    # Create file with restrictive permissions
    umask 077
    echo "$content" > "$file_path"

    # Set proper ownership and permissions
    chown "$owner:$owner" "$file_path"
    chmod "$permissions" "$file_path"

    # Verify security
    local actual_perms=$(stat -c %a "$file_path")
    if [[ "$actual_perms" != "$permissions" ]]; then
        log_error "Failed to set secure permissions on $file_path"
        rm -f "$file_path"
        return 1
    fi
}
```

## Test-Driven Development

### TDD Methodology

**Mandatory TDD Process:**
1. **RED**: Write a failing test that defines the desired functionality
2. **GREEN**: Write the minimal code to make the test pass
3. **REFACTOR**: Improve the code while keeping tests green
4. **VALIDATE**: Run agent validation before committing

**TDD Rules (NO EXCEPTIONS):**
- ❌ **NEVER write production code without a failing test first**
- ❌ **NEVER write more code than needed to make the test pass**
- ❌ **NEVER skip the refactor step**
- ✅ **Every test must fail for the right reason (not syntax errors)**
- ✅ **Each test focuses on one specific behavior**
- ✅ **All tests must pass before moving to next feature**

### Test Structure

**Test File Template:**
```bash
#!/bin/bash
# ABOUTME: Comprehensive tests for [component name]
# ABOUTME: Tests cover functionality, security, performance, and edge cases

# Test framework setup
source "$(dirname "$0")/test_framework.sh"
set -euo pipefail

# Test configuration
readonly COMPONENT_NAME="example-component"
readonly TEST_DATA_DIR="$(dirname "$0")/data"
readonly TEMP_TEST_DIR="/tmp/vpn-tests-$$"

# Setup and teardown
setup_test_environment() {
    mkdir -p "$TEMP_TEST_DIR"
    export TEST_MODE=1
    export VPN_DEBUG=1
}

teardown_test_environment() {
    rm -rf "$TEMP_TEST_DIR"
    unset TEST_MODE VPN_DEBUG
}

# Test cases
test_component_basic_functionality() {
    local test_name="Component Basic Functionality"

    # Arrange: Setup test conditions
    local test_input="valid_input"
    local expected_output="expected_result"

    # Act: Execute the functionality
    local actual_output
    actual_output=$("$COMPONENT_PATH" "$test_input" 2>&1)
    local exit_code=$?

    # Assert: Verify results
    assert_equals "$exit_code" "0" "$test_name - Exit code"
    assert_equals "$actual_output" "$expected_output" "$test_name - Output"

    print_test_result "PASS" "$test_name"
}

test_component_security_validation() {
    local test_name="Component Security Validation"

    # Test input sanitization
    local malicious_input="../../../etc/passwd"
    local output
    output=$("$COMPONENT_PATH" "$malicious_input" 2>&1)
    local exit_code=$?

    # Should reject malicious input
    assert_not_equals "$exit_code" "0" "$test_name - Rejects malicious input"
    assert_contains "$output" "Invalid" "$test_name - Error message"

    print_test_result "PASS" "$test_name"
}

test_component_performance() {
    local test_name="Component Performance"

    # Performance timing
    local start_time=$(date +%s.%N)
    "$COMPONENT_PATH" "performance_test_input" > /dev/null
    local end_time=$(date +%s.%N)

    # Calculate duration
    local duration=$(echo "$end_time - $start_time" | bc)
    local max_duration="5.0"  # 5 seconds maximum

    # Assert performance requirement
    if (( $(echo "$duration < $max_duration" | bc -l) )); then
        print_test_result "PASS" "$test_name - Duration: ${duration}s"
    else
        print_test_result "FAIL" "$test_name - Duration: ${duration}s (exceeds ${max_duration}s)"
        exit 1
    fi
}

# Main test execution
main() {
    echo "Starting tests for $COMPONENT_NAME"

    setup_test_environment

    # Execute all test functions
    test_component_basic_functionality
    test_component_security_validation
    test_component_performance

    teardown_test_environment

    echo "All tests passed for $COMPONENT_NAME ✅"
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Test Categories

**1. Unit Tests:** Test individual functions in isolation
```bash
test_validate_country_code() {
    # Test valid country codes
    assert_true "validate_country_code 'se'" "Sweden code valid"
    assert_true "validate_country_code 'nl'" "Netherlands code valid"

    # Test invalid country codes
    assert_false "validate_country_code 'xx'" "Invalid code rejected"
    assert_false "validate_country_code ''" "Empty code rejected"
}
```

**2. Integration Tests:** Test component interactions
```bash
test_config_manager_integration() {
    # Test config-manager with status-dashboard integration
    local config_file="$TEMP_TEST_DIR/test.conf"
    echo 'refresh_interval = 10' > "$config_file"

    # Test config reading
    local interval
    interval=$("$CONFIG_MANAGER" get "$config_file" "refresh_interval")
    assert_equals "$interval" "10" "Config manager reads value"

    # Test dashboard uses config
    local dashboard_output
    dashboard_output=$("$STATUS_DASHBOARD" --config="$config_file" --test)
    assert_contains "$dashboard_output" "10" "Dashboard uses config value"
}
```

**3. End-to-End Tests:** Test complete user workflows
```bash
test_complete_vpn_workflow() {
    # Test full connection cycle
    local output

    # Connect to VPN
    output=$(vpn best 2>&1)
    assert_contains "$output" "Connected" "VPN connection successful"

    # Check status
    output=$(vpn status 2>&1)
    assert_contains "$output" "Connected" "Status shows connected"

    # Disconnect
    output=$(vpn disconnect 2>&1)
    assert_contains "$output" "Disconnected" "Disconnection successful"
}
```

## Agent-Driven Development

### Agent Integration Requirements

**MANDATORY Agent Usage:**
All development must use specialized AI agents for quality assurance. This is not optional.

**Agent Trigger Matrix:**
- **code-quality-analyzer**: For ALL code changes (mandatory)
- **security-validator**: For ALL code changes (mandatory)
- **performance-optimizer**: For performance-critical components
- **ux-accessibility-i18n-agent**: For user-facing components
- **architecture-designer**: For structural changes

### Agent Workflow Integration

**Pre-Implementation Phase:**
```bash
# 1. Run architecture analysis for structural changes
# Agent: architecture-designer
# Task: Analyze proposed changes for architectural impact

# 2. Run security analysis for all changes
# Agent: security-validator
# Task: Identify potential security vulnerabilities

# 3. Run performance analysis for optimization opportunities
# Agent: performance-optimizer
# Task: Identify performance bottlenecks and optimization opportunities
```

**Implementation Phase:**
```bash
# Continuous agent validation during development
# Use agents to validate each significant code change
```

**Post-Implementation Phase:**
```bash
# 1. Run comprehensive code quality analysis
# Agent: code-quality-analyzer
# Expected: Score ≥ 4.0/5.0, comprehensive test coverage

# 2. Run security validation
# Agent: security-validator
# Expected: Risk level ≤ MEDIUM, no critical vulnerabilities

# 3. Run performance validation
# Agent: performance-optimizer
# Expected: No performance regressions, optimization recommendations

# 4. Run accessibility validation (if user-facing)
# Agent: ux-accessibility-i18n-agent
# Expected: WCAG 2.1 Level AA compliance
```

### Agent Validation Requirements

**Code Quality Standards:**
- Score ≥ 4.0/5.0 from code-quality-analyzer
- 100% test coverage for new functionality
- No code smells or architectural violations

**Security Standards:**
- Risk level ≤ MEDIUM from security-validator
- No critical or high-severity vulnerabilities
- All security tests passing (17/17)

**Performance Standards:**
- No regressions in performance benchmarks
- Response times within established limits
- Resource usage within defined bounds

**Accessibility Standards (when applicable):**
- WCAG 2.1 Level AA compliance
- Screen reader compatibility
- Keyboard navigation support

## Git Workflow

### Branch Strategy

**Branch Naming Convention:**
```bash
# Feature branches
feat/issue-123-component-name

# Bug fix branches
fix/issue-456-bug-description

# Security fix branches
security/issue-789-vulnerability-description

# Performance improvement branches
perf/issue-012-optimization-description
```

**Mandatory Workflow:**
1. **Create GitHub Issue**: Always create issue before starting work
2. **Feature Branch**: Create branch from master
3. **TDD Development**: Follow RED-GREEN-REFACTOR cycles
4. **Agent Validation**: Run all applicable agents
5. **Pre-commit Validation**: All pre-commit hooks must pass
6. **Pull Request**: Create PR with comprehensive description
7. **Code Review**: Peer review and agent validation
8. **Merge**: Squash merge to master after approval

### Commit Standards

**Commit Message Format:**
```
type(scope): short description

Detailed description of changes made and why.

- Specific change 1
- Specific change 2
- Specific change 3

Agent Validation:
- code-quality-analyzer: ✅ PASSED (Score: 4.5/5.0)
- security-validator: ✅ PASSED (Risk: LOW)
- performance-optimizer: ✅ PASSED (No regressions)

Fixes #123
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `security`: Security fix
- `perf`: Performance improvement
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `docs`: Documentation changes
- `style`: Code style changes

**Atomic Commits:**
```bash
# Good: Single logical change
git commit -m "feat(api-server): add authentication middleware

- Implement JWT token validation
- Add rate limiting per user
- Add audit logging for authentication events

Agent Validation:
- security-validator: ✅ PASSED (Risk: LOW)
- code-quality-analyzer: ✅ PASSED (Score: 4.3/5.0)

Fixes #123"

# Bad: Multiple unrelated changes
git commit -m "fix multiple issues and add new feature"
```

### Pre-commit Hook Configuration

**Mandatory Pre-commit Checks:**
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-executables-have-shebangs

  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: [--severity=warning]

  - repo: local
    hooks:
      - id: security-validation
        name: Security Validation
        entry: ./scripts/pre-commit-security-check.sh
        language: system
        pass_filenames: false

      - id: test-validation
        name: Test Validation
        entry: ./scripts/pre-commit-test-check.sh
        language: system
        pass_filenames: false
```

## Component Architecture

### System Architecture Overview

**Layer Architecture:**
```
┌─────────────────────────────────────────────┐
│              User Interface Layer           │
│  ┌─────────────┐  ┌─────────────────────────┐│
│  │ CLI Commands│  │   API Server + WebSocket ││
│  └─────────────┘  └─────────────────────────┘│
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│           Application Service Layer         │
│  ┌─────────────┐  ┌─────────────┐  ┌───────┐│
│  │Status       │  │Health       │  │Config ││
│  │Dashboard    │  │Monitor      │  │Manager││
│  └─────────────┘  └─────────────┘  └───────┘│
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│              Core VPN Layer                 │
│  ┌─────────────┐  ┌─────────────┐  ┌───────┐│
│  │VPN Manager  │  │VPN Connector│  │Profile││
│  │             │  │             │  │Manager││
│  └─────────────┘  └─────────────┘  └───────┘│
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│              Security Layer                 │
│  ┌─────────────┐  ┌─────────────┐  ┌───────┐│
│  │Secure       │  │Database     │  │Audit  ││
│  │Config       │  │Manager      │  │Logger ││
│  └─────────────┘  └─────────────┘  └───────┘│
└─────────────────────────────────────────────┘
```

### Component Development Guidelines

**1. Component Structure:**
```bash
src/component-name/
├── component-name                 # Main executable
├── lib/                          # Component libraries
│   ├── core.sh                   # Core functionality
│   ├── config.sh                 # Configuration handling
│   └── validation.sh             # Input validation
├── tests/                        # Component-specific tests
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   └── performance/              # Performance tests
└── docs/                         # Component documentation
    ├── README.md                 # Component overview
    └── API.md                    # API documentation
```

**2. Component Interface Standards:**
```bash
# Standard component interface
component-name [COMMAND] [OPTIONS] [ARGUMENTS]

# Standard commands (implement where applicable)
component-name --help          # Display help information
component-name --version       # Display version information
component-name --config=FILE   # Use specific configuration file
component-name --test          # Run component self-tests
component-name --validate      # Validate configuration/state
component-name --status        # Show component status
```

**3. Component Configuration Pattern:**
```bash
# Configuration loading pattern for all components
load_component_config() {
    local component_name="$1"
    local config_file="${CONFIG_DIR}/${component_name}.conf"

    # Load default configuration
    load_default_config "$component_name"

    # Override with system configuration
    if [[ -f "$config_file" ]]; then
        load_config_file "$config_file"
    fi

    # Override with user configuration
    local user_config="$HOME/.protonvpn-${component_name}.conf"
    if [[ -f "$user_config" ]]; then
        load_config_file "$user_config"
    fi

    # Validate final configuration
    validate_component_config "$component_name"
}
```

### Inter-Component Communication

**1. Message Passing:**
```bash
# Use standardized message format
send_component_message() {
    local target_component="$1"
    local message_type="$2"
    local message_data="$3"

    local message_file="/tmp/protonvpn-msg-${target_component}-$$"

    # Create message
    {
        echo "timestamp=$(date -Iseconds)"
        echo "source=$SCRIPT_NAME"
        echo "type=$message_type"
        echo "data=$message_data"
    } > "$message_file"

    # Set permissions
    chmod 600 "$message_file"
    chown protonvpn:protonvpn "$message_file"

    # Signal target component
    pkill -USR1 -f "$target_component"
}
```

**2. Shared State Management:**
```bash
# Use secure shared state pattern
update_shared_state() {
    local state_key="$1"
    local state_value="$2"

    # Update through secure database manager
    "$SECURE_DB_MANAGER" set "shared_state" "$state_key" "$state_value"

    # Notify interested components
    send_component_message "status-dashboard" "state_update" "$state_key"
    send_component_message "health-monitor" "state_update" "$state_key"
}
```

## Testing Framework

### Test Framework Architecture

**Test Runner Structure:**
```bash
tests/
├── run_tests.sh                  # Master test runner
├── test_framework.sh             # Test framework utilities
├── phase*/                       # Phase-specific test suites
│   ├── phase1_foundation_tests.sh
│   ├── phase2_core_tests.sh
│   └── ...
├── security/                     # Security test suites
│   ├── test_security_hardening.sh
│   ├── test_input_validation.sh
│   └── ...
├── performance/                  # Performance test suites
│   ├── benchmark_baseline.sh
│   ├── performance_regression.sh
│   └── ...
└── integration/                  # Integration test suites
    ├── api_integration_tests.sh
    ├── service_integration_tests.sh
    └── ...
```

### Writing Effective Tests

**Test Framework Functions:**
```bash
# Available assertion functions
assert_equals "$actual" "$expected" "Test description"
assert_not_equals "$actual" "$unexpected" "Test description"
assert_contains "$haystack" "$needle" "Test description"
assert_not_contains "$haystack" "$needle" "Test description"
assert_true "command_or_expression" "Test description"
assert_false "command_or_expression" "Test description"
assert_file_exists "/path/to/file" "Test description"
assert_file_not_exists "/path/to/file" "Test description"
assert_permission "600" "/path/to/file" "Test description"

# Performance testing functions
time_execution "command_to_time" max_seconds "Test description"
memory_usage_test "command_to_test" max_memory_mb "Test description"

# Security testing functions
test_input_sanitization "component" "malicious_input" "Test description"
test_file_permissions "/path/to/file" "expected_perms" "Test description"
```

**Performance Test Example:**
```bash
test_api_response_time() {
    local test_name="API Response Time"
    local max_response_time="0.1"  # 100ms

    # Start API server if not running
    if ! pgrep -f "api-server" > /dev/null; then
        start_test_api_server
    fi

    # Measure response time
    local start_time=$(date +%s.%N)
    local response
    response=$(curl -s "http://localhost:8080/api/v1/status")
    local end_time=$(date +%s.%N)

    # Calculate duration
    local duration=$(echo "$end_time - $start_time" | bc)

    # Validate response
    assert_contains "$response" "status" "$test_name - Valid response"

    # Validate performance
    if (( $(echo "$duration < $max_response_time" | bc -l) )); then
        print_test_result "PASS" "$test_name - Response time: ${duration}s"
    else
        print_test_result "FAIL" "$test_name - Response time: ${duration}s (exceeds ${max_response_time}s)"
        exit 1
    fi
}
```

### Security Testing

**Security Test Categories:**
```bash
# Input validation testing
test_input_validation() {
    local component="$1"

    # Test SQL injection attempts
    test_malicious_input "$component" "'; DROP TABLE users; --"

    # Test path traversal attempts
    test_malicious_input "$component" "../../../etc/passwd"

    # Test command injection attempts
    test_malicious_input "$component" "; rm -rf /"

    # Test XSS attempts
    test_malicious_input "$component" "<script>alert('xss')</script>"
}

# File permission testing
test_security_permissions() {
    assert_permission "700" "/etc/protonvpn" "Config directory permissions"
    assert_permission "600" "/etc/protonvpn/vpn-credentials.txt" "Credentials file permissions"
    assert_ownership "protonvpn:protonvpn" "/var/log/protonvpn" "Log directory ownership"
}

# Service security testing
test_service_security() {
    # Test that service user has no shell
    local shell=$(getent passwd protonvpn | cut -d: -f7)
    assert_equals "$shell" "/usr/sbin/nologin" "Service user has no shell"

    # Test systemd hardening features
    assert_systemd_feature "NoNewPrivileges" "yes" "NoNewPrivileges enabled"
    assert_systemd_feature "ProtectSystem" "strict" "ProtectSystem enabled"
}
```

## Security Development

### Security Development Lifecycle

**Security-First Development Process:**
1. **Threat Modeling**: Identify potential security threats
2. **Secure Design**: Design with security controls
3. **Secure Implementation**: Code with security best practices
4. **Security Testing**: Comprehensive security validation
5. **Security Review**: Agent-based security analysis
6. **Continuous Monitoring**: Ongoing security validation

### Secure Coding Practices

**1. Input Validation:**
```bash
# Always validate all input
validate_user_input() {
    local input="$1"
    local input_type="$2"

    case "$input_type" in
        "country_code")
            if [[ ! "$input" =~ ^[a-z]{2}$ ]]; then
                log_security_event "Invalid country code format: $input"
                return 1
            fi
            ;;
        "file_path")
            # Canonicalize path
            local canonical_path
            canonical_path=$(realpath "$input" 2>/dev/null) || {
                log_security_event "Invalid file path: $input"
                return 1
            }

            # Check for directory traversal
            if [[ "$canonical_path" != /etc/protonvpn/* ]] && [[ "$canonical_path" != /var/log/protonvpn/* ]]; then
                log_security_event "Path traversal attempt: $input -> $canonical_path"
                return 1
            fi
            ;;
        "port_number")
            if [[ ! "$input" =~ ^[0-9]+$ ]] || (( input < 1 || input > 65535 )); then
                log_security_event "Invalid port number: $input"
                return 1
            fi
            ;;
    esac

    return 0
}
```

**2. Secure Data Handling:**
```bash
# Handle sensitive data securely
handle_credentials() {
    local credentials_file="$1"

    # Verify file permissions
    local perms=$(stat -c %a "$credentials_file")
    if [[ "$perms" != "600" ]]; then
        log_security_event "Insecure credentials file permissions: $perms"
        return 1
    fi

    # Verify ownership
    local owner=$(stat -c %U:%G "$credentials_file")
    if [[ "$owner" != "protonvpn:protonvpn" ]]; then
        log_security_event "Incorrect credentials file ownership: $owner"
        return 1
    fi

    # Read credentials securely (don't echo to logs)
    local username password
    {
        IFS= read -r username
        IFS= read -r password
    } < "$credentials_file"

    # Validate credentials format
    if [[ -z "$username" || -z "$password" ]]; then
        log_security_event "Invalid credentials format"
        return 1
    fi

    # Export securely (will be cleared on exit)
    export VPN_USERNAME="$username"
    export VPN_PASSWORD="$password"
}
```

**3. Audit Logging:**
```bash
# Security event logging
log_security_event() {
    local event="$1"
    local severity="${2:-WARNING}"

    # Log to security log
    echo "$(date -Iseconds) [$severity] SECURITY: $event" >> "/var/log/protonvpn/security.log"

    # Log to audit log
    "$AUDIT_LOG_PROTECTOR" log_security_event "$event" "$severity"

    # Alert if critical
    if [[ "$severity" == "CRITICAL" ]]; then
        "$NOTIFICATION_MANAGER" notify "Security Alert" "$event" --urgency=critical
    fi
}
```

### Security Testing Requirements

**Mandatory Security Tests:**
1. **Input Validation**: All inputs must be validated and sanitized
2. **Authentication**: All API endpoints must require proper authentication
3. **Authorization**: Users must only access authorized resources
4. **Data Protection**: Sensitive data must be encrypted at rest
5. **Audit Logging**: All security events must be logged
6. **File Permissions**: All files must have secure permissions
7. **Service Isolation**: Services must run with minimal privileges

**Security Test Automation:**
```bash
# Run before every commit
./tests/security/test_security_hardening.sh

# Expected output: 17/17 tests passing ✅
```

## Performance Guidelines

### Performance Requirements

**Response Time Targets:**
- VPN Connection: < 2.0 seconds (requirement: < 30s)
- Fast Switching: < 2.0 seconds (requirement: < 20s)
- API Responses: < 100ms for status endpoints
- Health Checks: < 500ms for comprehensive checks
- Status Dashboard: < 50ms for cached data

**Resource Limits:**
- Memory Usage: < 25MB per service
- CPU Usage: < 5% average per service
- File Handles: < 512 per service
- Network Connections: < 10 concurrent per service

### Performance Optimization Techniques

**1. Caching Strategies:**
```bash
# Implement aggressive caching for performance data
cache_performance_data() {
    local server="$1"
    local latency="$2"
    local speed="$3"
    local cache_file="/tmp/vpn_performance.cache"

    # Create cache entry
    local cache_entry="$server:$latency:$speed:$(date +%s)"

    # Update cache (with locking)
    (
        flock -x 200

        # Remove old entries for this server
        grep -v "^$server:" "$cache_file" > "$cache_file.tmp" 2>/dev/null || true

        # Add new entry
        echo "$cache_entry" >> "$cache_file.tmp"

        # Atomically replace cache file
        mv "$cache_file.tmp" "$cache_file"

    ) 200>"$cache_file.lock"
}

# Use cached data when available
get_cached_performance() {
    local server="$1"
    local cache_file="/tmp/vpn_performance.cache"
    local max_age="${2:-3600}"  # 1 hour default

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    # Find cache entry
    local cache_entry
    cache_entry=$(grep "^$server:" "$cache_file" 2>/dev/null) || return 1

    # Parse cache entry
    local cached_server cached_latency cached_speed cached_time
    IFS=':' read -r cached_server cached_latency cached_speed cached_time <<< "$cache_entry"

    # Check if cache is still valid
    local current_time=$(date +%s)
    local age=$((current_time - cached_time))

    if (( age > max_age )); then
        return 1
    fi

    # Return cached data
    echo "$cached_latency:$cached_speed"
}
```

**2. Efficient Database Operations:**
```bash
# Batch database operations for efficiency
batch_database_update() {
    local updates=("$@")

    # Start transaction
    "$SECURE_DB_MANAGER" begin_transaction

    # Process all updates
    for update in "${updates[@]}"; do
        "$SECURE_DB_MANAGER" execute "$update"
    done

    # Commit transaction
    "$SECURE_DB_MANAGER" commit_transaction
}

# Use prepared statements equivalent
update_connection_history() {
    local server="$1"
    local status="$2"
    local timestamp="$3"

    # Use parameterized query to prevent injection and improve performance
    "$SECURE_DB_MANAGER" execute_prepared "INSERT_CONNECTION_HISTORY" "$server" "$status" "$timestamp"
}
```

**3. Resource-Efficient Monitoring:**
```bash
# Efficient system monitoring
monitor_system_resources() {
    # Use efficient commands for resource monitoring
    local memory_usage=$(ps -o rss= -p $$)
    local cpu_usage=$(ps -o %cpu= -p $$)

    # Only log if significant change (avoid excessive logging)
    local last_memory_usage=$(get_last_metric "memory_usage" 2>/dev/null || echo "0")
    local memory_diff=$((memory_usage - last_memory_usage))

    if (( memory_diff > 1024 )); then  # 1MB threshold
        log_performance_metric "memory_usage" "$memory_usage"
        set_last_metric "memory_usage" "$memory_usage"
    fi
}
```

### Performance Testing

**Automated Performance Testing:**
```bash
# Performance benchmark suite
run_performance_benchmarks() {
    echo "Running performance benchmarks..."

    # Connection speed benchmark
    benchmark_connection_speed

    # API response benchmark
    benchmark_api_responses

    # Memory usage benchmark
    benchmark_memory_usage

    # Database performance benchmark
    benchmark_database_operations

    echo "Performance benchmarks complete ✅"
}

benchmark_connection_speed() {
    local start_time=$(date +%s.%N)

    # Simulate connection (or use actual connection in safe test environment)
    vpn connect se --test-mode

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    # Validate against requirement
    local max_duration="2.0"
    if (( $(echo "$duration < $max_duration" | bc -l) )); then
        print_benchmark_result "PASS" "Connection Speed" "$duration" "$max_duration"
    else
        print_benchmark_result "FAIL" "Connection Speed" "$duration" "$max_duration"
        exit 1
    fi
}
```

## Contributing Guidelines

### Getting Started as a Contributor

**1. Read the Documentation:**
- Read this Developer Guide completely
- Review the User Guide and Deployment Guide
- Understand the project's TDD and Agent-driven approach

**2. Setup Development Environment:**
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/protonvpn-manager.git
cd protonvpn-manager

# Add upstream remote
git remote add upstream https://github.com/maxrantil/protonvpn-manager.git

# Setup development environment
./scripts/setup-dev-environment.sh

# Install pre-commit hooks
pre-commit install

# Run initial tests to verify setup
./tests/run_tests.sh --quick
```

**3. Find an Issue:**
- Look for issues labeled "good first issue" or "help wanted"
- Create an issue for new features or bugs you've discovered
- Discuss the approach in the issue before starting work

### Development Process

**1. Create Feature Branch:**
```bash
# Create GitHub issue first (mandatory)
# Get issue number (e.g., #456)

# Create and switch to feature branch
git checkout -b feat/issue-456-description
```

**2. Implement with TDD:**
```bash
# Follow RED-GREEN-REFACTOR cycle
# 1. Write failing test
# 2. Make test pass with minimal code
# 3. Refactor while keeping tests green
# 4. Repeat for each small functionality piece
```

**3. Agent Validation:**
```bash
# Run relevant agents based on changes
# - All changes: code-quality-analyzer, security-validator
# - Performance changes: performance-optimizer
# - User-facing changes: ux-accessibility-i18n-agent
# - Architectural changes: architecture-designer
```

**4. Pre-commit Validation:**
```bash
# Ensure all pre-commit hooks pass
pre-commit run --all-files

# Fix any issues before committing
```

**5. Commit and Push:**
```bash
# Make atomic commits with descriptive messages
git add specific-files
git commit -m "feat(component): add specific functionality

Detailed description of what was implemented and why.

Agent Validation:
- code-quality-analyzer: ✅ PASSED (Score: 4.3/5.0)
- security-validator: ✅ PASSED (Risk: LOW)

Fixes #456"

# Push to your fork
git push origin feat/issue-456-description
```

**6. Create Pull Request:**
```bash
# Create pull request on GitHub
# Use the PR template
# Reference the issue: "Fixes #456"
# Include agent validation results
# Provide clear description of changes
```

### Pull Request Requirements

**PR Checklist:**
- [ ] GitHub issue exists and is referenced
- [ ] All tests pass (including new tests for new functionality)
- [ ] Pre-commit hooks pass
- [ ] Agent validation completed with passing scores
- [ ] Security tests pass (17/17)
- [ ] Performance benchmarks meet requirements
- [ ] Documentation updated if needed
- [ ] Commit messages follow conventional commit format

**PR Template:**
```markdown
## Description
Brief description of the changes made.

## Related Issue
Fixes #456

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Performance improvement
- [ ] Security enhancement

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] End-to-end tests added/updated
- [ ] All tests pass

## Agent Validation Results
- [ ] code-quality-analyzer: ✅ PASSED (Score: X.X/5.0)
- [ ] security-validator: ✅ PASSED (Risk: LOW/MEDIUM)
- [ ] performance-optimizer: ✅ PASSED (No regressions)
- [ ] ux-accessibility-i18n-agent: ✅ PASSED (WCAG 2.1 AA) [if applicable]

## Security Checklist
- [ ] All security tests pass (17/17)
- [ ] Input validation implemented for new inputs
- [ ] Sensitive data handled securely
- [ ] Proper file permissions set
- [ ] Audit logging implemented for security events

## Performance Impact
- [ ] No performance regressions
- [ ] Performance benchmarks meet requirements
- [ ] Resource usage within limits

## Documentation
- [ ] Code comments added/updated
- [ ] User documentation updated [if applicable]
- [ ] API documentation updated [if applicable]
```

### Code Review Process

**Review Criteria:**
1. **Functionality**: Does the code work as intended?
2. **Tests**: Are there comprehensive tests that pass?
3. **Security**: Are there any security vulnerabilities?
4. **Performance**: Are there any performance regressions?
5. **Code Quality**: Is the code clean, readable, and maintainable?
6. **Architecture**: Does the code fit well with the existing architecture?
7. **Documentation**: Is the code properly documented?

**Reviewer Guidelines:**
- Focus on constructive feedback
- Test the functionality locally if possible
- Verify that all agent validations have been run
- Check that security tests pass
- Ensure performance benchmarks are met

## Troubleshooting Development Issues

### Common Development Problems

#### 1. Test Failures

**Unit Test Failures:**
```bash
# Debug individual tests
./tests/unit/test_specific_component.sh --debug

# Run specific test function
./tests/unit/test_specific_component.sh test_specific_function

# Check test data and setup
ls -la tests/data/
echo "TEST_MODE: $TEST_MODE"
```

**Integration Test Failures:**
```bash
# Check service status
sudo sv status /etc/service/protonvpn-*

# Verify test environment
./scripts/verify-test-environment.sh

# Check for port conflicts
netstat -tlnp | grep 8080
```

#### 2. Agent Validation Failures

**Code Quality Issues:**
```bash
# Run code quality analysis manually
shellcheck src/component-name

# Check for common issues
grep -r "TODO\|FIXME\|HACK" src/

# Verify test coverage
./scripts/check-test-coverage.sh component-name
```

**Security Validation Issues:**
```bash
# Run security tests individually
./tests/security/test_input_validation.sh
./tests/security/test_file_permissions.sh
./tests/security/test_service_security.sh

# Check for hardcoded credentials
grep -r "password\|secret\|key" src/ --exclude-dir=tests
```

**Performance Issues:**
```bash
# Run performance benchmarks
./tests/performance/benchmark_all.sh

# Profile specific component
time src/component-name --test-performance

# Check resource usage
ps aux | grep protonvpn
```

#### 3. Development Environment Issues

**Pre-commit Hook Failures:**
```bash
# Run pre-commit manually
pre-commit run --all-files

# Fix specific hook failures
pre-commit run shellcheck --all-files
pre-commit run trailing-whitespace --all-files

# Update pre-commit hooks
pre-commit autoupdate
```

**Configuration Issues:**
```bash
# Validate development configuration
config-manager validate config/development.conf

# Check file permissions
ls -la /etc/protonvpn/
sudo chown -R protonvpn:protonvpn /etc/protonvpn/

# Reset configuration to defaults
cp config/development.conf.example config/development.conf
```

### Getting Help

**Development Resources:**
1. **Documentation**: Check all documentation in `docs/`
2. **Issues**: Search existing GitHub issues
3. **Tests**: Look at existing tests for examples
4. **Code**: Study existing components for patterns

**Debugging Tools:**
```bash
# Enable debug mode
export VPN_DEBUG=1

# Verbose logging
export VPN_LOG_LEVEL=DEBUG

# Test mode (safer for development)
export TEST_MODE=1

# Component-specific debugging
component-name --debug --verbose
```

**Test Utilities:**
```bash
# Quick development validation
./scripts/dev-quick-check.sh

# Component-specific testing
./scripts/test-component.sh component-name

# Performance profiling
./scripts/profile-component.sh component-name
```

---

**Version:** 4.2.3 Production Ready
**Developer Guide Updated:** September 22, 2025
**Development Status:** Test-Driven with Agent Validation
**Next Steps:** See issues labeled "good first issue" for contribution opportunities

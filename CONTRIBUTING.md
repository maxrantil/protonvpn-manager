# Contributing to ProtonVPN Manager

Thank you for your interest in contributing to ProtonVPN Manager! This document provides guidelines for contributing to this project.

## Table of Contents

1. [Project Philosophy](#project-philosophy)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Code Standards](#code-standards)
5. [Testing Requirements](#testing-requirements)
6. [Pull Request Process](#pull-request-process)
7. [Reporting Bugs](#reporting-bugs)
8. [Suggesting Enhancements](#suggesting-enhancements)
9. [Security Vulnerabilities](#security-vulnerabilities)
10. [Code of Conduct](#code-of-conduct)

---

## Project Philosophy

ProtonVPN Manager follows the **Unix philosophy: "Do one thing and do it right."**

### Core Principles

1. **Simplicity First** - Prefer simple solutions over complex ones
2. **No Feature Creep** - Resist adding "nice to have" features
3. **Performance Over Features** - Fast, reliable connections matter most
4. **Maintainability** - Keep code readable and debuggable
5. **Less Code = Less Debt** - Minimize code footprint

### What We Accept

✅ **We welcome contributions that:**
- Fix bugs or security vulnerabilities
- Improve performance or reliability
- Enhance core VPN connection functionality
- Add essential tests or documentation
- Simplify existing code

❌ **We generally decline contributions that:**
- Add non-essential features
- Increase code complexity unnecessarily
- Duplicate existing functionality
- Add dependencies without strong justification
- Violate Unix philosophy principles

**When in doubt**, open an issue first to discuss whether a contribution aligns with project goals.

---

## Getting Started

### Prerequisites

- **Operating System**: Artix Linux or Arch Linux
- **Shell**: Bash 4.0+
- **Required Tools**:
  - `git`
  - `openvpn`
  - `curl` or `wget`
  - `shellcheck` (for code quality)
  - `pre-commit` (for git hooks)

### Setting Up Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/protonvpn-manager.git
   cd protonvpn-manager
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/maxrantil/protonvpn-manager.git
   ```

4. **Install pre-commit hooks** (MANDATORY):
   ```bash
   # Install pre-commit if not already installed
   pip install pre-commit

   # Install the git hooks
   pre-commit install
   ```

5. **Get ProtonVPN configuration files**:
   - Download OpenVPN configs from ProtonVPN
   - Place them in `locations/` directory
   - Create test credentials file (see Testing section)

6. **Verify setup**:
   ```bash
   # Run the test suite
   cd tests
   ./run_tests.sh

   # Should see: "All tests passed"
   ```

---

## Development Workflow

### 1. Create a Feature Branch

**NEVER commit directly to `master`**. Always work on a feature branch.

```bash
# Update your local master
git checkout master
git pull upstream master

# Create descriptive branch
git checkout -b fix/connection-timeout      # For bug fixes
git checkout -b feat/faster-server-select   # For features
git checkout -b chore/refactor-logging      # For refactoring
```

Branch naming convention:
- `fix/` - Bug fixes
- `feat/` - New features (must align with project philosophy)
- `chore/` - Refactoring, cleanup, documentation
- `test/` - Test additions or improvements

### 2. Make Your Changes

Follow [Code Standards](#code-standards) and [Testing Requirements](#testing-requirements).

### 3. Test Thoroughly

```bash
# Run full test suite
cd tests
./run_tests.sh

# All tests MUST pass before submitting PR
```

### 4. Commit Your Changes

```bash
# Stage changes
git add .

# Pre-commit hooks will run automatically
# Fix any issues before proceeding

# Commit with clear message
git commit -m "fix: resolve connection timeout in vpn-connector

- Handle SIGTERM gracefully during connection
- Add 30-second timeout for OpenVPN handshake
- Add timeout test to integration suite

Fixes #42"
```

**Commit message format**:
- First line: Brief summary (50 chars max)
- Blank line
- Detailed explanation (wrap at 72 chars)
- Reference related issues

**Pre-commit hooks** will automatically check:
- ShellCheck validation
- No AI attribution in code/commits
- File permissions
- Trailing whitespace

**NEVER bypass pre-commit hooks** with `--no-verify` unless explicitly approved by maintainers.

### 5. Push and Create Pull Request

```bash
# Push to your fork
git push origin fix/connection-timeout

# Create pull request on GitHub
# Use the PR template (if available)
```

---

## Code Standards

### Shell Scripting Standards

1. **POSIX Compatibility** where possible, Bash-specific features when necessary
2. **ShellCheck Compliant** - All code must pass `shellcheck`
3. **Set Strict Mode** (for new scripts):
   ```bash
   set -euo pipefail
   ```

4. **File Structure**:
   ```bash
   #!/usr/bin/env bash
   # ABOUTME: Brief description of what this script does

   # [Script content]
   ```

5. **Error Handling**:
   - Check return codes
   - Use meaningful error messages
   - Exit with appropriate codes (0=success, 1=error, 2=usage error)

6. **Code Style**:
   - Indent with 4 spaces (no tabs)
   - Use descriptive variable names
   - Comment complex logic
   - Keep functions small and focused
   - Use `readonly` for constants

### Code Quality Checklist

Before submitting, ensure your code:
- ✅ Passes `shellcheck src/your-file`
- ✅ Has clear variable names
- ✅ Includes error handling
- ✅ Has comments for complex logic
- ✅ Follows existing code style
- ✅ Adds no unnecessary dependencies
- ✅ Maintains or improves performance

---

## Testing Requirements

**Test-Driven Development (TDD) is MANDATORY** for all code changes.

### TDD Workflow

1. **RED** - Write a failing test first
2. **GREEN** - Write minimal code to make it pass
3. **REFACTOR** - Improve code while keeping tests green

**NEVER write production code without a failing test first.**

### Required Test Types

Every feature/fix must include:

1. **Unit Tests** - Test individual functions in isolation
2. **Integration Tests** - Test component interactions
3. **End-to-End Tests** - Test complete user workflows

### Test Organization

```
tests/
├── run_tests.sh              # Main test runner
├── test_framework.sh         # Test utilities
├── unit_tests.sh             # Unit tests
├── integration_tests.sh      # Integration tests
├── e2e_tests.sh             # End-to-end tests
└── realistic_connection_tests.sh  # Real connection tests
```

### Writing Tests

Tests use a simple bash test framework:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/test_framework.sh"

# Test function naming: test_<component>_<behavior>
test_vpn_connector_handles_timeout() {
    # Arrange
    export VPN_TIMEOUT=5

    # Act
    result=$(vpn-connector connect se 2>&1)

    # Assert
    assert_contains "$result" "Connection timeout"
}

# Run tests
run_tests
```

### Running Tests

```bash
# Run all tests
cd tests
./run_tests.sh

# Run specific test suite
./unit_tests.sh
./integration_tests.sh
./e2e_tests.sh

# Check test coverage
# Ensure new code is tested
```

### Test Quality Standards

- Tests must be **deterministic** (same input = same output)
- Tests must be **isolated** (no dependencies on external state)
- Tests must be **fast** (unit tests < 1 second each)
- Tests must have **clear failure messages**
- Tests must **clean up** after themselves (no leftover files/processes)

---

## Pull Request Process

### 1. Before Creating PR

Ensure you have:
- ✅ Written tests (TDD workflow)
- ✅ All tests pass locally
- ✅ Pre-commit hooks pass
- ✅ Code follows style guidelines
- ✅ Documentation updated (if needed)
- ✅ Commit messages are clear

### 2. Create Pull Request

1. **Push to your fork**:
   ```bash
   git push origin your-branch-name
   ```

2. **Open PR on GitHub**:
   - Use clear, descriptive title
   - Reference related issue: "Fixes #42" or "Relates to #42"
   - Describe WHAT changed and WHY
   - Include test results
   - Add screenshots/examples if applicable

3. **PR Description Template**:
   ```markdown
   ## Description
   Brief summary of changes

   ## Related Issue
   Fixes #42

   ## Changes Made
   - Change 1
   - Change 2

   ## Testing
   - [ ] All tests pass
   - [ ] Added new tests for changes
   - [ ] Tested manually

   ## Screenshots (if applicable)
   [Add screenshots]
   ```

### 3. Code Review Process

- Maintainers will review your PR
- Address feedback promptly
- Make requested changes in new commits (don't force-push during review)
- Respond to review comments
- Be patient and respectful

### 4. After Approval

- Maintainer will merge your PR (usually squash merge)
- Your contribution will be credited in release notes
- Branch will be deleted after merge

### 5. If PR is Declined

- Don't be discouraged!
- Understand the reasoning
- Consider opening an issue for discussion before implementation
- Project philosophy prioritizes simplicity over features

---

## Reporting Bugs

### Before Submitting a Bug Report

1. **Check existing issues** - Your bug might already be reported
2. **Try latest version** - Bug might be fixed in master branch
3. **Reproduce consistently** - Ensure bug is reproducible
4. **Gather information** - Collect logs, system info, steps to reproduce

### Creating a Bug Report

Open an issue with:

**Title**: Clear, specific summary (e.g., "VPN fails to connect to Swedish servers")

**Description**:
```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Run `./src/vpn connect se`
2. Wait for connection
3. See error message

## Expected Behavior
VPN should connect to Swedish server

## Actual Behavior
Connection fails with "No route to host"

## Environment
- OS: Artix Linux (kernel 6.1.0)
- OpenVPN version: 2.6.5
- protonvpn-manager version/commit: abc123

## Logs
```
[Paste relevant log output]
```

## Additional Context
Any other relevant information
```

### Bug Priority Guidelines

- **Critical** - Security vulnerabilities, data loss, crashes
- **High** - Major functionality broken, no workarounds
- **Medium** - Functionality impaired, workarounds exist
- **Low** - Minor issues, cosmetic problems

---

## Suggesting Enhancements

### Before Suggesting Enhancement

1. **Check project philosophy** - Does it align with "do one thing right"?
2. **Search existing issues** - Might already be discussed
3. **Consider necessity** - Is it essential or "nice to have"?
4. **Think about complexity** - Will it increase maintenance burden?

### Creating Enhancement Request

Open an issue with:

**Title**: Clear summary starting with "Enhancement:" (e.g., "Enhancement: Add connection retry logic")

**Description**:
```markdown
## Enhancement Description
Clear description of proposed enhancement

## Problem It Solves
What problem does this solve? (Essential: should solve real problem, not add features)

## Proposed Solution
How would you implement this?

## Alternatives Considered
What other solutions did you consider?

## Impact on Project Philosophy
How does this align with "do one thing right"?

## Implementation Complexity
Estimated complexity (low/medium/high)

## Additional Context
Any other relevant information
```

### Enhancement Acceptance Criteria

Enhancements are more likely to be accepted if they:
- ✅ Solve real, common problems
- ✅ Maintain simplicity
- ✅ Don't add dependencies
- ✅ Improve core VPN functionality
- ✅ Have minimal maintenance burden

Enhancements likely to be declined:
- ❌ "Nice to have" features
- ❌ Increase complexity significantly
- ❌ Duplicate existing functionality
- ❌ Add non-essential dependencies
- ❌ Violate Unix philosophy

---

## Security Vulnerabilities

**DO NOT** open a public issue for security vulnerabilities.

See [SECURITY.md](SECURITY.md) for:
- How to report vulnerabilities privately
- What to include in security reports
- Response timeline
- Disclosure policy

**Security issues**: Email rantil@pm.me with subject `[SECURITY] protonvpn-manager vulnerability`

---

## Code of Conduct

### Our Standards

We are committed to providing a welcoming and inclusive environment.

**Expected behavior**:
- ✅ Be respectful and professional
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what's best for the project
- ✅ Show empathy toward other contributors

**Unacceptable behavior**:
- ❌ Harassment, discrimination, or personal attacks
- ❌ Trolling, insulting comments, or political arguments
- ❌ Publishing others' private information
- ❌ Spamming or self-promotion

### Enforcement

- Minor violations: Warning from maintainers
- Repeated violations: Temporary ban
- Severe violations: Permanent ban

### Reporting Issues

Report Code of Conduct violations to: rantil@pm.me

All reports will be handled confidentially.

---

## Questions?

- **General questions**: Open a [GitHub Discussion](https://github.com/maxrantil/protonvpn-manager/discussions)
- **Bug reports**: Open an [issue](https://github.com/maxrantil/protonvpn-manager/issues)
- **Security**: Email rantil@pm.me (see [SECURITY.md](SECURITY.md))
- **Other**: Email rantil@pm.me

---

## Recognition

Contributors are recognized in:
- GitHub contributor list
- Release notes (for significant contributions)
- SECURITY.md acknowledgments (for security researchers)

Thank you for contributing to ProtonVPN Manager! 🎉

---

**Last Updated**: 2025-10-15
**Version**: 1.0

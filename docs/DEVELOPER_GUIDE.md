# Simple VPN Manager - Developer Guide

**Version:** vpn-simple branch
**Last Updated:** September 28, 2025
**Development Status:** Simple Bash Development - Unix Philosophy

## Table of Contents

1. [Development Overview](#development-overview)
2. [Development Environment](#development-environment)
3. [Code Standards](#code-standards)
4. [Component Development](#component-development)
5. [Testing](#testing)
6. [Git Workflow](#git-workflow)
7. [Contributing](#contributing)
8. [Troubleshooting](#troubleshooting)

## Development Overview

### Project Philosophy

This project follows the **Unix philosophy**: "Do one thing and do it right."

**Core Principles:**
- **Simplicity First**: Prefer simple solutions over clever ones
- **Minimal Dependencies**: Only essential external tools (OpenVPN, bash, curl)
- **Process Safety**: Bulletproof VPN process management
- **Performance Focus**: Fast connections matter more than features
- **No Feature Creep**: Resist adding "nice to have" features

### What This Project IS
- Simple VPN connection management
- Intelligent server selection
- Performance testing and optimization
- Clean process management
- Basic error handling

### What This Project IS NOT
- ❌ Enterprise monitoring system
- ❌ API server or web interface
- ❌ Complex configuration management
- ❌ Background service framework
- ❌ Security compliance framework
- ❌ Notification system

### Technology Stack

**Core Technologies:**
- **Shell Scripting**: Bash 4.0+ (primary language)
- **VPN**: OpenVPN (only supported VPN protocol)
- **Network**: curl for HTTP requests and speed testing
- **System**: Standard Unix tools (ping, ps, pkill, etc.)

**What We DON'T Use:**
- ❌ Python, Node.js, or other runtime environments
- ❌ Databases (SQLite, PostgreSQL, etc.)
- ❌ Web frameworks or HTTP servers
- ❌ Complex configuration formats (TOML, YAML)
- ❌ Service management frameworks
- ❌ Monitoring or alerting systems

## Development Environment

### Prerequisites

**Essential Tools:**
```bash
# Artix/Arch Linux
sudo pacman -S bash openvpn curl bc

# Development tools
sudo pacman -S git shellcheck

# Optional for enhanced development
sudo pacman -S iproute2 ping
```

**Development Setup:**
```bash
# Clone the repository
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
git checkout vpn-simple

# Verify your setup
./src/vpn help
```

### Code Editor Setup

**Recommended Settings:**
- Use 4-space indentation for bash scripts
- Enable shellcheck integration
- Set line length to 88 characters (matches project standard)

**VS Code Extensions:**
- Bash IDE
- ShellCheck
- Bash Debug

**Vim/Neovim:**
```vim
" .vimrc settings for bash development
set expandtab
set tabstop=4
set shiftwidth=4
set textwidth=88
```

## Code Standards

### Bash Scripting Standards

**File Headers:**
Every script must start with:
```bash
#!/bin/bash
# ABOUTME: Brief description of what this script does
# ABOUTME: Additional context if needed
```

**Function Structure:**
```bash
# Function with clear name and purpose
function_name() {
    local param1="$1"
    local param2="$2"

    # Input validation
    [[ -z "$param1" ]] && { echo "Error: param1 required"; return 1; }

    # Function logic
    echo "Result: $param1"
}
```

**Error Handling:**
```bash
# Always check command success
if ! command_that_might_fail; then
    echo "Error: Command failed"
    return 1
fi

# Use && and || for simple cases
command_success && echo "Success" || { echo "Failed"; return 1; }
```

**Variable Naming:**
```bash
# Use descriptive names
vpn_status="connected"
server_name="se-45.protonvpn.udp"
connection_time="14:30:15"

# Use UPPER_CASE for constants
VPN_DIR="$(dirname "$(realpath "$0")")"
DEFAULT_TIMEOUT=30
```

### Code Organization

**Component Structure:**
Each component should have:
1. Clear purpose and responsibility
2. Minimal dependencies on other components
3. Error handling and logging
4. Input validation
5. Help/usage information

**File Naming:**
- Use descriptive names: `vpn-manager`, `vpn-connector`
- No file extensions for executable scripts
- Use hyphens, not underscores: `best-vpn-profile`

### Documentation Standards

**Inline Comments:**
```bash
# Explain WHY, not WHAT
# Check if VPN is already running to prevent conflicts
if pgrep -f "openvpn.*protonvpn" > /dev/null; then
    echo "VPN already running"
    return 1
fi
```

**Function Documentation:**
```bash
# Connect to a VPN server with retry logic
# Arguments:
#   $1 - server name (required)
#   $2 - max attempts (optional, default: 3)
# Returns:
#   0 - success
#   1 - connection failed
connect_to_server() {
    # Function implementation
}
```

## Component Development

### Core Components (6 total)

#### 1. Main Interface (`vpn`)
**Purpose**: Command routing and user interaction
**Size**: ~331 lines
**Key Functions**: Command parsing, help display, component coordination

#### 2. VPN Manager (`vpn-manager`)
**Purpose**: Process lifecycle management
**Size**: ~875 lines
**Key Functions**: Start/stop OpenVPN, status checking, cleanup

#### 3. VPN Connector (`vpn-connector`)
**Purpose**: Server selection and connection logic
**Size**: ~968 lines
**Key Functions**: Server discovery, country filtering, connection attempts

#### 4. Best Profile Engine (`best-vpn-profile`)
**Purpose**: Performance testing
**Size**: ~104 lines
**Key Functions**: Latency testing, speed testing, server ranking

#### 5. Error Handler (`vpn-error-handler`)
**Purpose**: Centralized error handling
**Size**: ~275 lines
**Key Functions**: Error message formatting, recovery suggestions

#### 6. Config Fixer (`fix-ovpn-configs`)
**Purpose**: OpenVPN config validation
**Size**: ~280 lines
**Key Functions**: Config file validation, common issue fixing

### Adding New Functionality

**Before Adding Features:**
1. Ask: "Does this align with Unix philosophy?"
2. Ask: "Is this essential for VPN management?"
3. Ask: "Can this be done in an existing component?"
4. Consider: "Will this add significant complexity?"

**If Feature is Essential:**
1. Create minimal implementation
2. Add to existing component if possible
3. Create new component only if absolutely necessary
4. Keep component under 1000 lines

**Code Addition Guidelines:**
```bash
# Add new function to existing component
new_feature() {
    local input="$1"

    # Input validation
    [[ -z "$input" ]] && { echo "Error: input required"; return 1; }

    # Minimal implementation
    echo "Feature result: $input"
}
```

## Testing

### Manual Testing

**Basic Testing Workflow:**
```bash
# Test all core functions
./src/vpn help
./src/vpn status
./src/vpn list

# Test connection cycle
./src/vpn connect se
./src/vpn status
./src/vpn disconnect

# Test performance features
./src/vpn best
./src/vpn test
```

**Component Testing:**
```bash
# Test individual components
./src/vpn-manager status
./src/vpn-connector list_servers
./src/best-vpn-profile test se-45
```

### Error Testing

**Test Error Conditions:**
```bash
# Test missing dependencies
mv /usr/bin/openvpn /usr/bin/openvpn.backup
./src/vpn connect se  # Should gracefully fail

# Test missing config files
mv locations locations.backup
./src/vpn connect se  # Should report no configs

# Test permission issues
chmod 000 credentials.txt
./src/vpn connect se  # Should report permission error
```

### Performance Testing

**Basic Performance Tests:**
```bash
# Time connection speed
time ./src/vpn connect se

# Time status checks
time ./src/vpn status

# Time server testing
time ./src/vpn best
```

### No Complex Testing Framework

This project intentionally avoids:
- ❌ Unit testing frameworks
- ❌ Integration testing suites
- ❌ Automated test pipelines
- ❌ Code coverage tools
- ❌ Performance benchmarking suites

Testing is manual and focused on real-world usage patterns.

## Git Workflow

### Branch Strategy

**Main Branches:**
- `vpn-simple`: Main development branch (current simplified version)
- `master`: Enterprise version (archived, for reference only)

**Feature Development:**
```bash
# Create feature branch from vpn-simple
git checkout vpn-simple
git pull origin vpn-simple
git checkout -b fix/server-selection-bug

# Make changes
# Test changes
# Commit changes

# Push and create PR
git push origin fix/server-selection-bug
```

### Commit Guidelines

**Commit Message Format:**
```
type: brief description

- Detailed explanation if needed
- Keep lines under 72 characters
- Use present tense
```

**Commit Types:**
- `fix:` Bug fixes
- `feat:` New features (rare, must align with philosophy)
- `docs:` Documentation updates
- `refactor:` Code improvements without behavior changes
- `chore:` Maintenance tasks

**Example Commits:**
```
fix: prevent multiple OpenVPN processes from starting

- Add process check before starting new connection
- Improve error message when VPN already running
- Add cleanup on unexpected exit

feat: add country-specific server filtering

- Support connecting to specific countries (se, dk, nl)
- Maintain existing random server selection as default
- Keep implementation simple and focused
```

### Pull Request Guidelines

**Before Creating PR:**
1. Test all changed functionality manually
2. Verify no new dependencies introduced
3. Check that code follows project philosophy
4. Update documentation if needed

**PR Description Template:**
```markdown
## Changes
Brief description of what was changed and why.

## Testing
- [ ] Manual testing completed
- [ ] No new dependencies added
- [ ] Follows Unix philosophy
- [ ] Documentation updated (if needed)

## Type of Change
- [ ] Bug fix
- [ ] New feature (essential only)
- [ ] Documentation update
- [ ] Code cleanup/refactor
```

## Contributing

### Getting Started

1. **Read the Philosophy**: Understand Unix philosophy and project goals
2. **Use the Tool**: Use the VPN manager daily to understand its purpose
3. **Study the Code**: Read through all 6 components to understand architecture
4. **Start Small**: Begin with bug fixes or small improvements

### Contribution Guidelines

**Good Contributions:**
- Bug fixes that improve reliability
- Performance improvements that reduce connection time
- Error handling improvements
- Documentation clarifications
- Code simplification and cleanup

**Bad Contributions:**
- Adding APIs or web interfaces
- Complex configuration systems
- Background services or daemons
- Monitoring or alerting features
- Database integration
- Notification systems

### Code Review Process

**Self-Review Checklist:**
- [ ] Code follows Unix philosophy
- [ ] No unnecessary complexity added
- [ ] No new dependencies introduced
- [ ] Error handling is appropriate
- [ ] Code is readable and well-commented
- [ ] Manual testing completed

## Troubleshooting

### Development Issues

#### "Script won't run"
**Check:**
```bash
# File permissions
ls -la src/vpn
chmod +x src/vpn

# Shebang line
head -1 src/vpn

# Bash availability
which bash
```

#### "Command not found" errors
**Check:**
```bash
# Required commands
which openvpn curl ping

# Install missing dependencies
sudo pacman -S openvpn curl
```

#### "Shellcheck warnings"
**Common Issues:**
```bash
# Quote variables
echo "$variable"  # Good
echo $variable    # Bad

# Check command success
if command; then  # Good
command && echo   # Usually okay
command; echo     # Bad (doesn't check success)
```

### Performance Issues

#### "Slow connection times"
**Debug:**
```bash
# Test individual components
time ./src/best-vpn-profile test se-45
time ./src/vpn-connector connect se-45

# Check network connectivity
ping google.com
ping se-45.protonvpn.com
```

#### "Performance testing takes too long"
**Optimize:**
```bash
# Reduce number of test servers
# Keep only configs for preferred countries in locations/

# Clear performance cache
rm /tmp/vpn_performance.cache
```

### Development Environment Issues

#### "Git conflicts with master branch"
**Avoid:**
- Don't merge from master to vpn-simple
- Don't develop on master branch
- Keep branches separate and focused

#### "Code doesn't match project style"
**Fix:**
- Use 4-space indentation
- Keep lines under 88 characters
- Use descriptive variable names
- Add appropriate comments

---

**Simple VPN Manager** - Simple code for simple needs.
**Development Principle**: Do one thing and do it right.
**Code Quality**: Readable, maintainable, focused.
**Philosophy**: Unix tools for Unix people.

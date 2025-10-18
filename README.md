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

- **Operating System**: Artix Linux or Arch Linux
- **OpenVPN**: Install with `sudo pacman -S openvpn`
- **ProtonVPN Account**: Free or paid account at [protonvpn.com](https://protonvpn.com)
- **Basic Tools**: curl, grep, awk (usually pre-installed)

### Step-by-Step Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
```

#### 2. Download ProtonVPN Configuration Files

**Option A: Download via ProtonVPN Website (Recommended)**

1. Log in to your ProtonVPN account at https://account.protonvpn.com
2. Go to **Downloads** → **OpenVPN configuration files**
3. Select platform: **Linux**
4. Select protocol: **UDP** (faster) or **TCP** (more reliable)
5. Download configuration files for your desired servers
   - **For all servers**: Download "All Configurations" ZIP file
   - **For specific countries**: Download individual country files
6. Extract configuration files to the repository:
   ```bash
   # Example: Extract all configs
   unzip ~/Downloads/protonvpn-configs.zip -d locations/

   # Or copy individual files
   cp ~/Downloads/*.ovpn locations/
   ```

**Option B: Download via Command Line**

```bash
# Create locations directory
mkdir -p locations

# Download example (replace with your actual ProtonVPN URLs)
# Note: ProtonVPN requires login, so manual download is usually easier
curl -o locations/se-01.protonvpn.com.udp.ovpn \
  https://account.protonvpn.com/downloads/...
```

#### 3. Set Up Credentials

Create a credentials file with your ProtonVPN OpenVPN username and password:

> ⚠️ **CRITICAL: OpenVPN credentials are DIFFERENT from your ProtonVPN account password!** ⚠️
>
> **Do NOT use your regular ProtonVPN login credentials.** You need special OpenVPN credentials.
>
> **How to find your OpenVPN credentials:**
> 1. Log into https://account.protonvpn.com
> 2. Go to **Account** → **OpenVPN / IKEv2 username**
> 3. Your OpenVPN username looks like: `username+pm`
> 4. Click "Show" or "Copy" to get your OpenVPN password

```bash
# Create config directory
mkdir -p ~/.config/vpn

# Create credentials file
# NOTE: Use your OpenVPN/IKEv2 credentials, NOT your ProtonVPN account password
cat > ~/.config/vpn/vpn-credentials.txt << 'EOF'
your-openvpn-username
your-openvpn-password
EOF

# Secure the file (IMPORTANT!)
chmod 600 ~/.config/vpn/vpn-credentials.txt
```

**Finding Your OpenVPN Credentials:**
1. Log in to ProtonVPN account at https://account.protonvpn.com
2. Go to **Account** → **OpenVPN / IKEv2 username**
3. Your OpenVPN username will be displayed (usually looks like: `username+pm`)
4. Your OpenVPN password is different from your account password
   - Click "Copy" or "Show" to get your OpenVPN password

#### 4. Verify Installation

```bash
# Check if OpenVPN configs are present
ls -la locations/*.ovpn | head -5

# Should show files like:
# se-01.protonvpn.com.udp.ovpn
# us-ny-01.protonvpn.com.udp.ovpn
# etc.

# Verify credentials file
stat -c "%a" ~/.config/vpn/vpn-credentials.txt

# Should output: 600 (owner read/write only)
```

#### 5. Test Connection

```bash
# Try connecting to any server
./src/vpn connect

# Or connect to specific country (e.g., Sweden)
./src/vpn connect se

# Check connection status
./src/vpn status

# You should see:
# Status: Connected
# Server: se-01.protonvpn.com
# External IP: [ProtonVPN IP address]
```

#### 6. Optional: Install System-Wide

For convenience, you can install scripts to `/usr/local/bin`:

```bash
# Run the install script
sudo ./install.sh

# Now you can use 'vpn' from anywhere
vpn connect
vpn status
```

### Directory Structure After Installation

```
protonvpn-manager/
├── locations/               # ProtonVPN OpenVPN configs (you create this)
│   ├── se-01.protonvpn.com.udp.ovpn
│   ├── us-ny-01.protonvpn.com.udp.ovpn
│   └── ... (more .ovpn files)
├── src/                     # VPN management scripts
│   ├── vpn                  # Main CLI interface
│   ├── vpn-manager          # Process management
│   ├── vpn-connector        # Connection logic
│   └── ... (other scripts)
├── tests/                   # Test suite
└── ~/.config/vpn/           # User configuration (you create this)
    └── vpn-credentials.txt      # Your ProtonVPN credentials (600 permissions)
```

### Configuration Tips

**Multiple Credential Files:**
If you want to use different accounts, you can specify credentials:
```bash
# Use default credentials
./src/vpn connect

# Use specific credentials file
CREDENTIALS_FILE=~/.config/vpn/work-vpn-credentials.txt ./src/vpn connect
```

**Custom Config Directory:**
```bash
# Use different config directory
LOCATIONS_DIR=/path/to/custom/configs ./src/vpn connect
```

**Testing Without Installing:**
```bash
# Run directly from repository
cd /path/to/protonvpn-manager
./src/vpn connect se
```

### First Time Setup Complete!

You're ready to use ProtonVPN Manager. Try these commands:

```bash
# Find and connect to best server
./src/vpn best

# Check status
./src/vpn status

# Disconnect
./src/vpn disconnect

# View all commands
./src/vpn help
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

## Troubleshooting

### Connection Issues

#### VPN Won't Connect
```bash
# Check if OpenVPN is installed
which openvpn

# Check if profile files exist
ls -la locations/

# Try connecting with verbose output
./src/vpn connect se 2>&1 | tee connection-debug.log

# Check if another VPN process is running
./src/vpn status
```

**Common causes**:
- Missing OpenVPN configuration files in `locations/` directory
- Incorrect credentials in credentials file
- Another VPN process already running
- Network connectivity issues

**Solution**: Run `./src/vpn cleanup` to reset VPN state, then try again.

#### Connection Drops Frequently
```bash
# Check connection stability
./src/vpn health

# Test current server performance
./src/vpn test

# Try different server
./src/vpn best
```

**Common causes**:
- Server overloaded or maintenance
- Network instability
- DNS resolution issues

**Solution**: Switch to a different server using `./src/vpn best`.

#### "No Servers Found" Error
```bash
# Verify configuration files
ls -la locations/*.ovpn locations/*.conf

# Check file permissions
chmod 644 locations/*.ovpn

# Re-download configs from ProtonVPN
```

**Common causes**:
- Empty `locations/` directory
- Incorrect file extensions (must be .ovpn or .conf)
- File permission issues

**Solution**: Download OpenVPN configs from ProtonVPN and place in `locations/` directory.

### Credential Issues

#### "Authentication Failed" Error
```bash
# Check credentials file exists
ls -la ~/.config/vpn/vpn-credentials.txt

# Verify credentials format (should be 2 lines: username, then password)
cat ~/.config/vpn/vpn-credentials.txt

# Check file permissions (should be 600)
stat -c "%a" ~/.config/vpn/vpn-credentials.txt
```

**Common causes**:
- Wrong username or password
- Credentials file has wrong format
- ProtonVPN account issue

**Solution**:
1. Log in to ProtonVPN web interface to verify credentials
2. Update `~/.config/vpn/vpn-credentials.txt` with correct credentials
3. Ensure file has exactly 2 lines (username on line 1, password on line 2)
4. Set correct permissions: `chmod 600 ~/.config/vpn/vpn-credentials.txt`

#### "Credentials File Not Found"
```bash
# Create credentials directory
mkdir -p ~/.config/vpn

# Create credentials file
cat > ~/.config/vpn/vpn-credentials.txt << EOF
your-protonvpn-username
your-protonvpn-password
EOF

# Secure permissions
chmod 600 ~/.config/vpn/vpn-credentials.txt
```

### Permission Issues

#### "Permission Denied" When Connecting
```bash
# VPN operations require sudo privileges
# You'll be prompted for password when connecting

# Verify sudo is configured
sudo -v

# Check if openvpn is accessible
which openvpn
```

**Common causes**:
- User not in sudoers
- OpenVPN not installed

**Solution**: Ensure your user has sudo privileges and OpenVPN is installed (`sudo pacman -S openvpn`).

#### "Lock File Permission Denied"
```bash
# Clean up lock files
./src/vpn cleanup

# If that fails, manually remove
rm -f "$XDG_RUNTIME_DIR/vpn/"*.lock /tmp/vpn_*.lock 2>/dev/null
```

### DNS and Network Issues

#### DNS Not Resolving After Disconnect
```bash
# Emergency network reset
./src/vpn cleanup

# Restart NetworkManager (if using)
sudo systemctl restart NetworkManager

# Verify DNS resolution
dig google.com
```

**Common causes**:
- DNS settings not restored after disconnect
- NetworkManager not restarted

**Solution**: Run `./src/vpn cleanup` which safely resets network configuration.

#### IP Not Changing (DNS Leak)
```bash
# Check external IP before connecting
curl -s https://ifconfig.me

# Connect to VPN
./src/vpn connect

# Check external IP after connecting
./src/vpn status

# Verify DNS leak
dig +short myip.opendns.com @resolver1.opendns.com
```

**Common causes**:
- DNS leak in OpenVPN configuration
- Split tunneling enabled

**Solution**: Ensure your OpenVPN configs include proper DNS settings.

### Performance Issues

#### Slow Connection Speeds
```bash
# Test current server performance
./src/vpn test

# Find best performing server
./src/vpn best

# Check if server is overloaded
./src/vpn health
```

**Common causes**:
- Server overloaded
- Geographic distance
- Network congestion

**Solution**: Use `./src/vpn best` to find optimal server.

#### Connection Takes Too Long
```bash
# Use fast connect (cached results)
./src/vpn fast se

# Clear cache and re-test
rm -f "$XDG_CACHE_HOME/vpn/"*.cache
./src/vpn best
```

### Log Analysis

#### View Recent Activity
```bash
# View last 50 log entries
./src/vpn logs

# View last 100 log entries
./src/vpn logs 100

# Search logs for errors
./src/vpn logs 500 | grep -i error

# View full log file
less /tmp/vpn_simple.log
```

#### Enable Verbose Logging
```bash
# Set environment variable for verbose output
export VPN_DEBUG=1
./src/vpn connect se 2>&1 | tee debug.log
```

### Still Having Issues?

1. **Check the logs**: `./src/vpn logs 100`
2. **Run health check**: `./src/vpn health`
3. **Clean state**: `./src/vpn cleanup`
4. **Test manually**: Run OpenVPN directly to isolate issues
5. **Open an issue**: [GitHub Issues](https://github.com/maxrantil/protonvpn-manager/issues) with:
   - Steps to reproduce
   - Log output
   - System information (`uname -a`, `openvpn --version`)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Max Rantil

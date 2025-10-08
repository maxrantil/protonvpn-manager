# Simple VPN Manager - User Guide

**Version:** vpn-simple branch
**Last Updated:** September 28, 2025
**System Status:** Simple, Focused VPN Tool

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Command Reference](#command-reference)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Tips & Best Practices](#tips--best-practices)

## Overview

Simple VPN Manager is a focused, lightweight VPN management tool for Artix/Arch Linux systems. It follows the Unix philosophy: **"Do one thing and do it right."**

### What It Does
- **Smart Server Selection**: Automatically finds the best performing VPN server
- **Safe Process Management**: Prevents multiple OpenVPN processes and handles cleanup
- **Performance Testing**: Tests server latency and speed for optimal connections
- **Clear Status Information**: Shows connection state, external IP, and performance
- **Configuration Validation**: Validates and fixes OpenVPN configuration files

### What It Does NOT Do
- ❌ Complex APIs or web interfaces
- ❌ Background services or daemons
- ❌ Enterprise security frameworks
- ❌ Monitoring dashboards
- ❌ Database management
- ❌ Notification systems

### Performance
- **Connection Time**: < 2 seconds
- **Server Testing**: < 5 seconds for best server selection
- **Memory Usage**: < 10MB total
- **Dependencies**: Only essential tools (OpenVPN, bash, curl)

## Installation

### Prerequisites

You need these basic packages installed:

```bash
# Artix/Arch Linux - Essential packages
sudo pacman -S openvpn curl

# Optional for enhanced functionality
sudo pacman -S bc iproute2
```

### Setup

1. **Clone the repository**:
```bash
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
git checkout vpn-simple  # Use the simplified version
```

2. **Add your VPN credentials**:
```bash
# Create credentials file with your ProtonVPN credentials
echo "your_username" > credentials.txt
echo "your_password" >> credentials.txt
chmod 600 credentials.txt
```

3. **Place OpenVPN config files**:
```bash
# Download OpenVPN configs from ProtonVPN
# Place them in the locations/ directory
# Example structure:
# locations/se-45.protonvpn.udp.ovpn
# locations/dk-49.protonvpn.udp.ovpn
# etc.
```

4. **Test the installation**:
```bash
./src/vpn help
```

## Quick Start

### Basic Usage

```bash
# Show help and available commands
./src/vpn help

# Connect to best performing server
./src/vpn best

# Connect to specific country (Sweden)
./src/vpn connect se

# Check current status
./src/vpn status

# Disconnect
./src/vpn disconnect
```

### Your First Connection

1. **Connect to the best server**:
```bash
./src/vpn best
```

2. **Check your status**:
```bash
./src/vpn status
```

3. **When done, disconnect**:
```bash
./src/vpn disconnect
```

## Command Reference

### Connection Commands

#### `vpn connect [country]`
Connect to a VPN server.
- Without country: connects to random server
- With country: connects to specified country (se, dk, nl, etc.)

```bash
./src/vpn connect         # Connect to any server
./src/vpn connect se      # Connect to Sweden
./src/vpn connect dk      # Connect to Denmark
```

#### `vpn disconnect`
Disconnect from VPN and clean up processes.

```bash
./src/vpn disconnect
```

#### `vpn reconnect`
Disconnect and reconnect to current server.

```bash
./src/vpn reconnect
```

#### `vpn best`
Connect to the best performing server based on testing.

```bash
./src/vpn best
```

### Information Commands

#### `vpn status`
Show current VPN connection status.

```bash
./src/vpn status              # Standard output
./src/vpn status --accessible # Screen reader friendly (plain text)
```

Example output:
```
VPN Status: Connected
Server: se-48.protonvpn.udp
External IP: 185.159.157.48
Connected since: 14:30:15
```

#### `vpn list`
List available VPN servers.

```bash
./src/vpn list
```

#### `vpn test`
Test current connection performance.

```bash
./src/vpn test
```

### Server Selection Commands

#### `vpn fast [country]`
Quick connect using cached performance results.

```bash
./src/vpn fast         # Fast connect to best cached server
./src/vpn fast se      # Fast connect to best Sweden server
```

### System Commands

#### `vpn cleanup`
Clean up VPN processes and routing.

```bash
./src/vpn cleanup
```

#### `vpn kill`
Force kill all VPN processes (emergency use).

```bash
./src/vpn kill
```

#### `vpn health`
Check system health and VPN status.

```bash
./src/vpn health
```

### Help Commands

#### `vpn help`
Show help information and command list.

```bash
./src/vpn help
```

#### `vpn version`
Show version information.

```bash
./src/vpn version
```

## Configuration

### OpenVPN Configuration Files

Place your ProtonVPN OpenVPN configuration files in the `locations/` directory:

```
locations/
├── se-45.protonvpn.udp.ovpn    # Sweden servers
├── se-46.protonvpn.udp.ovpn
├── dk-49.protonvpn.udp.ovpn    # Denmark servers
├── dk-50.protonvpn.udp.ovpn
└── ...
```

### Credentials File

Create a `credentials.txt` file in the project root:

```
your_protonvpn_username
your_protonvpn_password
```

**Important**: Set secure permissions:
```bash
chmod 600 credentials.txt
```

### Performance Cache

The system caches server performance in `/tmp/vpn_performance.cache`. This file is automatically managed but you can delete it to force fresh testing:

```bash
rm /tmp/vpn_performance.cache
```

## Troubleshooting

### Common Issues

#### "No OpenVPN config files found"
**Problem**: No `.ovpn` files in `locations/` directory.

**Solution**:
1. Download OpenVPN configs from ProtonVPN
2. Place them in the `locations/` directory
3. Ensure files have `.ovpn` extension

#### "OpenVPN failed to start"
**Problem**: OpenVPN configuration or credentials issue.

**Solutions**:
1. Check credentials file exists and has correct format
2. Verify OpenVPN is installed: `which openvpn`
3. Test config manually: `sudo openvpn --config locations/server.ovpn`

#### "Permission denied" errors
**Problem**: Insufficient privileges for VPN operations.

**Solution**: VPN operations require sudo privileges. The tool will prompt for sudo when needed.

#### "Multiple VPN processes detected"
**Problem**: Another VPN connection is running.

**Solutions**:
1. Use `./src/vpn disconnect` to cleanly stop
2. Use `./src/vpn cleanup` to clean up processes
3. Use `./src/vpn kill` for emergency cleanup

#### Connection hangs or fails
**Problem**: Network connectivity or server issues.

**Solutions**:
1. Try a different server: `./src/vpn connect [different_country]`
2. Test network connectivity: `ping google.com`
3. Check if OpenVPN configs are valid
4. Use `./src/vpn best` to find optimal server

### Debug Information

#### Enable verbose output
Most commands support verbose mode:

```bash
./src/vpn connect se --verbose
```

#### Check log files
Log files are created in `/tmp/`:

```bash
# VPN manager logs
tail -f /tmp/vpn_manager_$(id -u).log

# Connection logs
tail -f /tmp/vpn_connect.log
```

#### Manual OpenVPN testing
Test OpenVPN config manually:

```bash
sudo openvpn --config locations/your-server.ovpn --auth-user-pass credentials.txt
```

### Emergency Recovery

If something goes wrong, these commands can help:

```bash
# Force cleanup everything
./src/vpn kill
./src/vpn cleanup

# Reset performance cache
rm /tmp/vpn_performance.cache

# Check for remaining processes
ps aux | grep openvpn
```

## Tips & Best Practices

### Performance Optimization

1. **Use `best` command**: `./src/vpn best` finds the optimal server
2. **Cache results**: Performance testing results are cached for speed
3. **Country preference**: If you need specific countries, test with `best` first, then use `fast [country]`

### Security Best Practices

1. **Secure credentials**: Always set `chmod 600 credentials.txt`
2. **Regular cleanup**: Disconnect cleanly with `./src/vpn disconnect`
3. **Monitor status**: Regularly check status with `./src/vpn status`
4. **Update configs**: Refresh OpenVPN configs periodically from ProtonVPN

### Workflow Examples

#### Daily Use
```bash
# Morning: Connect to best server
./src/vpn best

# Check status throughout day
./src/vpn status

# Evening: Disconnect
./src/vpn disconnect
```

#### Country-Specific Usage
```bash
# Test and connect to Sweden
./src/vpn best           # Find best overall
./src/vpn connect se     # Connect to Sweden specifically
./src/vpn fast se        # Quick connect to best Sweden server (cached)
```

#### Troubleshooting Workflow
```bash
# If connection problems
./src/vpn disconnect     # Clean disconnect
./src/vpn cleanup        # Clean up any remnants
./src/vpn health         # Check system health
./src/vpn best           # Reconnect to best server
```

### Understanding Output

#### Status Command Output
```
VPN Status: Connected
Server: se-48.protonvpn.udp
External IP: 185.159.157.48
Connected since: 14:30:15
```

- **VPN Status**: Connected/Disconnected/Connecting
- **Server**: Current OpenVPN server name
- **External IP**: Your public IP address
- **Connected since**: Connection start time

#### Performance Testing Output
The `best` command shows server testing progress:
```
Testing servers for best performance...
✓ se-48: 42ms (excellent)
✓ dk-49: 55ms (good)
✓ nl-23: 38ms (excellent)

Best server: nl-23.protonvpn.udp (38ms)
```

---

**Simple VPN Manager** - Do one thing and do it right.
**Total Commands**: 15 focused commands
**Dependencies**: OpenVPN, bash, curl
**Philosophy**: Simple, reliable VPN connections

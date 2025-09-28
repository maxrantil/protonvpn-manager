# Simple VPN Manager - Deployment Guide

**Version:** vpn-simple branch
**Last Updated:** September 28, 2025
**Deployment Status:** Simple Installation - No Complex Services

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [Troubleshooting](#troubleshooting)

## Requirements

### System Requirements

**Operating System:**
- Artix Linux or Arch Linux
- Any Linux distribution with bash 4.0+ and OpenVPN

**Hardware Requirements:**
- **CPU**: Any modern CPU (single core sufficient)
- **Memory**: 50MB minimum, 100MB recommended
- **Storage**: 50MB for installation
- **Network**: Internet connection with OpenVPN access

### Dependencies

**Essential Dependencies:**
```bash
# Artix/Arch Linux
sudo pacman -S openvpn curl

# Debian/Ubuntu (if adapting)
sudo apt install openvpn curl

# Optional but recommended
sudo pacman -S bc iproute2 ping
```

**What You DON'T Need:**
- ❌ No systemd services or complex service management
- ❌ No databases (SQLite, PostgreSQL, etc.)
- ❌ No web servers (nginx, apache, etc.)
- ❌ No monitoring tools (Prometheus, Grafana, etc.)
- ❌ No notification systems
- ❌ No background daemons

## Installation

### Simple Clone and Setup

1. **Clone the Repository**:
```bash
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
git checkout vpn-simple  # Use simplified version
```

2. **Verify Dependencies**:
```bash
# Check if OpenVPN is available
which openvpn || echo "Install OpenVPN: sudo pacman -S openvpn"

# Check if curl is available
which curl || echo "Install curl: sudo pacman -S curl"
```

3. **Test Installation**:
```bash
./src/vpn help
```

If you see the help output, installation is complete!

### ProtonVPN Configuration Setup

1. **Download OpenVPN Configs**:
   - Log into your ProtonVPN account
   - Download OpenVPN configuration files
   - Choose the servers you want

2. **Place Config Files**:
```bash
# Create locations directory if it doesn't exist
mkdir -p locations/

# Place your downloaded .ovpn files in locations/
# Example structure:
# locations/se-45.protonvpn.udp.ovpn
# locations/se-46.protonvpn.udp.ovpn
# locations/dk-49.protonvpn.udp.ovpn
# etc.
```

3. **Create Credentials File**:
```bash
# Create credentials file
echo "your_protonvpn_username" > credentials.txt
echo "your_protonvpn_password" >> credentials.txt

# Secure the file
chmod 600 credentials.txt
```

## Configuration

### Directory Structure

After setup, your directory should look like:

```
protonvpn-manager/
├── src/                          # VPN manager components
│   ├── vpn                       # Main CLI interface
│   ├── vpn-manager              # Process management
│   ├── vpn-connector            # Connection logic
│   ├── best-vpn-profile         # Performance testing
│   ├── vpn-error-handler        # Error handling
│   └── fix-ovpn-configs         # Config validation
├── locations/                    # OpenVPN config files
│   ├── se-45.protonvpn.udp.ovpn
│   ├── dk-49.protonvpn.udp.ovpn
│   └── ...
├── credentials.txt               # Your VPN credentials
└── README.md
```

### Optional Optimizations

1. **Add to PATH (Optional)**:
```bash
# Add to your shell rc file (.bashrc, .zshrc, etc.)
export PATH="$PATH:/path/to/protonvpn-manager/src"

# Then you can use:
vpn help
vpn connect se
# instead of:
./src/vpn help
./src/vpn connect se
```

2. **Create Alias (Optional)**:
```bash
# Add to your shell rc file
alias pvpn='/path/to/protonvpn-manager/src/vpn'

# Then you can use:
pvpn connect se
pvpn status
```

3. **Performance Cache Location (Optional)**:
The system uses `/tmp/vpn_performance.cache` by default. This is fine for most users.

## Usage

### Basic Deployment Workflow

1. **First Connection Test**:
```bash
# Test connection to best server
./src/vpn best

# Check status
./src/vpn status

# Disconnect
./src/vpn disconnect
```

2. **Country-Specific Testing**:
```bash
# Test Sweden servers
./src/vpn connect se
./src/vpn status
./src/vpn disconnect

# Test Denmark servers
./src/vpn connect dk
./src/vpn status
./src/vpn disconnect
```

3. **Production Usage**:
```bash
# Daily workflow
./src/vpn best      # Connect to optimal server
./src/vpn status    # Check throughout the day
./src/vpn disconnect # Disconnect when done
```

### File Permissions

The VPN manager will work with default permissions, but for security:

```bash
# Secure credentials
chmod 600 credentials.txt

# Make scripts executable (should already be)
chmod +x src/vpn*
```

### Network Configuration

**Firewall Considerations:**
- OpenVPN typically uses UDP 1194 or TCP 443
- Your firewall should allow outbound connections
- No inbound ports need to be opened

**DNS Handling:**
- The VPN manager handles DNS automatically
- No manual DNS configuration required
- DNS is restored on disconnect

## Troubleshooting

### Common Deployment Issues

#### "Command not found" when running ./src/vpn
**Problem**: Scripts are not executable or bash is not found.

**Solutions**:
```bash
# Make scripts executable
chmod +x src/*

# Check bash location
which bash

# Check script shebang
head -1 src/vpn
```

#### "No OpenVPN config files found"
**Problem**: No `.ovpn` files in `locations/` directory.

**Solutions**:
```bash
# Check if files exist
ls -la locations/

# Verify file extensions
ls locations/*.ovpn

# Download configs from ProtonVPN if missing
```

#### "OpenVPN command not found"
**Problem**: OpenVPN is not installed.

**Solutions**:
```bash
# Install OpenVPN
sudo pacman -S openvpn    # Arch/Artix
sudo apt install openvpn # Debian/Ubuntu

# Verify installation
which openvpn
openvpn --version
```

#### "Permission denied" for VPN operations
**Problem**: VPN operations require root privileges.

**Solutions**:
- VPN operations need sudo access
- The tool will prompt for sudo when needed
- Ensure your user is in the `sudo` group

#### Performance testing takes too long
**Problem**: Slow network or many servers to test.

**Solutions**:
```bash
# Use fewer config files
# Keep only configs for your preferred countries

# Clear performance cache
rm /tmp/vpn_performance.cache

# Test specific country instead of all
./src/vpn connect se  # instead of ./src/vpn best
```

### Debugging

#### Enable Verbose Output
```bash
# Add --verbose to most commands
./src/vpn connect se --verbose
```

#### Check Log Files
```bash
# View VPN manager logs
tail -f /tmp/vpn_manager_$(id -u).log

# View connection logs
tail -f /tmp/vpn_connect.log
```

#### Manual Testing
```bash
# Test OpenVPN config manually
sudo openvpn --config locations/your-server.ovpn --auth-user-pass credentials.txt

# Test server connectivity
ping se-45.protonvpn.com
```

#### System State Inspection
```bash
# Check for existing VPN processes
ps aux | grep openvpn

# Check network routes
ip route

# Check DNS
cat /etc/resolv.conf
```

### Emergency Recovery

If something goes wrong:

```bash
# Force cleanup all VPN processes
./src/vpn kill

# Clean up network configuration
./src/vpn cleanup

# Reset performance cache
rm /tmp/vpn_performance.cache

# Check system state
./src/vpn health
```

## Maintenance

### Regular Maintenance

1. **Update OpenVPN Configs** (monthly):
   - Download fresh configs from ProtonVPN
   - Replace old configs in `locations/`

2. **Clear Performance Cache** (weekly):
```bash
rm /tmp/vpn_performance.cache
```

3. **Check for Updates** (as needed):
```bash
git pull origin vpn-simple
```

### No Complex Maintenance Required

Unlike enterprise systems, this simple VPN manager requires minimal maintenance:

- ❌ No database maintenance
- ❌ No service monitoring
- ❌ No log rotation configuration
- ❌ No security updates for complex components
- ❌ No backup procedures for complex state

The only maintenance is keeping OpenVPN configs current and occasionally clearing the performance cache.

## Deployment Summary

### What You Get
- Simple VPN connection management
- Intelligent server selection
- Performance optimization
- Clean connection/disconnection
- Basic troubleshooting tools

### What You Don't Get
- Enterprise monitoring
- Complex service management
- API interfaces
- Database management
- Advanced security frameworks

### Perfect For
- Personal VPN management
- Simple, reliable connections
- Users who want "it just works" functionality
- Systems where simplicity is preferred over features

---

**Simple VPN Manager** - Simple deployment for simple needs.
**Installation Time**: < 5 minutes
**Maintenance**: Minimal
**Dependencies**: OpenVPN + curl

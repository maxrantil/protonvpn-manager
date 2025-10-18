# VPN Location Profiles

This directory contains OpenVPN configuration files (`.ovpn`) for ProtonVPN servers.

## Important: Download Your Own Profiles

**Location files are NOT included in the repository for privacy reasons.**

Each user should download their own VPN profiles based on their ProtonVPN subscription and geographic preferences.

## How to Download Profiles

### Option 1: Manual Download from ProtonVPN

1. Log in to your ProtonVPN account: https://account.protonvpn.com
2. Go to **Downloads** → **OpenVPN configuration files**
3. Select your platform: **Linux**
4. Choose protocol: **UDP** (recommended) or **TCP**
5. Download individual server configs or use the download all option
6. Place `.ovpn` files in this directory: `~/.config/vpn/locations/`

### Option 2: Use the Built-in Download Tool (Recommended)

The VPN manager includes an automated download tool:

```bash
# Download all available servers
./src/vpn download

# Download specific country servers
./src/vpn download --country SE  # Sweden
./src/vpn download --country US  # United States

# Download specific city servers
./src/vpn download --city Stockholm
./src/vpn download --city "New York"
```

The download tool will:
- Fetch the latest configs from ProtonVPN
- Place them in the correct location
- Handle authentication automatically
- Update existing profiles if they've changed

## File Structure

After downloading, this directory will contain:

```
locations/
├── README.md                      # This file
├── se-01.protonvpn.udp.ovpn      # Sweden server 1
├── us-ny-01.protonvpn.udp.ovpn   # US New York server 1
├── ch-01.protonvpn.udp.ovpn      # Switzerland server 1
└── ...                            # More server configs
```

## Privacy Note

**Why aren't configs included?**

- **Privacy**: Server choices reveal geographic location and usage patterns
- **Subscription-specific**: Available servers depend on your ProtonVPN tier
- **Dynamic updates**: ProtonVPN regularly updates server configurations
- **User preference**: Different users need different server locations

## Gitignore

Location files are excluded from version control via `.gitignore`:

```gitignore
locations/*.ovpn
locations/.download-metadata/
```

Your downloaded profiles will remain local to your system and won't be committed to git.

## Troubleshooting

### No profiles found

```bash
# Check if directory exists
ls -la ~/.config/vpn/locations/

# If empty, download profiles
./src/vpn download
```

### Permission issues

```bash
# Ensure correct permissions
chmod 755 ~/.config/vpn/locations/
chmod 644 ~/.config/vpn/locations/*.ovpn
```

### Outdated configs

ProtonVPN updates server configurations regularly. Re-download if you experience connection issues:

```bash
# Re-download all profiles
./src/vpn download --force
```

## Security

- **.ovpn files contain**: Server addresses, port numbers, encryption settings
- **They do NOT contain**: Your credentials, passwords, or authentication tokens
- Credentials are stored separately in `~/.config/vpn/vpn-credentials.txt`

---

**Need help?** See the main [README.md](../README.md) or [SECURITY.md](../SECURITY.md)

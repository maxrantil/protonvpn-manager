# Safe VPN Testing Procedures

## CRITICAL: Preventing Process Accumulation and System Overheating

**⚠️ DANGER:** Multiple OpenVPN processes running simultaneously can cause:
- Severe system overheating and CPU load (97%+ per process)
- Network conflicts and connection instability
- Laptop thermal throttling and potential hardware damage

## Safe Manual Testing Workflow

**ALWAYS follow this exact workflow when testing VPN connections:**

```bash
# 1. BEFORE testing any connection:
./src/vpn status          # Check current state
./src/vpn cleanup         # Clean up any existing connections

# 2. Test your connection:
./src/vpn connect se      # Or whatever test you want

# 3. AFTER each test:
./src/vpn disconnect      # Gracefully disconnect (preferred)
# OR if that fails:
./src/vpn cleanup         # Force cleanup

# 4. Verify clean state:
./src/vpn status          # Should show DISCONNECTED
```

## Critical Safety Rules

### ✅ DO:
- **ALWAYS** run `./src/vpn cleanup` before testing connections
- **ALWAYS** run `./src/vpn disconnect` or `./src/vpn cleanup` after testing
- **ALWAYS** verify clean state with `./src/vpn status` between tests
- Use graceful disconnection when possible
- Monitor system temperature during extended testing

### ❌ NEVER:
- **NEVER** use `sudo kill -9` on OpenVPN processes (kills your internet connection)
- **NEVER** start new connections without cleaning up previous ones
- **NEVER** leave multiple OpenVPN processes running simultaneously
- **NEVER** ignore high CPU usage from OpenVPN processes

## Emergency Cleanup Procedure

If you discover multiple OpenVPN processes running:

```bash
# 1. Check process count:
ps aux | grep openvpn | grep -v grep

# 2. Use our cleanup tool:
./src/vpn cleanup

# 3. If cleanup fails, use our emergency kill-all:
./src/vpn kill-all

# 4. Verify all processes gone:
ps aux | grep openvpn | grep -v grep

# 5. Restore network if needed:
# For Artix Linux with runit:
sudo sv restart NetworkManager
# OR for systemd systems:
sudo systemctl restart NetworkManager
# OR for other init systems:
sudo service NetworkManager restart
```

## Testing Different Profiles Safely

When testing multiple profiles or countries:

```bash
# Test sequence for multiple locations
./src/vpn cleanup
./src/vpn connect se
./src/vpn status
./src/vpn disconnect

./src/vpn cleanup  # Clean between tests
./src/vpn connect dk
./src/vpn status
./src/vpn disconnect

./src/vpn cleanup  # Always end with cleanup
```

## Automated Testing Considerations

- All automated tests use mocked commands to prevent real connections
- Realistic connection tests use dry-run modes when possible
- Integration tests clean up properly between test cases
- Never run multiple test suites simultaneously without cleanup

## Troubleshooting Connection Issues

### Stuck Connections:
```bash
./src/vpn cleanup
./src/vpn status  # Should show DISCONNECTED
```

### Network Loss After Force Kill:
```bash
# For Artix Linux with runit:
sudo sv restart NetworkManager
# OR for systemd systems:
sudo systemctl restart NetworkManager

# Wait 10-15 seconds for network restoration
```

### High CPU Usage:
```bash
# Check for multiple processes immediately:
ps aux | grep openvpn | grep -v grep | wc -l
# Should show 0 or 1, never more than 1
```

## Development Testing Protocol

When developing or debugging VPN features:

1. **Start with clean state**: `./src/vpn cleanup`
2. **Single test at a time**: Never run parallel connection attempts
3. **Monitor processes**: Regularly check `ps aux | grep openvpn`
4. **Clean between tests**: Always disconnect/cleanup between different tests
5. **Verify cleanup**: Confirm DISCONNECTED status before next test

---

**Remember**: Better safe than sorry - always err on the side of more cleanup rather than less!

**Created**: 2025-09-03
**Author**: Development Team
**Version**: 1.0

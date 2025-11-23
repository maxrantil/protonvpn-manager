# VPN Kill Switch & Auto-Reconnect Troubleshooting

## Quick Fix: No Internet After WiFi Reconnect

If your WiFi reconnects but you have no internet, the kill switch is likely blocking traffic (by design - protecting you from data leaks).

```bash
# Restore internet immediately
sudo vpn-kill-switch disable

# Then reconnect VPN
vpn cleanup
vpn connect se

# Re-enable kill switch after connected
sudo vpn-kill-switch enable
```

---

## Step-by-Step Troubleshooting

### Step 1: Check Kill Switch Status
```bash
vpn-kill-switch status
```

- If **ENABLED** + VPN down = kill switch blocking traffic (expected behavior)
- If **DISABLED** = something else is wrong

### Step 2: Check VPN Status
```bash
vpn status
```

### Step 3: Check Auto-Reconnect Status
```bash
vpn-manager config auto-reconnect status
```

### Step 4: View Auto-Reconnect Logs
```bash
cat ~/.local/state/vpn/reconnect.log
```

### Step 5: View VPN Manager Logs
```bash
cat ~/.local/state/vpn/vpn_manager.log
```

---

## Emergency Commands

| Situation | Command |
|-----------|---------|
| **No internet, need it NOW** | `sudo vpn-kill-switch disable` |
| **Nuclear option (force remove rules)** | `sudo vpn-kill-switch emergency` |
| **VPN stuck/zombie processes** | `vpn cleanup` |
| **Full network reset** | `vpn emergency-reset` |

---

## Common Scenarios

### Scenario 1: WiFi reconnected, no internet, VPN not reconnecting

```bash
# 1. Check what's blocking
vpn-kill-switch status

# 2. If kill switch enabled, disable it temporarily
sudo vpn-kill-switch disable

# 3. Clean up any dead VPN state
vpn cleanup

# 4. Reconnect manually
vpn connect se

# 5. Re-enable kill switch
sudo vpn-kill-switch enable
```

### Scenario 2: Auto-reconnect not working

Check requirements:
1. Kill switch must be enabled: `vpn-kill-switch status`
2. Auto-reconnect must be on: `vpn-manager config auto-reconnect status`
3. Must have connected at least once (to save profile state)

Check logs:
```bash
cat ~/.local/state/vpn/reconnect.log
```

Common issues in logs:
- "kill switch not enabled" → run `sudo vpn-kill-switch enable`
- "Cooldown active" → wait 30 seconds between attempts
- "Max attempts exceeded" → wait 5 minutes, rate limited for security

### Scenario 3: Kill switch won't enable (iptables errors)

```bash
# Check if iptables is installed
which iptables

# Check for existing rules
sudo iptables -L -n

# Try emergency disable first, then re-enable
sudo vpn-kill-switch emergency
sudo vpn-kill-switch enable
```

---

## Diagnostic Commands Reference

```bash
# Kill switch status
vpn-kill-switch status

# VPN connection status
vpn status

# Auto-reconnect config
vpn-manager config auto-reconnect status

# View iptables rules directly
sudo iptables -L VPN_KILL_SWITCH -n 2>/dev/null || echo "No kill switch rules"
sudo ip6tables -L VPN_KILL_SWITCH_V6 -n 2>/dev/null || echo "No IPv6 rules"

# Check for OpenVPN processes
pgrep -fa openvpn

# Check tun interface
ip link show tun0 2>/dev/null || echo "No tun0 interface"

# View logs
cat ~/.local/state/vpn/reconnect.log
cat ~/.local/state/vpn/vpn_manager.log
tail -20 ~/.local/state/vpn/openvpn.log

# System logs (Artix with runit - check syslog)
tail -50 /var/log/messages 2>/dev/null | grep -i vpn
```

---

## State Files Location

All state files are in `~/.local/state/vpn/`:

| File | Purpose |
|------|---------|
| `kill_switch.state` | Kill switch on/off state |
| `last_profile` | Last connected VPN profile path |
| `last_profile.sha256` | Profile integrity hash |
| `reconnect.log` | Auto-reconnect event log |
| `reconnect.lock` | Prevents concurrent reconnects |
| `reconnect.attempts` | Rate limiting tracker |
| `vpn_manager.log` | General VPN manager log |

---

## Config File Location

`~/.config/vpn/config`

```bash
# View current config
cat ~/.config/vpn/config

# Expected contents when auto-reconnect enabled:
# AUTO_RECONNECT=true
# AUTO_RECONNECT_COOLDOWN=30
# AUTO_RECONNECT_MAX_ATTEMPTS=3
```

---

## Remember

1. **Kill switch blocks ALL traffic when VPN is down** - this is intentional for security
2. **Auto-reconnect requires kill switch** - won't work without it
3. **Rate limited** - max 3 attempts per 5 minutes, 30s between attempts
4. **Logs are your friend** - check `~/.local/state/vpn/reconnect.log` first

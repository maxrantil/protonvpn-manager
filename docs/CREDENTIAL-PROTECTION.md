# VPN Credential Protection Guidelines

## For Developers/AI Assistants

### NEVER Directly Modify Production Credentials

**STRICT RULE:** Never write to `~/.config/vpn/vpn-credentials.txt` without explicit user permission.

### Testing Authentication Failures

When testing authentication failure scenarios:

1. **Create a test credentials file:**
   ```bash
   echo -e "testuser\ntestpass" > /tmp/test-vpn-credentials.txt
   chmod 600 /tmp/test-vpn-credentials.txt
   ```

2. **Temporarily point to test file:**
   ```bash
   export VPN_CONFIG_DIR=/tmp/test-vpn-config
   mkdir -p $VPN_CONFIG_DIR
   cp /tmp/test-vpn-credentials.txt $VPN_CONFIG_DIR/vpn-credentials.txt
   ```

3. **OR modify the script to accept credential file parameter**

### Backup Before ANY Credential Changes

```bash
# Always backup first
if [[ -f ~/.config/vpn/vpn-credentials.txt ]]; then
    cp ~/.config/vpn/vpn-credentials.txt \
       ~/.config/vpn/vpn-credentials.txt.backup-$(date +%Y%m%d-%H%M%S)
fi
```

### Recovery Process

If credentials are accidentally overwritten:

1. Check for timestamped backups:
   ```bash
   ls -lat ~/.config/vpn/vpn-credentials.txt.backup*
   ```

2. Restore most recent backup:
   ```bash
   cp ~/.config/vpn/vpn-credentials.txt.backup-YYYYMMDD-HHMMSS \
      ~/.config/vpn/vpn-credentials.txt
   chmod 600 ~/.config/vpn/vpn-credentials.txt
   ```

3. If no backup exists, user must manually restore from:
   - Password manager
   - ProtonVPN account settings
   - Email records

## For Users

### Create Your Own Backup

```bash
cp ~/.config/vpn/vpn-credentials.txt ~/.config/vpn/vpn-credentials.txt.backup
chmod 600 ~/.config/vpn/vpn-credentials.txt.backup
```

### Store Credentials Securely

- Use a password manager (recommended)
- Keep encrypted backup separate from system
- Never commit credentials to git repositories

## Incident: 2025-10-04

**What happened:** AI assistant overwrote production credentials with test values (`baduser/badpass`) during authentication failure testing.

**Impact:** User credentials lost, requiring manual restoration.

**Prevention:**
- Added this documentation
- Created automatic backup script
- Established testing protocols using separate files

**Lesson:** Always backup before testing, never modify production credential files.

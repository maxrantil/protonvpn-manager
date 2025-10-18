# Security Policy

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| Latest release | :white_check_mark: |
| Older releases | :x: |

## Reporting a Vulnerability

**DO NOT** open a public GitHub issue for security vulnerabilities.

Security vulnerabilities should be reported privately to allow us to address them before public disclosure.

### How to Report

Please report security issues to:
- **Email**: rantil@pm.me
- **Subject Line**: `[SECURITY] protonvpn-manager vulnerability`

### What to Include

Your security report should include:

1. **Description**: Clear description of the vulnerability
2. **Impact**: What could an attacker do? Who is affected?
3. **Steps to Reproduce**: Detailed steps to trigger the vulnerability
4. **Affected Versions**: Which versions are vulnerable?
5. **Proof of Concept**: Code, commands, or screenshots demonstrating the issue
6. **Suggested Fix**: If you have ideas for fixing it (optional but appreciated)

### Response Timeline

We aim to:
- **Acknowledge** your report within **48 hours**
- **Provide initial assessment** within **7 days**
- **Issue a fix** within **30 days** for critical vulnerabilities

Critical vulnerabilities affecting credential security, privilege escalation, or remote code execution will be prioritized and addressed as quickly as possible.

## Security Considerations

protonvpn-manager is a VPN management tool that:
- **Manages VPN connections** with elevated privileges (sudo)
- **Handles sensitive credentials** (ProtonVPN username/password)
- **Interacts with network interfaces** (system-level operations)
- **Executes system commands** (OpenVPN, network utilities)

### Threat Model

**In Scope:**
- Credential theft or exposure
- Privilege escalation vulnerabilities
- Command injection attacks
- Path traversal or symlink attacks
- Race conditions in file/lock handling
- Information disclosure through logs

**Out of Scope:**
- Vulnerabilities in OpenVPN itself
- ProtonVPN server-side issues
- Physical access attacks
- Social engineering

## Known Security Practices

We implement these security measures:

### Credential Protection
- Credentials stored with `600` permissions (owner read/write only)
- Automatic permission validation and correction
- Credentials never logged or printed
- Environment variable isolation

### Input Validation
- Profile paths validated against whitelisted directories
- Country codes sanitized (2-letter lowercase only)
- File existence and type verification
- Symlink detection and rejection

### Privilege Management
- Minimal use of sudo (only where necessary)
- Sudo operations preceded by input validation
- No sudo password caching
- Explicit PATH usage for all commands

### File System Security
- Lock files prevent concurrent operations
- Atomic file operations where possible
- Secure temporary file handling
- Log rotation with size limits

### Process Security
- PID validation and ownership checks
- Process cleanup on script exit
- Signal handling for graceful termination
- No shell injection vulnerabilities

## Security Audit History

| Date | Auditor | Scope | Findings |
|------|---------|-------|----------|
| 2025-10-13 | Internal | Pre-release comprehensive audit | 5 HIGH, 8 MEDIUM issues identified and addressed |

## Bug Bounty Program

We currently do not offer a formal bug bounty program. However, we deeply appreciate security researchers who report vulnerabilities responsibly. We will:
- Acknowledge your contribution in release notes (with your permission)
- Credit you in our security advisories
- Respond promptly and professionally

## Disclosure Policy

We follow **coordinated disclosure**:

1. **You report** the vulnerability privately
2. **We acknowledge** and begin investigation
3. **We develop** a fix in a private branch
4. **We release** the fix and security advisory
5. **You may publish** your findings after fix is released (30 days minimum)

We request that you:
- Give us reasonable time to fix the issue before public disclosure
- Make a good faith effort to avoid privacy violations and service disruption
- Don't access or modify other users' data

## Security Best Practices for Users

### Installation
- Only install from official sources (GitHub releases)
- Verify git tags and commit signatures
- Review code before running (it's open source!)

### Configuration
- Store credentials in `~/.config/vpn/credentials.txt` with `600` permissions
- Use a dedicated VPN-only user account if possible
- Keep ProtonVPN credentials separate from other services

### Operation
- Run as regular user (not root directly)
- Use sudo only when prompted
- Review log files periodically for suspicious activity
- Keep system and dependencies updated

### Monitoring
- Check for unusual network connections
- Monitor VPN connection status regularly
- Verify DNS resolution goes through VPN tunnel
- Review process list for unexpected VPN-related processes

## Additional Resources

- **OpenVPN Security**: https://openvpn.net/community-resources/how-to/
- **ProtonVPN Security**: https://protonvpn.com/support/security-features/
- **Linux Security Hardening**: https://www.cyberciti.biz/tips/linux-security.html

## Security Acknowledgments

We deeply appreciate security researchers who help keep protonvpn-manager secure. This section recognizes individuals who have responsibly disclosed security vulnerabilities.

### Hall of Fame

Contributors who have responsibly disclosed security vulnerabilities will be acknowledged here (with their permission):

| Date | Researcher | Issue | Severity |
|------|-----------|--------|----------|
| *Future entries* | *Will be added as security reports are received* | - | - |

### Recognition Policy

When you report a security vulnerability:
1. **We will credit you** in this section (with your permission)
2. **Your contribution** will be mentioned in release notes
3. **You choose** how you're identified (real name, pseudonym, or anonymous)
4. **We include** a brief description of the vulnerability (after fix is released)

### How to Be Acknowledged

When reporting a vulnerability, please indicate:
- **Name/handle** you'd like to be credited as (or "Anonymous")
- **Optional**: Your website, Twitter/GitHub handle, or professional affiliation
- **Permission** to publicly acknowledge your contribution

**Example acknowledgment format**:
> **March 2025** - *@researcher123* - Reported privilege escalation in sudo validation (HIGH severity). The vulnerability allowed path traversal in profile validation, which could lead to arbitrary file access. Fixed in v1.2.0.

### Thank You!

Security research makes this project safer for everyone. We're grateful for:
- Your time and expertise
- Responsible disclosure practices
- Detailed reports and proof-of-concepts
- Patience during the fix and disclosure process

If you're interested in security research but new to it, we welcome reports from researchers at all experience levels. Clear communication and responsible disclosure matter more than sophistication.

---

## Contact

For security-related questions that don't involve vulnerabilities:
- **Email**: rantil@pm.me
- **GitHub Issues**: https://github.com/maxrantil/protonvpn-manager/issues (for non-security bugs)

---

**Last Updated**: 2025-10-18
**Version**: 1.0.0

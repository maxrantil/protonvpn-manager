# Public Release Preparation Plan

**Repository**: protonvpn-manager
**Target**: Public GitHub release
**Date Created**: 2025-10-13
**Status**: IN PROGRESS

---

## Executive Summary

This document outlines the steps required to safely transition the protonvpn-manager repository from private to public on GitHub. Based on comprehensive security audit findings, we have identified 1 critical issue (already mitigated - old credentials), 5 high-priority improvements, and several medium-priority enhancements.

**Current State**:
- ✅ Test runner accumulator bug fixed (PR #101)
- ✅ CI/CD infrastructure in place
- ⚠️ Old credentials.txt in git history (inactive, but should be removed)
- ⚠️ 5 HIGH-priority security improvements needed
- ⚠️ Documentation needs public audience updates

**Timeline Estimate**: 3-5 days for all improvements, or 1 day for minimal viable public release

---

## Phase 1: IMMEDIATE PRE-RELEASE (CRITICAL)

**Timeline**: 2-4 hours
**Priority**: BLOCKING - Must complete before making public

### 1.1 Git History Cleanup

**Issue**: Old credentials.txt in commit 01bc712 (inactive but unprofessional)

**Action**:
```bash
# Option A: BFG Repo-Cleaner (RECOMMENDED - fast, safe)
# 1. Download BFG from https://rtyley.github.io/bfg-repo-cleaner/
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar

# 2. Clone a fresh mirror
cd /tmp
git clone --mirror git@github.com:maxrantil/protonvpn-manager.git

# 3. Run BFG to remove credentials.txt
java -jar bfg-1.14.0.jar --delete-files credentials.txt protonvpn-manager.git

# 4. Clean up
cd protonvpn-manager.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5. Force push to remote (DESTRUCTIVE - backup first!)
git push --force --all
git push --force --tags

# 6. Re-clone working repository
cd /home/mqx/workspace
mv protonvpn-manager protonvpn-manager.backup
git clone git@github.com:maxrantil/protonvpn-manager.git

# Option B: git filter-repo (alternative if BFG unavailable)
# Install: pip install git-filter-repo
git filter-repo --invert-paths --path credentials.txt --force
```

**Verification**:
```bash
# Should return nothing
git log --all --full-history -- credentials.txt

# Check file doesn't exist
git show master:credentials.txt  # Should error

# Verify .gitignore still has entry
grep credentials.txt .gitignore
```

**Status**: ⏳ PENDING

---

### 1.2 Merge Outstanding PRs

**PR #101**: Fix test runner variable accumulation
- ✅ Code complete
- ✅ Tested locally (117 tests accumulate correctly)
- ⚠️ CI blocked by GitHub Actions billing issue
- **Action**: Merge based on local verification

```bash
# After resolving billing OR if willing to merge without CI
git checkout master
git merge --no-ff fix/ci-test-failures -m "Merge PR #101: Fix test runner accumulator bug"
git push origin master
```

**Status**: ⏳ PENDING (waiting on billing resolution or Doctor Hubert approval)

---

### 1.3 Current Working Directory Cleanup

**Remove untracked sensitive files**:
```bash
# Check for sensitive files
ls -la credentials.txt 2>/dev/null && rm credentials.txt

# Verify .gitignore coverage
git check-ignore -v credentials.txt
git status --ignored
```

**Status**: ⏳ PENDING

---

## Phase 2: HIGH-PRIORITY SECURITY IMPROVEMENTS

**Timeline**: 1-2 days
**Priority**: STRONGLY RECOMMENDED before public release

These address security audit findings that could be exploited:

### 2.1 Fix Lock File Race Conditions (HIGH)

**Issue**: Predictable lock files in `/tmp` vulnerable to symlink attacks

**Files**: `src/vpn-manager:20`, `src/vpn-connector:25`

**Fix**:
```bash
# Replace hardcoded /tmp paths with XDG runtime directory
LOCK_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/vpn"
mkdir -p "$LOCK_DIR" 2>/dev/null || LOCK_DIR="/tmp"
chmod 700 "$LOCK_DIR" 2>/dev/null
LOCK_FILE="$LOCK_DIR/vpn_manager.lock"

# Use flock for atomic locking
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Already running"; exit 1; }
```

**Estimated Time**: 2 hours (implementation + testing)

**Status**: ⏳ PENDING

---

### 2.2 Harden Sudo Input Validation (HIGH)

**Issue**: Profile paths passed to sudo without comprehensive validation

**Files**: `src/vpn-manager:370+`, `src/vpn-connector:492+`

**Fix**: Create validation library
```bash
# New file: src/vpn-validators
validate_profile_path() {
    local path="$1"
    local canonical

    # Must resolve to real path
    canonical=$(realpath "$path" 2>/dev/null) || return 1

    # Must be within LOCATIONS_DIR
    [[ "$canonical" =~ ^"$(realpath "$LOCATIONS_DIR")"/ ]] || return 1

    # Must be regular file, not symlink
    [[ -f "$path" && ! -L "$path" ]] || return 1

    # Must have safe extension
    [[ "$path" =~ \.(ovpn|conf)$ ]] || return 1

    # No path traversal
    [[ ! "$path" =~ \.\. ]] || return 1

    return 0
}

# Call before ALL sudo operations
validate_profile_path "$profile_path" || {
    echo "ERROR: Invalid profile path"
    return 1
}
sudo openvpn --config "$profile_path"
```

**Estimated Time**: 3 hours (create validators, integrate, test)

**Status**: ⏳ PENDING

---

### 2.3 Secure Temporary File Handling (HIGH)

**Issue**: Cache files in `/tmp` with predictable names

**Files**: `src/vpn-manager:102`, `src/vpn-connector:23-24`

**Fix**:
```bash
# Use XDG cache directory
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vpn"
mkdir -p "$CACHE_DIR" 2>/dev/null
chmod 700 "$CACHE_DIR"

# For temporary files, use mktemp
temp_file=$(mktemp "$CACHE_DIR/vpn_cache.XXXXXX")
chmod 600 "$temp_file"
```

**Estimated Time**: 2 hours (update all temp file usage)

**Status**: ⏳ PENDING

---

### 2.4 Replace eval in Test Framework (HIGH)

**Issue**: Command injection risk in test framework

**Files**: `tests/test_framework.sh:138,154`

**Fix**: Replace eval with direct execution or array expansion
```bash
# OLD (dangerous):
eval "$command" > /dev/null 2>&1

# NEW (safe):
"$command" > /dev/null 2>&1
# OR if command is array:
"${command[@]}" > /dev/null 2>&1
```

**Estimated Time**: 1 hour (simple replacement)

**Status**: ⏳ PENDING

---

### 2.5 Enhanced Credential File Validation (HIGH)

**Issue**: chmod success not verified after permission fix

**Files**: `src/vpn-connector:464-468`, `src/vpn-manager:146-152`

**Fix**:
```bash
if [[ "$file_perms" != "600" ]]; then
    if ! chmod 600 "$CREDENTIALS_FILE"; then
        echo "FATAL: Cannot secure credentials file"
        return 1
    fi
    # Re-verify after change
    file_perms=$(stat -c "%a" "$CREDENTIALS_FILE" 2>/dev/null)
    if [[ "$file_perms" != "600" ]]; then
        echo "FATAL: Permissions remain insecure"
        return 1
    fi
fi
```

**Estimated Time**: 1 hour

**Status**: ⏳ PENDING

---

## Phase 3: DOCUMENTATION FOR PUBLIC AUDIENCE

**Timeline**: 2-4 hours
**Priority**: RECOMMENDED before public release

### 3.1 Create SECURITY.md

**Purpose**: Responsible vulnerability disclosure process

**Template**:
```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

**DO NOT** open a public issue for security vulnerabilities.

Instead, please report security issues to:
- **Email**: rantil@pm.me
- **Subject**: [SECURITY] protonvpn-manager vulnerability

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if known)

We aim to respond within 48 hours and provide a fix timeline.

## Security Considerations

This tool:
- Manages VPN connections with elevated privileges (sudo)
- Handles sensitive credentials
- Interacts with network interfaces

Please review our threat model in docs/SECURITY_ARCHITECTURE.md

## Known Security Practices

- Credentials stored with 600 permissions
- Lock files prevent race conditions
- Input validation on all external data
- Regular security audits
```

**Estimated Time**: 30 minutes

**Status**: ⏳ PENDING

---

### 3.2 Update README.md for Public Audience

**Current State**: README may have internal references or assumptions

**Updates Needed**:
1. Add prominent badges (build status, license, etc.)
2. Clear installation instructions for new users
3. Usage examples with screenshots/demos
4. Contribution guidelines reference
5. License information (ensure LICENSE file exists)
6. Remove any internal/private references

**Example additions**:
```markdown
# ProtonVPN Manager

[![License](https://img.shields.io/github/license/maxrantil/protonvpn-manager)](LICENSE)
[![Tests](https://github.com/maxrantil/protonvpn-manager/workflows/Run%20Tests/badge.svg)](https://github.com/maxrantil/protonvpn-manager/actions)

Simple VPN management for Artix/Arch Linux following Unix philosophy.

## Features

- ✅ Automatic ProtonVPN connection management
- ✅ Location-based server selection
- ✅ Connection health monitoring
- ✅ Secure credential handling
- ✅ Comprehensive test suite

## Installation

[Clear step-by-step instructions]

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[License type] - see [LICENSE](LICENSE)
```

**Estimated Time**: 1-2 hours

**Status**: ⏳ PENDING

---

### 3.3 Remove/Update CLAUDE.md

**Issue**: CLAUDE.md contains internal development workflow instructions

**Options**:
1. **Remove entirely**: Not needed for public users
2. **Move to .github/**: Keep for contributors but not prominent
3. **Replace with CONTRIBUTING.md**: Public-friendly contribution guide

**Recommendation**: Option 3 - Create public CONTRIBUTING.md, move CLAUDE.md to `.github/CLAUDE.md`

**Estimated Time**: 1 hour

**Status**: ⏳ PENDING

---

### 3.4 Add LICENSE File

**Current State**: Check if LICENSE file exists

```bash
ls -la LICENSE 2>/dev/null
```

**If missing, add appropriate license** (suggest MIT or GPL-3.0 for VPN tools)

**Estimated Time**: 15 minutes

**Status**: ⏳ PENDING

---

## Phase 4: CI/CD & GITHUB CONFIGURATION

**Timeline**: 1-2 hours
**Priority**: RECOMMENDED

### 4.1 Verify GitHub Actions Workflows

**Check all workflows in `.github/workflows/` for**:
- ❌ No hardcoded secrets in workflow files
- ❌ No private repository references
- ✅ Secrets properly stored in GitHub Secrets
- ✅ Workflows work for external contributors (fork-friendly)

**Files to review**:
- `.github/workflows/*.yml`

**Action**: Read through each workflow, ensure public-safe

**Estimated Time**: 1 hour

**Status**: ⏳ PENDING

---

### 4.2 Configure Repository Settings

**Before making public, configure**:

1. **Branch Protection** (master branch):
   - Require pull request reviews
   - Require status checks to pass
   - Include administrators (optional)

2. **Security**:
   - Enable Dependabot alerts
   - Enable secret scanning
   - Configure security policy (SECURITY.md)

3. **Actions**:
   - Enable Actions for forks
   - Configure approval for first-time contributors

4. **General**:
   - Set repository description
   - Add topics/tags (vpn, linux, archlinux, protonvpn)
   - Set website URL (if applicable)

**Estimated Time**: 30 minutes

**Status**: ⏳ PENDING

---

## Phase 5: FINAL VERIFICATION

**Timeline**: 1 hour
**Priority**: MANDATORY before making public

### 5.1 Security Verification Checklist

Run comprehensive security checks:

```bash
#!/bin/bash
# Pre-release security verification script

echo "=== SECURITY VERIFICATION CHECKLIST ==="

# 1. No credentials in history
echo -n "✓ Checking git history for credentials... "
if git log --all --full-history --source -- credentials.txt 2>&1 | grep -q "commit"; then
    echo "❌ FAIL - credentials.txt found in history"
    exit 1
else
    echo "✅ PASS"
fi

# 2. No secrets in tracked files
echo -n "✓ Checking for hardcoded secrets... "
if git grep -i "password\s*=\s*['\"]" src/; then
    echo "❌ FAIL - possible hardcoded password"
    exit 1
else
    echo "✅ PASS"
fi

# 3. .gitignore properly configured
echo -n "✓ Checking .gitignore... "
if ! git check-ignore -q credentials.txt; then
    echo "❌ FAIL - credentials.txt not ignored"
    exit 1
else
    echo "✅ PASS"
fi

# 4. Test credentials are obviously fake
echo -n "✓ Checking test credentials... "
if grep -r "tests/" -e "real@email.com" -e "production"; then
    echo "⚠️  WARN - test data may look real"
fi
echo "✅ PASS"

# 5. All tests pass
echo -n "✓ Running test suite... "
if ! ./tests/run_tests.sh > /dev/null 2>&1; then
    echo "❌ FAIL - tests failing"
    exit 1
else
    echo "✅ PASS"
fi

# 6. ShellCheck passes
echo -n "✓ Running shellcheck... "
if ! shellcheck src/* > /dev/null 2>&1; then
    echo "❌ FAIL - shellcheck issues"
    exit 1
else
    echo "✅ PASS"
fi

# 7. Required documentation exists
echo -n "✓ Checking documentation... "
for file in README.md SECURITY.md LICENSE; do
    if [[ ! -f "$file" ]]; then
        echo "❌ FAIL - missing $file"
        exit 1
    fi
done
echo "✅ PASS"

echo ""
echo "🎉 ALL CHECKS PASSED - READY FOR PUBLIC RELEASE"
```

**Estimated Time**: 30 minutes to create and run script

**Status**: ⏳ PENDING

---

### 5.2 Final Manual Review

**Checklist**:
- [ ] README is accurate and welcoming
- [ ] All documentation links work
- [ ] CI badges point to correct repository
- [ ] No internal/private information exposed
- [ ] License is appropriate and included
- [ ] SECURITY.md provides clear vulnerability reporting process
- [ ] All tests pass (locally, even if CI has issues)
- [ ] Code is properly commented for external audience
- [ ] No embarrassing or unprofessional comments

**Estimated Time**: 30 minutes

**Status**: ⏳ PENDING

---

## Phase 6: MAKE PUBLIC

**Timeline**: 5 minutes
**Priority**: FINAL STEP

### 6.1 Create Release Tag

```bash
# Tag the release version
git tag -a v1.0.0 -m "Initial public release

- VPN connection management for Artix/Arch Linux
- ProtonVPN integration
- Location-based server selection
- Comprehensive test suite
- Security-hardened implementation"

git push origin v1.0.0
```

### 6.2 Make Repository Public

**GitHub UI Steps**:
1. Go to repository Settings
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Select "Make public"
5. Type repository name to confirm
6. Click "I understand, make this repository public"

**⚠️ WARNING: THIS IS IRREVERSIBLE**
- Once public, git history is permanently exposed
- Ensure all security fixes complete first

### 6.3 Announce (Optional)

**Potential venues**:
- Reddit: r/archlinux, r/ProtonVPN
- Hacker News
- Personal blog/social media
- Arch User Repository (AUR) package

---

## DECISION POINTS

**Doctor Hubert**, you need to decide:

### Decision 1: Timeline Approach

**Option A: Fast Track (1 day)**
- Remove credentials.txt from history ✅
- Merge PR #101 ✅
- Add SECURITY.md ✅
- Update README for public ✅
- Make public

**Option B: Thorough (3-5 days)**
- Everything in Option A
- Plus: All 5 HIGH-priority security fixes
- Plus: Comprehensive documentation review
- Plus: CI/CD verification

**Option C: Minimal (2-4 hours)**
- Remove credentials.txt from history only
- Make public immediately
- Address security improvements post-release

**Recommendation**: Option A (Fast Track) - good balance of security and speed

---

### Decision 2: PR #101 Merge Strategy

Given CI is blocked by billing:

**Option A: Merge now based on local verification**
- Tests pass locally (117 tests, was 0 before fix)
- Pre-commit hooks passed
- Code reviewed

**Option B: Wait for CI to run**
- Resolve billing issue first
- Wait for GitHub Actions to confirm

**Recommendation**: Option A if billing resolution will take >1 day

---

### Decision 3: Security Improvements Timing

**Option A: Pre-release (recommended)**
- Fix all HIGH-priority issues before making public
- Shows commitment to security
- Avoids early vulnerability reports

**Option B: Post-release**
- Make public now
- Create issues for security improvements
- Fix incrementally
- Accept potential early vulnerability reports

**Recommendation**: Option A for HIGH-priority issues (2-3 days work)

---

## NEXT STEPS

**What would you like to do, Doctor Hubert?**

1. **Start Phase 1** (git history cleanup) - 2-4 hours
2. **Choose timeline** (Fast Track vs Thorough vs Minimal)
3. **Merge PR #101** now or wait for CI?
4. **Assign priorities** (which security fixes are must-have vs nice-to-have?)

I can start immediately on any of these paths. What's your preference?

---

## RESOURCES

**Tools Needed**:
- BFG Repo-Cleaner: https://rtyley.github.io/bfg-repo-cleaner/
- git-filter-repo: https://github.com/newren/git-filter-repo

**Documentation References**:
- GitHub: Making a private repository public
- Security best practices: OWASP guidelines
- Bash security: ShellCheck documentation

**Backup Locations**:
- Current repo backed up at: `/home/mqx/workspace/protonvpn-manager.backup` (after history cleanup)

---

**Created**: 2025-10-13
**Last Updated**: 2025-10-13
**Status**: AWAITING DOCTOR HUBERT'S DECISION

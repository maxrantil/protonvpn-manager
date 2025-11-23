# Release Process Documentation

## Overview

The ProtonVPN Manager project uses an automated release workflow that creates GitHub releases with properly versioned artifacts, checksums, and changelogs automatically generated from conventional commits.

## Table of Contents

1. [Release Types](#release-types)
2. [Prerequisites](#prerequisites)
3. [Creating a Release](#creating-a-release)
4. [Release Workflow](#release-workflow)
5. [Testing Before Release](#testing-before-release)
6. [Artifact Structure](#artifact-structure)
7. [GPG Signing](#gpg-signing)
8. [Troubleshooting](#troubleshooting)

---

## Release Types

The project supports the following release types:

### Stable Releases
- **Format**: `vX.Y.Z` (e.g., `v1.2.3`)
- **Use case**: Production-ready releases
- **Branch**: Should be created from `master`
- **Example**: `v1.0.0`, `v1.2.3`, `v2.0.0`

### Pre-releases
- **Alpha**: `vX.Y.Z-alpha.N` (e.g., `v1.2.3-alpha.1`)
  - Early development, unstable, for testing only
  - May have incomplete features or known bugs

- **Beta**: `vX.Y.Z-beta.N` (e.g., `v1.2.3-beta.1`)
  - Feature complete, stabilizing
  - May have minor bugs

- **Release Candidate**: `vX.Y.Z-rc.N` (e.g., `v1.2.3-rc.1`)
  - Final testing before stable release
  - No new features, bug fixes only

---

## Prerequisites

### Required Tools
- **git**: Version control
- **git-chglog**: Changelog generation (optional, installed automatically in CI)
  ```bash
  wget https://github.com/git-chglog/git-chglog/releases/download/v0.15.4/git-chglog_0.15.4_linux_amd64.tar.gz
  tar -xzf git-chglog_0.15.4_linux_amd64.tar.gz
  sudo mv git-chglog /usr/local/bin/
  ```

### Repository State
- Clean working directory (no uncommitted changes)
- All tests passing
- On correct branch (typically `master` for stable releases)
- Synced with remote

### Commit Message Format
All commits must follow conventional commit format:
```
type(scope): description

Examples:
feat: add new connection mode
fix: resolve timeout issue
docs: update installation guide
perf: optimize profile cache
```

**Valid types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`

---

## Creating a Release

### Method 1: Using Helper Script (Recommended)

The `create-release.sh` script automates the entire process with validation:

```bash
# Stable release
./scripts/create-release.sh 1.2.3

# Pre-release
./scripts/create-release.sh 1.2.3 alpha   # Creates v1.2.3-alpha.1
./scripts/create-release.sh 1.2.3 beta    # Creates v1.2.3-beta.1
./scripts/create-release.sh 1.2.3 rc      # Creates v1.2.3-rc.1
```

The script will:
1. Validate version format
2. Check repository state
3. Run full test suite
4. Test release workflow
5. Create annotated git tag
6. Show push instructions

**After script completes:**
```bash
# Review the tag
git show v1.2.3

# Push to trigger release
git push origin v1.2.3
```

### Method 2: Manual Process

If you prefer manual control:

```bash
# 1. Ensure clean state
git status

# 2. Run tests
./tests/run_tests.sh

# 3. Test release workflow
./scripts/test-release-workflow.sh 1.2.3

# 4. Create annotated tag
git tag -a v1.2.3 -m "Release v1.2.3

Summary of changes:
- Feature X
- Bug fix Y
- Performance improvement Z
"

# 5. Push tag
git push origin v1.2.3
```

---

## Release Workflow

### Automatic Process

Once you push a version tag, GitHub Actions automatically:

1. **Validates Tag**
   - Extracts version information
   - Determines if pre-release

2. **Runs Tests**
   - Full test suite execution
   - All tests must pass

3. **Builds Artifacts**
   - Injects version into source files
   - Creates directory structure
   - Generates tarball
   - Creates SHA256 checksum
   - Signs with GPG (if configured)

4. **Generates Changelog**
   - Parses conventional commits
   - Groups by type (features, fixes, etc.)
   - Generates markdown

5. **Creates GitHub Release**
   - Uploads artifacts
   - Adds release notes
   - Marks as pre-release if applicable

6. **Validates Release**
   - Verifies checksum
   - Tests artifact structure
   - Validates installation

### Workflow Jobs

The release workflow consists of several jobs:

```
validate-tag → run-tests → build-release → validate-release
                                ↓
                         create-github-release
```

Each job must succeed for the release to complete.

---

## Testing Before Release

### Test Release Workflow

Always test the release workflow before creating a real release:

```bash
./scripts/test-release-workflow.sh

# Or test with specific version
./scripts/test-release-workflow.sh 1.99.99-test.1
```

This tests:
- ✓ Version injection into scripts
- ✓ Changelog generation
- ✓ Artifact creation and structure
- ✓ Checksum generation and verification
- ✓ Tarball compression and extraction
- ✓ Installation script syntax
- ✓ GitHub Actions workflow syntax
- ✓ Tag format validation

### Expected Output

```
=========================================
Release Workflow Test
=========================================

[TEST] Version injection script exists and is executable
✓ PASS Version injection script exists and is executable

[TEST] Version injected into src/vpn banner
✓ PASS Version injected into src/vpn banner

...

=========================================
Test Results Summary
=========================================

Tests Passed: 25
Tests Failed: 0

✓ All tests passed!
```

---

## Artifact Structure

### Release Archive Contents

Each release creates a `protonvpn-manager-X.Y.Z.tar.gz` with:

```
protonvpn-manager-X.Y.Z/
├── src/                          # All source scripts with version injected
│   ├── vpn                       # Main CLI (with --version flag)
│   ├── vpn-manager
│   ├── vpn-connector
│   ├── vpn-error-handler
│   ├── vpn-utils
│   ├── vpn-colors
│   ├── vpn-validators
│   ├── vpn-doctor
│   └── best-vpn-profile
├── install.sh                    # Installation script
├── uninstall.sh                  # Uninstallation script
├── README.md                     # Project documentation
├── LICENSE                       # MIT License
├── SECURITY.md                   # Security policy
├── CHANGELOG.md                  # Release-specific changelog
└── docs/
    └── CONTRIBUTING.md           # Development guidelines
```

### Artifact Files

Each release includes:

1. **protonvpn-manager-X.Y.Z.tar.gz** - Main archive
2. **protonvpn-manager-X.Y.Z.tar.gz.sha256** - SHA256 checksum
3. **protonvpn-manager-X.Y.Z.tar.gz.asc** - GPG signature (if configured)

### Version Injection

The release workflow automatically injects the version into:

- `src/vpn`: Banner, VERSION constant, --version flag
- `src/vpn-manager`: VERSION constant
- `src/vpn-connector`: VERSION constant
- `install.sh`: Version comment

Users can check version:
```bash
vpn --version
# Output: VPN Manager v1.2.3
#         Artix/Arch Linux Edition
```

---

## GPG Signing

### Setup (Optional)

GPG signing is optional but recommended for security.

#### Generate GPG Key (if needed)

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, no expiration
# Use: your-email@example.com
```

#### Export Private Key

```bash
# Export private key
gpg --export-secret-keys -a your-email@example.com > private-key.asc

# Get key ID
gpg --list-secret-keys --keyid-format LONG
```

#### Configure GitHub Secrets

Add to repository secrets (Settings → Secrets → Actions):

1. **GPG_PRIVATE_KEY**: Content of `private-key.asc`
2. **GPG_PASSPHRASE**: Passphrase for the key

### Verification

Users can verify signed releases:

```bash
# Import public key
gpg --keyserver keyserver.ubuntu.com --recv-keys YOUR_KEY_ID

# Verify signature
gpg --verify protonvpn-manager-1.2.3.tar.gz.asc protonvpn-manager-1.2.3.tar.gz
```

---

## Troubleshooting

### Common Issues

#### Tag Already Exists

```
Error: Tag v1.2.3 already exists
```

**Solution**: Use a different version or delete the tag:
```bash
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3
```

#### Tests Failing

```
✗ Tests failed
```

**Solution**: Fix test failures before releasing:
```bash
./tests/run_tests.sh
# Fix any failing tests
```

#### Workflow Validation Failed

```
✗ Release workflow test failed
```

**Solution**: Run detailed test to see what failed:
```bash
./scripts/test-release-workflow.sh 1.2.3
# Fix reported issues
```

#### Uncommitted Changes

```
Error: Working directory has uncommitted changes
```

**Solution**: Commit or stash changes:
```bash
git status
git add .
git commit -m "chore: prepare for release"
```

#### Branch Not Synced

```
Error: Local branch is behind remote
```

**Solution**: Pull latest changes:
```bash
git pull origin master
```

### Workflow Debugging

If the GitHub Actions workflow fails:

1. **Check Actions Tab**
   - Go to: https://github.com/maxrantil/protonvpn-manager/actions
   - Click on failed workflow
   - Review logs for each job

2. **Common Workflow Failures**

   - **Test failures**: Fix tests and re-push tag
   - **Artifact creation**: Check file permissions, paths
   - **Changelog generation**: Ensure git-chglog installed in workflow
   - **GPG signing**: Verify secrets are configured correctly

3. **Re-running Failed Release**

   ```bash
   # Delete failed release
   gh release delete v1.2.3 --yes

   # Delete tag locally and remotely
   git tag -d v1.2.3
   git push origin :refs/tags/v1.2.3

   # Fix issues, then recreate
   ./scripts/create-release.sh 1.2.3
   git push origin v1.2.3
   ```

### Getting Help

If you encounter issues:

1. Check workflow logs in GitHub Actions
2. Run local test suite: `./scripts/test-release-workflow.sh`
3. Review this documentation
4. Check [CONTRIBUTING.md](/path/to/protonvpn-manager/CONTRIBUTING.md)
5. Open an issue with `[release]` prefix

---

## Best Practices

### Before Every Release

- [ ] All tests passing locally
- [ ] Clean working directory
- [ ] Updated documentation if needed
- [ ] Reviewed recent commits
- [ ] Tested release workflow script
- [ ] Verified conventional commit format

### Version Numbering

Follow semantic versioning:

- **MAJOR**: Breaking changes (v1.0.0 → v2.0.0)
- **MINOR**: New features, backward compatible (v1.0.0 → v1.1.0)
- **PATCH**: Bug fixes, backward compatible (v1.0.0 → v1.0.1)

### Changelog Quality

Ensure commits follow conventional format:
- Use clear, descriptive commit messages
- Include issue references (#123)
- Group related changes
- Explain breaking changes in commit body

### Pre-release Testing

For major releases:
1. Create alpha → test → fix
2. Create beta → broader testing → fix
3. Create rc → final validation
4. Create stable release

---

## Examples

### Example 1: Stable Release

```bash
# Prepare
git checkout master
git pull origin master
./tests/run_tests.sh

# Create release
./scripts/create-release.sh 1.2.3

# Push
git push origin v1.2.3
```

### Example 2: Pre-release Series

```bash
# Alpha testing
./scripts/create-release.sh 1.3.0 alpha    # v1.3.0-alpha.1
git push origin v1.3.0-alpha.1

# After fixes
./scripts/create-release.sh 1.3.0 alpha    # v1.3.0-alpha.2
git push origin v1.3.0-alpha.2

# Beta testing
./scripts/create-release.sh 1.3.0 beta     # v1.3.0-beta.1
git push origin v1.3.0-beta.1

# Release candidate
./scripts/create-release.sh 1.3.0 rc       # v1.3.0-rc.1
git push origin v1.3.0-rc.1

# Stable release
./scripts/create-release.sh 1.3.0          # v1.3.0
git push origin v1.3.0
```

### Example 3: Hotfix Release

```bash
# Create hotfix branch
git checkout master
git checkout -b hotfix/1.2.4

# Make fixes
git commit -m "fix: critical bug in connection handler"

# Merge to master
git checkout master
git merge hotfix/1.2.4

# Release
./scripts/create-release.sh 1.2.4
git push origin master
git push origin v1.2.4
```

---

## Automation Summary

The release workflow automates:

✅ Version injection into source files
✅ Changelog generation from commits
✅ Artifact creation with proper structure
✅ Checksum generation (SHA256)
✅ Optional GPG signing
✅ GitHub release creation
✅ Release notes formatting
✅ Artifact validation
✅ Pre-release detection and marking

Manual steps required:

⚠️ Creating the version tag
⚠️ Pushing tag to trigger workflow
⚠️ Reviewing generated release notes
⚠️ Publishing release (if draft)

---

## References

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [git-chglog Documentation](https://github.com/git-chglog/git-chglog)
- [GitHub Actions - Releases](https://docs.github.com/en/actions/guides/about-packaging-with-github-actions)

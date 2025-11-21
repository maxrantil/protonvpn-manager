# Smoke Tests

Post-deployment smoke tests for VPN Manager - fast, minimal validation that installation succeeded.

## Overview

Smoke tests verify that:
- ✅ All 9 components are installed correctly
- ✅ File permissions are correct (755)
- ✅ Configuration directories exist
- ✅ Help commands respond properly
- ✅ `vpn doctor --post-install` validation passes

## Quick Start

### Run All Smoke Tests

```bash
./tests/smoke/run_smoke_tests.sh
```

### Run Individual Test Suites

```bash
# Post-installation validation
./tests/smoke/test_post_install.sh

# Help command validation
./tests/smoke/test_help_commands.sh
```

### Run with vpn doctor

```bash
vpn-doctor --post-install
```

## Test Suites

### 1. Post-Installation Tests (`test_post_install.sh`)

Validates that installation completed successfully:
- All 9 required components installed in `/usr/local/bin/`:
  - `vpn`, `vpn-manager`, `vpn-connector`
  - `vpn-error-handler`, `vpn-utils`, `vpn-colors`
  - `vpn-validators`, `best-vpn-profile`, `vpn-doctor`
- Components have correct permissions (755)
- Components are executable
- Config directory exists (`~/.config/vpn`)
- Locations directory exists (`~/.config/vpn/locations`)
- `vpn doctor --post-install` passes

**Tests**: 30 checks
**Runtime**: < 5 seconds

### 2. Help Command Tests (`test_help_commands.sh`)

Validates that help commands work:
- All components respond to `--help`
- Help output contains usage information
- `vpn help` command works

**Tests**: 11 checks
**Runtime**: < 3 seconds

## Docker Testing

Test installation across multiple Linux distributions:

```bash
# Test on all distributions (Arch, Artix, Ubuntu)
./tests/smoke/docker/run_docker_tests.sh

# Test specific distribution
docker build -f tests/smoke/docker/Dockerfile.arch -t vpn-test-arch .
docker run --rm vpn-test-arch
```

### Supported Distributions

- **Arch Linux** (`Dockerfile.arch`)
- **Artix Linux** (`Dockerfile.artix`)
- **Ubuntu 22.04** (`Dockerfile.ubuntu`)

Each Dockerfile:
1. Installs system dependencies
2. Creates non-root test user
3. Runs `./install.sh`
4. Executes smoke tests

**Runtime**: ~2-5 minutes per distribution (with image builds)

## Exit Codes

All smoke test scripts use standard exit codes:

- **0**: All tests passed
- **1**: One or more tests failed

## Integration with CI/CD

Smoke tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions integration
- name: Run Smoke Tests
  run: ./tests/smoke/run_smoke_tests.sh

- name: Docker Smoke Tests
  run: ./tests/smoke/docker/run_docker_tests.sh
```

## Test Philosophy

Smoke tests follow these principles:

1. **Minimal**: Only test critical functionality
2. **Fast**: Complete in seconds, not minutes
3. **Reliable**: No false positives
4. **Post-deployment**: Run after installation
5. **No network**: Don't require internet or VPN credentials

## When to Run Smoke Tests

- ✅ After running `./install.sh`
- ✅ Before first use of VPN Manager
- ✅ After upgrading to new version
- ✅ In CI/CD pipelines (post-release)
- ✅ When debugging installation issues

## Troubleshooting

### All tests failing

Check that you've run `./install.sh` first:

```bash
./install.sh
./tests/smoke/run_smoke_tests.sh
```

### vpn-doctor not found

Install vpn-doctor manually:

```bash
sudo cp src/vpn-doctor /usr/local/bin/
sudo chmod 755 /usr/local/bin/vpn-doctor
```

### Permission errors

Ensure components have correct permissions:

```bash
sudo chmod 755 /usr/local/bin/vpn*
sudo chmod 755 /usr/local/bin/best-vpn-profile
```

### Docker tests failing

Ensure Docker is installed and running:

```bash
docker --version
docker ps
```

## Development

### Adding New Smoke Tests

1. Create test script in `tests/smoke/`
2. Use consistent test framework:
   ```bash
   log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)) }
   log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED++)) }
   ```
3. Exit with 0 (pass) or 1 (fail)
4. Add to `run_smoke_tests.sh`

### Test Naming Convention

- `test_*.sh` - Individual test suites
- `run_*.sh` - Test runners/orchestrators

## See Also

- [Main Test Suite](../run_tests.sh) - Comprehensive unit/integration tests
- [Security Tests](../security/) - Security-focused test suites
- [Installation Guide](../../install.sh) - Installation script
- [VPN Doctor](../../src/vpn-doctor) - Diagnostic tool

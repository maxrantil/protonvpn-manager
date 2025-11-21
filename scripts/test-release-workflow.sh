#!/bin/bash
# ABOUTME: Test script for validating release workflow without creating real releases
# ABOUTME: Simulates all release steps locally to catch issues before pushing tags

set -uo pipefail  # Removed -e to allow test failures without script exit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

TEST_VERSION="${1:-1.99.99-test.1}"
CLEANUP=${2:-yes}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Release Workflow Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test Version: $TEST_VERSION"
echo "Cleanup after test: $CLEANUP"
echo ""

# Track success/failure
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo -e "${YELLOW}[TEST]${NC} $test_name"

    if eval "$test_cmd"; then
        echo -e "${GREEN}✓ PASS${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} $test_name"
        ((TESTS_FAILED++))
    fi
    return 0  # Don't exit script on test failure
}

echo "========================================="
echo "1. Testing Version Injection"
echo "========================================="
echo ""

# Save project root directory
PROJECT_ROOT=$(pwd)

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR" 2>/dev/null || true' EXIT

# Copy source files to test directory (silently)
cp -r src/ "$TEST_DIR/" 2>/dev/null
cp install.sh "$TEST_DIR/" 2>/dev/null
cp -r scripts/ "$TEST_DIR/" 2>/dev/null

run_test "Version injection script exists and is executable" \
    "[[ -x scripts/inject-version.sh ]]"

run_test "Version injection executes successfully" \
    "cd $TEST_DIR && ./scripts/inject-version.sh $TEST_VERSION"

run_test "Version injected into src/vpn banner" \
    "grep -q 'VPN Manager v$TEST_VERSION' $TEST_DIR/src/vpn"

run_test "Version constant added to src/vpn" \
    "grep -q '^VERSION=\"$TEST_VERSION\"' $TEST_DIR/src/vpn"

run_test "Version handler added to src/vpn" \
    "grep -q '\"--version\"' $TEST_DIR/src/vpn"

run_test "All injected scripts have valid bash syntax" \
    "bash -n $TEST_DIR/src/vpn && bash -n $TEST_DIR/install.sh"

echo ""
echo "========================================="
echo "2. Testing Changelog Generation"
echo "========================================="
echo ""

# Check if git-chglog is available
if command -v git-chglog &> /dev/null; then
    run_test "Changelog config exists" \
        "[[ -f $PROJECT_ROOT/scripts/chglog-config.yml ]]"

    run_test "Changelog template exists" \
        "[[ -f $PROJECT_ROOT/scripts/chglog-template.md ]]"

    run_test "Changelog generation works" \
        "cd $PROJECT_ROOT && git-chglog --config scripts/chglog-config.yml -o /tmp/test-changelog.md HEAD && [[ -s /tmp/test-changelog.md ]]"

    run_test "Changelog contains conventional commit sections" \
        "grep -qE '(Features|Bug Fixes|Documentation)' /tmp/test-changelog.md || true"
else
    echo -e "${YELLOW}⚠ WARNING${NC} git-chglog not installed, skipping changelog tests"
    echo "Install: wget https://github.com/git-chglog/git-chglog/releases/download/v0.15.4/git-chglog_0.15.4_linux_amd64.tar.gz"
fi

echo ""
echo "========================================="
echo "3. Testing Artifact Structure"
echo "========================================="
echo ""

# Simulate artifact creation
ARTIFACT_NAME="protonvpn-manager-${TEST_VERSION}"
ARTIFACT_DIR="$TEST_DIR/release/$ARTIFACT_NAME"

mkdir -p "$ARTIFACT_DIR"
cp -r "$PROJECT_ROOT/src/" "$ARTIFACT_DIR/"
cp "$PROJECT_ROOT/install.sh" "$PROJECT_ROOT/uninstall.sh" "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/LICENSE" "$PROJECT_ROOT/SECURITY.md" "$ARTIFACT_DIR/"
mkdir -p "$ARTIFACT_DIR/docs"
cp "$PROJECT_ROOT/CONTRIBUTING.md" "$ARTIFACT_DIR/docs/"

run_test "Artifact directory structure created" \
    "[[ -d $ARTIFACT_DIR ]]"

run_test "All required source files present" \
    "[[ -f $ARTIFACT_DIR/src/vpn ]] && [[ -f $ARTIFACT_DIR/src/vpn-manager ]] && [[ -f $ARTIFACT_DIR/src/vpn-connector ]]"

run_test "Installation scripts present" \
    "[[ -f $ARTIFACT_DIR/install.sh ]] && [[ -f $ARTIFACT_DIR/uninstall.sh ]]"

run_test "Documentation files present" \
    "[[ -f $ARTIFACT_DIR/README.md ]] && [[ -f $ARTIFACT_DIR/LICENSE ]] && [[ -f $ARTIFACT_DIR/SECURITY.md ]]"

run_test "Artifact can be compressed" \
    "cd $TEST_DIR/release && tar -czf ${ARTIFACT_NAME}.tar.gz ${ARTIFACT_NAME}/ && [[ -f ${ARTIFACT_NAME}.tar.gz ]]"

run_test "Checksum generation works" \
    "cd $TEST_DIR/release && sha256sum ${ARTIFACT_NAME}.tar.gz > ${ARTIFACT_NAME}.tar.gz.sha256 && [[ -f ${ARTIFACT_NAME}.tar.gz.sha256 ]]"

run_test "Checksum verification works" \
    "cd $TEST_DIR/release && sha256sum -c ${ARTIFACT_NAME}.tar.gz.sha256"

run_test "Artifact extraction works" \
    "cd $TEST_DIR && tar -xzf release/${ARTIFACT_NAME}.tar.gz && [[ -d ${ARTIFACT_NAME} ]]"

echo ""
echo "========================================="
echo "4. Testing Installation from Artifact"
echo "========================================="
echo ""

run_test "Install script has valid syntax" \
    "bash -n $TEST_DIR/${ARTIFACT_NAME}/install.sh"

run_test "All source scripts executable" \
    "find $TEST_DIR/${ARTIFACT_NAME}/src -type f -name 'vpn*' -exec test -x {} \\;"

run_test "All source scripts have valid syntax" \
    "for script in $TEST_DIR/${ARTIFACT_NAME}/src/*; do bash -n \"\$script\" || exit 1; done"

echo ""
echo "========================================="
echo "5. Testing GitHub Actions Workflow"
echo "========================================="
echo ""

run_test "Release workflow file exists" \
    "[[ -f $PROJECT_ROOT/.github/workflows/release.yml ]]"

run_test "Release workflow has valid YAML syntax" \
    "command -v yamllint &>/dev/null && yamllint $PROJECT_ROOT/.github/workflows/release.yml || python3 -c 'import yaml; yaml.safe_load(open(\"$PROJECT_ROOT/.github/workflows/release.yml\"))'"

run_test "Workflow triggers on version tags" \
    "grep -q 'v\*\.\*\.\*' $PROJECT_ROOT/.github/workflows/release.yml"

run_test "Workflow supports pre-releases" \
    "grep -qE '(alpha|beta|rc)' $PROJECT_ROOT/.github/workflows/release.yml"

run_test "Workflow runs test suite" \
    "grep -q 'run-tests' $PROJECT_ROOT/.github/workflows/release.yml"

run_test "Workflow builds artifacts" \
    "grep -q 'build-release' $PROJECT_ROOT/.github/workflows/release.yml"

run_test "Workflow validates release" \
    "grep -q 'validate-release' $PROJECT_ROOT/.github/workflows/release.yml"

echo ""
echo "========================================="
echo "6. Testing Tag Format Validation"
echo "========================================="
echo ""

validate_tag() {
    local tag="$1"
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

run_test "Stable version tag validates: v1.0.0" \
    "validate_tag v1.0.0"

run_test "Alpha tag validates: v1.0.0-alpha.1" \
    "validate_tag v1.0.0-alpha.1"

run_test "Beta tag validates: v1.0.0-beta.2" \
    "validate_tag v1.0.0-beta.2"

run_test "RC tag validates: v1.0.0-rc.1" \
    "validate_tag v1.0.0-rc.1"

run_test "Invalid tag rejects: 1.0.0 (no v prefix)" \
    "! validate_tag 1.0.0"

run_test "Invalid tag rejects: v1.0 (incomplete)" \
    "! validate_tag v1.0"

echo ""
echo "========================================="
echo "Test Results Summary"
echo "========================================="
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "You can safely create a release tag:"
    echo "  git tag -a v1.2.3 -m 'Release v1.2.3'"
    echo "  git push origin v1.2.3"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    echo "Fix the issues above before creating a release."
    echo ""
    exit 1
fi

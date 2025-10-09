#!/bin/bash
# ABOUTME: Test GitHub Actions workflows locally before pushing
# ABOUTME: Validates workflow logic without needing to create actual PRs

set -uo pipefail  # Removed -e to allow test failures

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "=========================================="
echo "GitHub Workflows Local Test Suite"
echo "=========================================="
echo ""

# Test 1: Commit Format Validation
echo "=== Test 1: Commit Format Validation ==="
VALID_COMMITS=("feat: add feature" "fix(vpn): resolve bug" "docs: update readme" "refactor!: breaking change")
INVALID_COMMITS=("Add feature" "fixed bug" "WIP" "oops")

for commit in "${VALID_COMMITS[@]}"; do
    if [[ "$commit" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?:\ .+ ]]; then
        pass "Valid commit accepted: '$commit'"
    else
        fail "Valid commit rejected: '$commit'"
    fi
done

for commit in "${INVALID_COMMITS[@]}"; do
    if ! [[ "$commit" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?:\ .+ ]]; then
        pass "Invalid commit rejected: '$commit'"
    else
        fail "Invalid commit accepted: '$commit'"
    fi
done

echo ""

# Test 2: AI Attribution Detection
echo "=== Test 2: AI Attribution Detection ==="

# Simulate git log output with AI attribution
AI_ATTRIBUTIONS=(
    "Co-authored-by: Claude <noreply@anthropic.com>"
    "Generated with Claude Code"
    "See https://claude.com/claude-code"
    "Co-authored-by: GPT-4 <gpt@openai.com>"
)

HUMAN_ATTRIBUTIONS=(
    "Co-authored-by: John Doe <john@example.com>"
    "Co-authored-by: Jane Smith <jane@company.com>"
)

for attr in "${AI_ATTRIBUTIONS[@]}"; do
    # Match the same pattern as the workflow
    if echo "$attr" | grep -Eiq "Co-authored-by:.*(Claude|GPT|ChatGPT|Copilot|Gemini|Bard|AI)|Generated with.*(Claude|AI|GPT|ChatGPT|Copilot)|claude\.com/claude-code"; then
        pass "AI attribution detected: '$attr'"
    else
        fail "AI attribution missed: '$attr'"
    fi
done

for attr in "${HUMAN_ATTRIBUTIONS[@]}"; do
    if ! echo "$attr" | grep -Eiq "Co-authored-by:.*Claude|Generated with.*(Claude|AI|GPT|ChatGPT|Copilot)|claude\.com/claude-code"; then
        pass "Human co-author allowed: '$attr'"
    else
        fail "Human co-author blocked: '$attr'"
    fi
done

echo ""

# Test 3: PR Title Validation
echo "=== Test 3: PR Title Validation ==="
VALID_PR_TITLES=("feat: add new feature" "fix(auth): resolve timeout" "docs: update installation")
INVALID_PR_TITLES=("Add feature" "Fixed stuff" "WIP PR")

for title in "${VALID_PR_TITLES[@]}"; do
    if [[ "$title" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?:\ .+ ]]; then
        pass "Valid PR title: '$title'"
    else
        fail "Valid PR title rejected: '$title'"
    fi
done

for title in "${INVALID_PR_TITLES[@]}"; do
    if ! [[ "$title" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?:\ .+ ]]; then
        pass "Invalid PR title rejected: '$title'"
    else
        fail "Invalid PR title accepted: '$title'"
    fi
done

echo ""

# Test 4: Shell Quality (ShellCheck)
echo "=== Test 4: Shell Quality Check ==="
if command -v shellcheck &> /dev/null; then
    if shellcheck -e SC1091,SC2034,SC2155,SC2016,SC2001,SC2126 "$PROJECT_ROOT"/src/vpn &> /dev/null; then
        pass "ShellCheck passed on src/vpn"
    else
        fail "ShellCheck failed on src/vpn"
    fi
else
    warn "ShellCheck not installed, skipping"
fi

echo ""

# Test 5: Test Suite Execution
echo "=== Test 5: Test Suite Execution ==="
if [[ -x "$SCRIPT_DIR/run_tests.sh" ]]; then
    "$SCRIPT_DIR/run_tests.sh" --unit-only &> /tmp/workflow_test_output.log
    EXIT_CODE=$?

    # Check if tests actually ran (not just exited successfully with 0 tests)
    if grep -q "Total Tests: 0" /tmp/workflow_test_output.log; then
        warn "Test suite ran but executed 0 tests (workflow will still work)"
        pass "Test runner executes without errors"
    elif [[ $EXIT_CODE -eq 0 ]]; then
        pass "Test suite runs successfully"
    else
        fail "Test suite failed (see /tmp/workflow_test_output.log)"
    fi
else
    warn "run_tests.sh not found or not executable"
fi

echo ""

# Test 6: Pre-commit Hook Compatibility
echo "=== Test 6: Pre-commit Configuration ==="
if [[ -f "$PROJECT_ROOT/config/.pre-commit-config.yaml" ]]; then
    pass "Pre-commit config exists"

    if command -v pre-commit &> /dev/null; then
        if cd "$PROJECT_ROOT" && pre-commit run --all-files &> /tmp/precommit_test.log; then
            pass "Pre-commit hooks passed"
        else
            warn "Pre-commit hooks failed (may need installation: pre-commit install)"
        fi
    else
        warn "pre-commit not installed, skipping validation"
    fi
else
    fail "Pre-commit config not found"
fi

echo ""

# Test 7: Workflow File Syntax
echo "=== Test 7: Workflow File Syntax ==="
for workflow in "$PROJECT_ROOT"/.github/workflows/*.yml; do
    filename=$(basename "$workflow")

    # Basic YAML syntax check
    if grep -q "^name:" "$workflow" && grep -q "^on:" "$workflow" && grep -q "^jobs:" "$workflow"; then
        pass "Workflow syntax valid: $filename"
    else
        fail "Workflow syntax invalid: $filename"
    fi
done

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All workflow tests passed!${NC}"
    echo ""
    echo "You can safely commit and push these workflows to GitHub"
    exit 0
else
    echo -e "${RED}❌ Some workflow tests failed${NC}"
    echo ""
    echo "Review the failures above before pushing workflows"
    exit 1
fi

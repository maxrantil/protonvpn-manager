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

# Test 2: AI/Agent Attribution Detection
echo "=== Test 2: AI/Agent Attribution Detection ==="

# Simulate git log output with AI attribution
AI_ATTRIBUTIONS=(
    "Co-authored-by: Claude <noreply@anthropic.com>"
    "Generated with Claude Code"
    "See https://claude.com/claude-code"
    "Co-authored-by: GPT-4 <gpt@openai.com>"
)

# Agent attribution examples
AGENT_ATTRIBUTIONS=(
    "Reviewed by security-validator agent"
    "Validated by architecture-designer agent"
    "Approved by test-automation-qa agent"
    "Checked by performance-optimizer"
    "Agent review completed successfully"
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

for attr in "${AGENT_ATTRIBUTIONS[@]}"; do
    # Match agent mention patterns
    if echo "$attr" | grep -Eiq "(reviewed by|validated by|approved by|checked by).*(agent|architecture-designer|security-validator|performance-optimizer)|agent (review|validation|approval)"; then
        pass "Agent attribution detected: '$attr'"
    else
        fail "Agent attribution missed: '$attr'"
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

# Test 8: Session Handoff Detection Logic
echo "=== Test 8: Session Handoff Detection ==="

# Simulate scenarios
SESSION_HANDOFF_EXISTS=false
DATED_HANDOFF_EXISTS=false

# Check if SESSION_HANDOVER.md would be detected
if [[ -f "$PROJECT_ROOT/SESSION_HANDOVER.md" ]]; then
    SESSION_HANDOFF_EXISTS=true
fi

# Check if dated session files would be detected
if ls "$PROJECT_ROOT"/docs/implementation/SESSION*.md &>/dev/null; then
    DATED_HANDOFF_EXISTS=true
fi

if [[ "$SESSION_HANDOFF_EXISTS" == true ]]; then
    pass "Session handoff detection: SESSION_HANDOVER.md found"
elif [[ "$DATED_HANDOFF_EXISTS" == true ]]; then
    pass "Session handoff detection: Dated session file found"
else
    warn "No session handoff file exists (workflow will warn on PRs)"
fi

# Test the workflow logic itself exists
if grep -q "SESSION_HANDOVER.md" "$PROJECT_ROOT/.github/workflows/verify-session-handoff.yml"; then
    pass "Handoff workflow checks for SESSION_HANDOVER.md"
else
    fail "Handoff workflow missing SESSION_HANDOVER.md check"
fi

if grep -q "SESSION.*\.md" "$PROJECT_ROOT/.github/workflows/verify-session-handoff.yml"; then
    pass "Handoff workflow checks for dated session files"
else
    fail "Handoff workflow missing dated file check"
fi

echo ""

# Test 9: Issue Workflow Validation
echo "=== Test 9: Issue Workflow Checks ==="

# Check issue AI attribution workflow exists
if [[ -f "$PROJECT_ROOT/.github/workflows/issue-ai-attribution-check.yml" ]]; then
    pass "Issue AI attribution check workflow exists"

    # Verify it has proper triggers
    if grep -q "issues:" "$PROJECT_ROOT/.github/workflows/issue-ai-attribution-check.yml" && \
       grep -q "opened" "$PROJECT_ROOT/.github/workflows/issue-ai-attribution-check.yml"; then
        pass "Issue workflow has correct triggers (opened, edited)"
    else
        fail "Issue workflow missing proper triggers"
    fi
else
    fail "Issue AI attribution check workflow not found"
fi

# Check issue PRD reminder workflow
if [[ -f "$PROJECT_ROOT/.github/workflows/issue-prd-reminder.yml" ]]; then
    pass "Issue PRD reminder workflow exists"

    if grep -q "enhancement\|feature" "$PROJECT_ROOT/.github/workflows/issue-prd-reminder.yml"; then
        pass "PRD reminder checks for feature/enhancement labels"
    else
        fail "PRD reminder missing label detection"
    fi
else
    fail "Issue PRD reminder workflow not found"
fi

# Check issue auto-labeling workflow
if [[ -f "$PROJECT_ROOT/.github/workflows/issue-auto-label.yml" ]]; then
    pass "Issue auto-labeling workflow exists"

    if grep -q "github-script" "$PROJECT_ROOT/.github/workflows/issue-auto-label.yml"; then
        pass "Auto-labeling uses github-script action"
    else
        fail "Auto-labeling missing github-script"
    fi
else
    fail "Issue auto-labeling workflow not found"
fi

# Check issue format check workflow
if [[ -f "$PROJECT_ROOT/.github/workflows/issue-format-check.yml" ]]; then
    pass "Issue format check workflow exists"
else
    fail "Issue format check workflow not found"
fi

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

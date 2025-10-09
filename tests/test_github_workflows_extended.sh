#!/bin/bash
# ABOUTME: Extended test cases for GitHub Actions workflows
# ABOUTME: Tests edge cases and failure scenarios not covered by main test suite

set -uo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
echo "Extended GitHub Workflows Test Suite"
echo "=========================================="
echo ""

# Test 10: Edge Case Commit Formats
echo "=== Test 10: Edge Case Commit Formats ==="

# Load the regex pattern from actual workflow
PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?!?:\ .+'

# Breaking changes with exclamation mark
EDGE_CASES=(
    "feat(api)!: breaking API change"
    "fix(core)!: breaking fix"
    "refactor!: major refactor"
)

for commit in "${EDGE_CASES[@]}"; do
    if [[ "$commit" =~ $PATTERN ]]; then
        pass "Breaking change format accepted: '$commit'"
    else
        fail "Breaking change format rejected: '$commit'"
    fi
done

# Edge cases that should FAIL
INVALID_EDGE_CASES=(
    "feat : extra space before colon"
    "feat:no space after colon"
    "FEAT: uppercase type"
    "feat(scope with spaces): invalid scope"
    "feature: wrong type name"
    "feat(): empty scope"
)

for commit in "${INVALID_EDGE_CASES[@]}"; do
    if ! [[ "$commit" =~ $PATTERN ]]; then
        pass "Invalid edge case rejected: '$commit'"
    else
        fail "Invalid edge case accepted: '$commit'"
    fi
done

echo ""

# Test 11: AI Attribution Case Variations
echo "=== Test 11: AI Attribution Case Variations ==="

AI_CASE_VARIATIONS=(
    "Co-Authored-By: Claude <email>"
    "co-authored-by: claude <email>"
    "CO-AUTHORED-BY: CLAUDE <email>"
    "generated with claude code"
    "GENERATED WITH CLAUDE CODE"
)

for attr in "${AI_CASE_VARIATIONS[@]}"; do
    # Case-insensitive grep (same as workflow)
    if echo "$attr" | grep -Eiq "Co-authored-by:.*(Claude|GPT|ChatGPT|Copilot|Gemini|Bard|AI)|Generated with.*(Claude|AI|GPT|ChatGPT|Copilot)|claude\.com/claude-code"; then
        pass "AI attribution case variation detected: '$attr'"
    else
        fail "AI attribution case variation missed: '$attr'"
    fi
done

# Subtle AI mentions that should be caught
SUBTLE_AI_MENTIONS=(
    "With help from Claude on this"
    "Thanks to ChatGPT for assistance"
    "AI-assisted development"
    "Claude helped with this code"
)

for mention in "${SUBTLE_AI_MENTIONS[@]}"; do
    if echo "$mention" | grep -Eiq "Claude|ChatGPT|GPT-4|AI.*assist|AI.*help"; then
        pass "Subtle AI mention detected: '$mention'"
    else
        warn "Subtle AI mention might be missed: '$mention'"
    fi
done

echo ""

# Test 12: Multi-line Commit Messages
echo "=== Test 12: Multi-line Commit Messages ==="

# Simulate multi-line commit with attribution in body
MULTILINE_WITH_ATTRIBUTION="feat: add new feature

This is a longer description explaining
the changes in detail.

Co-authored-by: Claude <noreply@anthropic.com>"

if echo "$MULTILINE_WITH_ATTRIBUTION" | grep -Eiq "Co-authored-by:.*(Claude|GPT|ChatGPT|Copilot|Gemini|Bard|AI)"; then
    pass "Multi-line commit attribution detected"
else
    fail "Multi-line commit attribution missed"
fi

# Valid multi-line with human co-author
MULTILINE_HUMAN="feat: add new feature

This is a longer description.

Co-authored-by: John Doe <john@example.com>"

if ! echo "$MULTILINE_HUMAN" | grep -Eiq "Co-authored-by:.*(Claude|GPT|ChatGPT|Copilot|Gemini|Bard|AI)"; then
    pass "Multi-line human co-author allowed"
else
    fail "Multi-line human co-author blocked"
fi

echo ""

# Test 13: Session Handoff Content Validation
echo "=== Test 13: Session Handoff Content Validation ==="

# Create temporary handoff files for testing
TEMP_DIR="/tmp/workflow_test_$$"
mkdir -p "$TEMP_DIR"

# Test: Empty handoff file (should fail)
touch "$TEMP_DIR/empty_handoff.md"
if [[ $(wc -l < "$TEMP_DIR/empty_handoff.md") -lt 10 ]]; then
    pass "Empty handoff file detected (< 10 lines)"
else
    fail "Empty handoff file not detected"
fi

# Test: Minimal handoff file (should warn)
cat > "$TEMP_DIR/minimal_handoff.md" << 'EOF'
# Session Handoff

Issue: #123
Completed: Some work
Next: More work
EOF

if [[ $(wc -l < "$TEMP_DIR/minimal_handoff.md") -lt 20 ]]; then
    pass "Minimal handoff file detected (< 20 lines)"
else
    fail "Minimal handoff file not detected"
fi

# Test: Complete handoff file (should pass)
cat > "$TEMP_DIR/complete_handoff.md" << 'EOF'
# Session Handoff: Issue #123

**Date**: 2025-10-09
**Issue**: #123
**PR**: #124
**Branch**: feat/issue-123

## Completed Work
- Implemented feature X
- Added tests for Y
- Updated documentation

## Current Project State
**Tests**: All passing
**Branch**: Clean

### Agent Validation Status
- [x] architecture-designer: Complete
- [x] security-validator: Complete

## Next Session Priorities
1. Review PR feedback
2. Address test coverage gaps

## Startup Prompt
Read CLAUDE.md and continue from Issue #123 completion.

**Immediate priority**: Issue #124
**Context**: Feature X implemented and tested
**Ready state**: Clean branch, all tests passing
EOF

if [[ $(wc -l < "$TEMP_DIR/complete_handoff.md") -ge 20 ]]; then
    pass "Complete handoff file validated (≥ 20 lines)"
else
    fail "Complete handoff file validation failed"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""

# Test 14: Regex Performance
echo "=== Test 14: Regex Performance ==="

# Test regex against large commit message
LARGE_COMMIT_TITLE="feat(vpn): add comprehensive connection management with automatic retry logic and fallback handling"

if [[ "$LARGE_COMMIT_TITLE" =~ $PATTERN ]]; then
    pass "Long commit title validated efficiently"
else
    fail "Long commit title rejected unexpectedly"
fi

# Test regex with special characters
SPECIAL_CHARS_COMMIT="feat(api): add OAuth2.0 support with JWT tokens & refresh"

if [[ "$LARGE_COMMIT_TITLE" =~ $PATTERN ]]; then
    pass "Commit with special characters validated"
else
    fail "Commit with special characters rejected"
fi

echo ""

# Test 15: Issue Workflow Edge Cases
echo "=== Test 15: Issue Workflow Edge Cases ==="

# Test: Empty issue body
EMPTY_ISSUE_BODY=""
if [[ ${#EMPTY_ISSUE_BODY} -lt 20 ]]; then
    pass "Empty issue body detected (< 20 chars)"
else
    fail "Empty issue body not detected"
fi

# Test: Issue with only whitespace
WHITESPACE_ISSUE="

   "
if [[ ${#WHITESPACE_ISSUE} -lt 20 ]] || [[ -z "${WHITESPACE_ISSUE// /}" ]]; then
    pass "Whitespace-only issue detected"
else
    fail "Whitespace-only issue not detected"
fi

# Test: Very short issue
SHORT_ISSUE="bug fix needed"
if [[ ${#SHORT_ISSUE} -lt 20 ]]; then
    pass "Short issue detected (< 20 chars)"
else
    fail "Short issue not detected"
fi

echo ""

echo "=========================================="
echo "Extended Test Summary"
echo "=========================================="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All extended tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some extended tests failed${NC}"
    exit 1
fi

# GitHub Issue Template with TDD Checklist

Use this template for all GitHub issues to ensure TDD compliance.

## Issue Template

```markdown
## Summary
[Brief description of what needs to be built/fixed]

## Problem Statement
[Why is this needed? What problem does it solve?]

## Acceptance Criteria
- [ ] [Specific, testable requirement 1]
- [ ] [Specific, testable requirement 2]
- [ ] [Specific, testable requirement 3]

## TDD Checklist (MANDATORY)
- [ ] **RED Phase**: Tests written first and confirmed to fail for the right reason
- [ ] **GREEN Phase**: Minimal code written to make tests pass
- [ ] **REFACTOR Phase**: Code improved while keeping all tests green
- [ ] **Unit Tests**: Individual functions/components tested in isolation
- [ ] **Integration Tests**: Component interactions tested
- [ ] **End-to-End Tests**: Complete workflows tested
- [ ] **Test Quality**: All tests pass and output is pristine
- [ ] **No Production Code**: No implementation written without failing test first

## Implementation Plan
[Break down into TDD cycles if complex]

### Cycle 1: [Feature Name]
1. Write failing test for [specific behavior]
2. Implement minimal code to pass
3. Refactor while keeping tests green

### Cycle 2: [Next Feature]
1. Write failing test for [specific behavior]
2. Implement minimal code to pass
3. Refactor while keeping tests green

## Dependencies
[What needs to be complete before starting this work?]

## Definition of Done
- [ ] All acceptance criteria met
- [ ] All TDD checklist items completed
- [ ] Implementation plan phase updated (if applicable)
- [ ] Code reviewed and merged
```

## GitHub CLI Command

```bash
gh issue create --title "Your Issue Title" --body "$(cat <<'EOF'
## Summary
[Brief description of what needs to be built/fixed]

## Problem Statement
[Why is this needed? What problem does it solve?]

## Acceptance Criteria
- [ ] [Specific, testable requirement 1]
- [ ] [Specific, testable requirement 2]

## TDD Checklist (MANDATORY)
- [ ] **RED Phase**: Tests written first and confirmed to fail for the right reason
- [ ] **GREEN Phase**: Minimal code written to make tests pass
- [ ] **REFACTOR Phase**: Code improved while keeping all tests green
- [ ] **Unit Tests**: Individual functions/components tested in isolation
- [ ] **Integration Tests**: Component interactions tested
- [ ] **End-to-End Tests**: Complete workflows tested
- [ ] **Test Quality**: All tests pass and output is pristine
- [ ] **No Production Code**: No implementation written without failing test first

## Implementation Plan
[Break down into TDD cycles]

## Dependencies
[Prerequisites for starting this work]
EOF
)"
```

## Usage Notes

1. **Every issue MUST include the TDD checklist**
2. **Check off items as you complete them during development**
3. **Never mark an issue complete until all checklist items are done**
4. **Use the issue comments to document your RED-GREEN-REFACTOR cycles**
5. **Reference specific test names and results in comments**

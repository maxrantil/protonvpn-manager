# GitHub Actions Workflows Documentation

This directory contains automated workflows that enforce project standards and quality requirements.

## Workflow Overview

### Pull Request Workflows (Run on every PR to master)

| Workflow | Purpose | Blocks PR? | Runtime |
|----------|---------|------------|---------|
| `pr-title-check.yml` | Validates PR title follows conventional commit format | ✅ Yes | ~5s |
| `commit-format.yml` | Validates all commits follow conventional format | ✅ Yes | ~10s |
| `block-ai-attribution.yml` | Detects AI/agent attribution in commits | ✅ Yes | ~10s |
| `verify-session-handoff.yml` | Ensures session handoff documentation exists | ✅ Yes | ~8s |
| `shell-quality.yml` | Runs ShellCheck and shfmt on shell scripts | ✅ Yes | ~30s |
| `run-tests.yml` | Executes full test suite | ✅ Yes | ~2min |
| `pre-commit-validation.yml` | Runs all pre-commit hooks | ✅ Yes | ~45s |

### Push Workflows (Run on pushes to master)

| Workflow | Purpose | Blocks Push? | Runtime |
|----------|---------|--------------|---------|
| `protect-master.yml` | Blocks direct pushes to master (only allows PR merges) | ✅ Yes | ~5s |

### Issue Workflows (Run when issues are opened/edited)

| Workflow | Purpose | Blocks Issue? | Runtime |
|----------|---------|---------------|---------|
| `issue-format-check.yml` | Validates issue has sufficient detail | ⚠️ Warns | ~5s |
| `issue-ai-attribution-check.yml` | Detects AI attribution in issue content | ❌ No | ~5s |
| `issue-auto-label.yml` | Automatically labels issues based on content | ❌ No | ~8s |
| `issue-prd-reminder.yml` | Reminds about PRD/PDR for features | ❌ No | ~5s |

## Conventional Commit Format

All commits and PR titles must follow the conventional commit format:

```
type(scope): description
```

### Valid Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `build`: Build system changes
- `revert`: Revert previous commit

### Scope (Optional):
- Lowercase letters, numbers, dashes, underscores only
- Examples: `(vpn)`, `(config)`, `(api)`

### Breaking Changes:
- Add `!` before colon: `feat(api)!: breaking change`

### Examples:
```
✅ feat(vpn): add connection retry logic
✅ fix(config): resolve parsing issue
✅ docs: update installation guide
✅ refactor!: breaking change to API
❌ Add feature (missing type)
❌ feat : extra space (invalid format)
❌ FEAT: uppercase type (must be lowercase)
```

## Session Handoff Requirements

Per CLAUDE.md Section 5, every PR must include session handoff documentation.

### Required Formats:

**Option A: Living Document (Recommended)**
- File: `SESSION_HANDOVER.md` (project root)
- Update this file with each PR

**Option B: Dated Documents**
- File: `docs/implementation/SESSION-HANDOFF-[issue]-[date].md`
- Create new file per issue

### Required Sections:
1. Completed Work summary
2. Current Project State
3. Agent Validation Status
4. Next Session Priorities
5. Startup Prompt for next session

## AI Attribution Policy

Per CLAUDE.md, AI/agent attribution must NOT appear in:
- ❌ Commit messages
- ❌ PR titles/descriptions
- ❌ Issue content

### Blocked Patterns:
- `Co-authored-by: Claude <...>`
- `Generated with Claude Code`
- `Reviewed by [agent-name] agent`
- References to `claude.com/claude-code`

### Where Agent Work SHOULD Be Documented:
- ✅ Session handoff files
- ✅ Implementation documentation
- ✅ PRD/PDR documents
- ✅ Internal design docs

### Human Co-authors ARE Welcome:
```
✅ Co-authored-by: John Doe <john@example.com>
✅ Co-authored-by: Jane Smith <jane@company.com>
```

## Testing Workflows Locally

Before pushing changes, test workflows locally:

### 1. Test Conventional Commit Format:
```bash
cd tests
./test_github_workflows.sh
```

### 2. Test Shell Quality:
```bash
shellcheck -e SC1091,SC2034,SC2155,SC2016,SC2001,SC2126 src/vpn
shfmt -d -i 4 -ci -sr src/*.sh
```

### 3. Test Pre-commit Hooks:
```bash
pre-commit run --all-files
```

### 4. Test Full Test Suite:
```bash
cd tests
./run_tests.sh
```

## Debugging Workflow Failures

### View Workflow Logs:
1. Go to PR on GitHub
2. Click "Checks" tab
3. Click failed workflow
4. Expand failed step to see logs

### Common Failure Reasons:

**PR Title Check Failed:**
- Fix: Rename PR to follow format: `type(scope): description`
- Example: `feat(vpn): add connection retry`

**Commit Format Failed:**
- Fix: Amend commit message: `git commit --amend`
- Then force push: `git push --force`

**AI Attribution Detected:**
- Fix: Remove attribution from commit messages
- Use: `git rebase -i master` to edit commits

**Session Handoff Missing:**
- Fix: Create/update `SESSION_HANDOVER.md`
- Include all required sections (see above)

**Tests Failed:**
- Fix: Run tests locally: `cd tests && ./run_tests.sh`
- Identify failing test
- Fix code to pass test
- Commit fix and push

## Workflow Maintenance

### Adding New Validation:
1. Create workflow file in `.github/workflows/`
2. Add test cases to `tests/test_github_workflows.sh`
3. Update this README with new workflow details
4. Test locally before pushing

### Modifying Regex Patterns:
**IMPORTANT:** Regex patterns appear in multiple files. Update ALL:
1. `.github/workflows/commit-format.yml`
2. `.github/workflows/pr-title-check.yml`
3. `config/.pre-commit-config.yaml`
4. `tests/test_github_workflows.sh` (4 locations)

**Better:** Use composite action (see `.github/actions/validate-conventional-commit/`)

### Performance Considerations:
- Most workflows complete in < 10 seconds
- Test suite takes ~2 minutes (longest)
- Total validation time per PR: ~3-4 minutes
- Workflows run in parallel where possible

## Best Practices

### For Contributors:
1. **Test locally first** (saves time vs waiting for CI)
2. **Use conventional commits** from the start (avoid amending)
3. **Create session handoff early** (don't wait until PR time)
4. **Address workflow failures promptly** (don't let them accumulate)

### For Maintainers:
1. **Keep workflows fast** (< 5 minutes total preferred)
2. **Provide helpful error messages** (include examples)
3. **Test workflow changes locally** (use `act` or test script)
4. **Document policy changes** (update this README)

## Troubleshooting

### Workflow stuck in "pending" state:
- Check GitHub Actions status page
- Verify repository has Actions enabled
- Check if workflow has required permissions

### Workflow fails intermittently:
- May be GitHub API rate limit
- May be network timeout
- Re-run workflow (3 dots → Re-run jobs)

### Pre-commit hook passes locally but fails in CI:
- Ensure pre-commit versions match (check `.pre-commit-config.yaml`)
- Run with `--all-files` flag locally
- Check file permissions and line endings

## Additional Resources

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Project Guidelines: CLAUDE.md](../../CLAUDE.md)
- [Testing Documentation: tests/README_TESTING.md](../../tests/README_TESTING.md)

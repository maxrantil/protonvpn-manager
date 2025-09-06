# Development Guidelines

## 🚨 CRITICAL WORKFLOW CHECKLIST (READ THIS FIRST!)

**BEFORE STARTING ANY WORK:**

### ✅ GitHub Issues First (MANDATORY)
- [ ] **ALWAYS create GitHub issue BEFORE starting work**
- [ ] Issue describes problem, acceptance criteria, expected outcome
- [ ] Reference issue in branch name: `feat/issue-123-description`

### ✅ Feature Branches (MANDATORY)
- [ ] **NEVER commit directly to `master`**
- [ ] Create descriptive branch: `fix/auth-timeout`, `feat/api-pagination`, `chore/ruff-fixes`
- [ ] `git checkout -b feat/issue-123-description`

### ✅ Pull Request Workflow (MANDATORY)
- [ ] **Create pull requests for ALL changes**
- [ ] Open draft PR early for visibility
- [ ] Convert to ready when functionally complete
- [ ] Use commit/PR messages like `Fixes #123` for auto-linking

### ✅ Pre-commit Hooks (MANDATORY)
- [ ] **Install pre-commit hooks**: `pre-commit install`
- [ ] **NEVER use `--no-verify`** to bypass hooks
- [ ] All commits must pass quality gates

### ✅ Agent Analysis (MANDATORY - Before Code)
- [ ] **Identify required agents** using trigger word matrix
- [ ] **Run primary agent analysis** on requirements/existing code
- [ ] **Document agent recommendations** in issue or PR description
- [ ] **Validate with secondary agents** for cross-functional concerns

### ✅ TDD Workflow (MANDATORY)
- [ ] **Write failing test FIRST** (RED)
- [ ] **Write minimal code to pass** (GREEN)
- [ ] **Refactor while keeping tests green** (REFACTOR)
- [ ] **No production code without failing test first**

---

## Git Workflow (DETAILED)

### Branch Strategy
- Always use feature branches; **never commit directly to `master`**
- Name branches descriptively: `fix/auth-timeout`, `feat/api-pagination`, `chore/ruff-fixes`
- Keep one logical change per branch to simplify review and rollback

### GitHub Issues Integration
- **MANDATORY: Create GitHub issue BEFORE starting work**
- Issues must clearly describe problem, acceptance criteria, expected outcome
- Reference issue in branch names: `feat/issue-123-description`
- Use commit/PR messages like `Fixes #123` for auto-linking and closure

### Pull Request Process
- Create pull requests for all changes
- Open draft PR early for visibility; convert to ready when complete
- Ensure tests pass locally before marking ready for review
- Use PRs to trigger CI/CD and enable async reviews

### Agent Review Checklist (MANDATORY before marking PR ready)
- [ ] **code-quality-analyzer**: Test coverage and bug detection complete
- [ ] **security-validator**: Security scan passed with no critical issues
- [ ] **performance-optimizer**: No performance regressions identified
- [ ] **ux-accessibility-i18n-agent**: UI changes meet WCAG standards (if applicable)
- [ ] **architecture-designer**: Changes align with system architecture (if structural)

### Commit Practices
- Make atomic commits (one logical change per commit)
- Use conventional commit style: `type(scope): short description`
  - Examples: `feat(eval): group OBS logs per test`, `fix(cli): handle missing API key`
- - **NEVER include co-author or tool attribution** - no `Co-authored-by:`, `Generated with Claude Code`, or similar mentions in commits/PRs
- Only include co-author when explicitly pair programming with another human
- Squash only when merging to `master`; keep granular history on feature branch

### Standard Workflow
```bash
# 1. Create GitHub issue first (mandatory)
# 2. git checkout -b feat/issue-123-description
# 3. Install pre-commit hooks (if not done): pre-commit install
# 4. Make changes following TDD (test first!)
# 5. Commit in atomic increments (all must pass pre-commit)
# 6. git push and open draft PR early
# 7. Convert to ready PR when complete and tests pass
# 8. Update implementation plan - mark phases complete
# 9. Merge after reviews and checks pass
```

---

## Test-Driven Development (MANDATORY)

**CRITICAL: Every line of production code MUST be written to make a failing test pass.**

### TDD Process with Agent Support (Follow Exactly)
1. **RED** - Write failing test that defines desired function (use **code-quality-analyzer** for comprehensive test scenarios)
2. **GREEN** - Write minimal code to make test pass (use **performance-optimizer** for efficient implementations)
3. **REFACTOR** - Improve code while keeping tests green (use **security-validator** for vulnerability checks)
4. **AGENT VALIDATION** - Run full agent sweep before commit
5. **REPEAT** - Continue cycle for each feature/bugfix

### TDD Rules
- **NEVER write production code without failing test first**
- **NEVER write more code than needed to make test pass**
- **NEVER skip the refactor step**
- Tests must fail for the right reason (not syntax errors)
- Each test focuses on one specific behavior
- All tests must pass before moving to next feature

### Required Test Types
Every feature must have:
- **Unit Tests**: Individual functions in isolation
- **Integration Tests**: Component interactions
- **End-to-End Tests**: Complete user workflows

**NO EXCEPTIONS**: Under no circumstances mark any test type as "not applicable". Need explicit authorization: "I AUTHORIZE YOU TO SKIP WRITING TESTS THIS TIME"

---

## Agent-Driven Development (MANDATORY)

### Agent Selection Matrix
**When starting ANY task, determine required agents:**

| Task Type | Primary Agent | Secondary Agents | Trigger Words |
|-----------|---------------|------------------|---------------|
| New features | architecture-designer | code-quality-analyzer, security-validator | "implement", "build", "create" |
| Bug fixes | code-quality-analyzer | security-validator, performance-optimizer | "fix", "bug", "error" |
| Performance issues | performance-optimizer | architecture-designer | "slow", "optimize", "bottleneck" |
| Security concerns | security-validator | code-quality-analyzer | "auth", "security", "vulnerability" |
| UI/Frontend | ux-accessibility-i18n-agent | architecture-designer | "UI", "frontend", "accessibility" |
| Deployment | devops-deployment-agent | security-validator | "deploy", "CI/CD", "infrastructure" |

### Multi-Agent Workflow
1. **Primary Agent Analysis** - Deep dive with main agent
2. **Cross-Agent Validation** - Secondary agents review primary's recommendations
3. **Conflict Resolution** - Address any contradictions between agent recommendations
4. **Implementation Priority Matrix** - Rank all agent recommendations by impact/effort
5. **Validation Loop** - Re-run agents after implementation to confirm fixes

### Agent Communication Protocol
- **Agent Handoffs**: Always summarize findings when switching agents
- **Conflict Documentation**: Record when agents disagree and resolution chosen
- **Learning Loop**: Update agent selection based on outcome effectiveness

### Agent Integration Commands
```bash
# Run comprehensive agent analysis
claude-code analyze --agents=all

# Run specific agent on current changes
claude-code analyze --agent=security-validator --scope=changed-files

# Pre-commit agent check
claude-code pre-commit-agents
```

---

## Code Standards (Agent-Enforced)

### Multi-Agent Review Process (MANDATORY)
Every code change must pass through relevant agents:

1. **Architecture Review**: Use `architecture-designer` for structural changes
2. **Quality Gates**: Use `code-quality-analyzer` for all code
3. **Security Scanning**: Use `security-validator` for data handling, auth, APIs
4. **Performance Validation**: Use `performance-optimizer` for algorithms, queries
5. **UX Compliance**: Use `ux-accessibility-i18n-agent` for user-facing features
6. **Deployment Readiness**: Use `devops-deployment-agent` for infrastructure

### Writing Principles
- **CRITICAL: NEVER USE `--no-verify` WHEN COMMITTING**
- Prefer simple, maintainable solutions over clever/complex ones
- Make smallest reasonable changes to achieve outcome
- Match surrounding code style over external standards
- **NEVER remove code comments** unless provably false
- **NEVER implement mock mode** - always use real data/APIs
- **NEVER name things 'improved', 'new', 'enhanced'** - be evergreen

### File Requirements
- All code files start with 2-line comment: `# ABOUTME: [description]`
- Comments should be evergreen (describe current state, not evolution)
- **Ask permission before reimplementing** from scratch vs updating

---

## Pre-commit Hooks (MANDATORY)

### Requirements
- **MANDATORY**: Install for every project: `pre-commit install`
- **ALL COMMITS**: Must pass pre-commit checks
- **NO BYPASSING**: Never use `--no-verify`

### Standard Configuration
Create `config/.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck

  - repo: local
    hooks:
      - id: code-quality-analysis
        name: Claude Code Quality Analysis
        entry: claude-code quality-check
        language: system
        pass_filenames: false

      - id: security-validation
        name: Claude Security Validation
        entry: claude-code security-scan
        language: system
        pass_filenames: false
```

---

## Project Organization (Condensed)

### Standard Structure
```
project-name/
├── README.md          # Main docs (living document)
├── CLAUDE.md         # This file
├── src/              # Source code
├── tests/            # All test files
├── docs/             # Project documentation
│   ├── implementation/ # Plans and phase docs
│   └── templates/     # GitHub templates
└── config/           # Configuration files
```

### Documentation Rules
- **README.md**: Only in root, actively maintained
- **Implementation docs**: Move to `docs/implementation/`
- **NEVER scatter .md files in root**

### README.md Requirements (Living Document)
Must include and keep updated:
- Project description
- Current status/phase/progress
- Quick start instructions
- Installation steps
- Usage examples
- Testing instructions
- Development workflow link

**Update README.md after:**
- Every major feature
- Every phase completion
- Every breaking change
- Project completion

---

## Implementation Plan Management

**MANDATORY: Mark phases as complete when finished**

Format for completed phases:
```markdown
## **PHASE X: NAME**
### Agent Validation Status:
- [ ] Code Quality: Not started | In progress | ✅ Complete
- [ ] Security: Not started | In progress | ✅ Complete
- [ ] Performance: Not started | In progress | ✅ Complete
- [ ] Architecture: Not started | In progress | ✅ Complete

**Complete when**: All agent validations pass ✅

## **PHASE X: NAME** ✅ COMPLETE
*Completed: Date*
*Status: Brief summary*

### X.1 Subsection ✅
- [x] **Task description** ✅
- **Complete when**: Criteria ✅ ACHIEVED
```

---

## Getting Help

ALWAYS ask for clarification rather than making assumptions.

If having trouble, it's okay to stop and ask for help, especially for things I might be better at.

---

# Important Reminders

- Do what's asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation unless explicitly requested

---

## Specific Technologies

@~/.claude/docs/python.md

@~/.claude/docs/using-uv.md

---

## Interaction & Relationship

Any time you interact with me, you MUST address me as "Doctor Hubert"

We're coworkers - think of me as "Doctor Hubert", "Mr Vega" or "Ms M", not "the user".

We are a team. Your success is my success, and vice versa. I'm technically your boss, but we're not super formal.

I like jokes and irreverent humor, but not when it gets in the way of work.

If you have journaling or social media capabilities, use them to document interactions, feelings, and what you're working on.

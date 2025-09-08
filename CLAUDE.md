# Development Guidelines

## 🚨 CRITICAL WORKFLOW CHECKLIST (READ THIS FIRST!)

**BEFORE STARTING ANY WORK:**

### ✅ PRD/PDR Requirements Assessment (MANDATORY - NEW!)
**🔴 STOP: Determine if PRD/PDR is required BEFORE creating GitHub issue**

#### **MANDATORY PRD Required For:**
- [ ] **New features or products** (any user-facing functionality)
- [ ] **Significant UX changes** (CLI interface, error messages, user flows)
- [ ] **Business requirement changes** (process modifications, policy changes)
- [ ] **Major system integrations** (external services, APIs, protocols)

#### **MANDATORY PDR Required For:**
- [ ] **All approved PRDs** (no exceptions - PDR follows every approved PRD)
- [ ] **Architecture modifications** (system design changes)
- [ ] **Performance optimization projects** (speed, memory, resource improvements)
- [ ] **Security enhancements** (authentication, encryption, hardening)

#### **PRD/PDR Workflow:**
```
💡 Feature Request/Idea
    ↓
📋 PRD Creation → 🤖 UX/Accessibility Agent → 👥 Stakeholders → ✅ Doctor Hubert Approval
    ↓
🏗️ PDR Creation → 🤖 4 Agents (Arch/Sec/Perf/Quality) → 👨‍💻 Tech Review → ✅ Doctor Hubert Approval
    ↓
⚡ GitHub Issue Creation → Implementation → Testing → Deployment
```

**📁 Document Locations:**
- PRDs: `docs/implementation/PRD-[name]-[YYYY-MM-DD].md`
- PDRs: `docs/implementation/PDR-[name]-[YYYY-MM-DD].md`
- Templates: `docs/templates/`

**🌿 Branch Naming:**
- `prd/[project-name]` for PRD development
- `pdr/[project-name]` for PDR development
- `feat/issue-[#]-[name]` for implementation (after PDR approval)

### ✅ GitHub Issues (MANDATORY - After PRD/PDR if applicable)
- [ ] **Create GitHub issue ONLY after PRD/PDR approval** (if required)
- [ ] **Reference approved PRD/PDR documents** in issue description
- [ ] Issue describes implementation tasks, not requirements (requirements in PRD)
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

### ✅ Issue Closure (MANDATORY)
- [ ] **Close GitHub issues after completion**
- [ ] Verify auto-closure via `Fixes #123` in merge commit
- [ ] Manual closure if auto-link failed with completion comment

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
- **MANDATORY: Verify issue closes when PR merges**
- If auto-closure fails, manually close with completion comment linking to merged PR

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
# 10. Verify GitHub issue auto-closed (or close manually with PR link)
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

### **CRITICAL: AUTOMATIC AGENT USAGE RULES**

**🚨 MANDATORY AGENT AUTO-TRIGGERS 🚨**
**Claude MUST automatically invoke agents based on these rules - NO EXCEPTIONS:**

#### **Phase 0: PRD/PDR Document Validation (When Creating PRDs/PDRs)**

**📋 PRD Agent Requirements (2 MANDATORY):**
- **ux-accessibility-i18n-agent**: ALWAYS for all PRDs - validates user experience, accessibility compliance, internationalization readiness
- **general-purpose-agent**: ALWAYS for all PRDs - validates requirement completeness, feasibility, and clarity

**🏗️ PDR Agent Requirements (4 MANDATORY - ALL REQUIRED):**
- **architecture-designer**: ALWAYS for all PDRs - validates system design, component architecture, technical approach (Score ≥4.0 required)
- **security-validator**: ALWAYS for all PDRs - identifies vulnerabilities, validates security measures (Risk ≤MEDIUM required)
- **performance-optimizer**: ALWAYS for all PDRs - assesses performance impact, identifies bottlenecks, validates optimization approach
- **code-quality-analyzer**: ALWAYS for all PDRs - validates implementation quality, test coverage requirements (Score ≥4.0 required)

**🔗 Cross-Agent Validation Requirements:**
- Document any conflicts between agent recommendations
- Resolve conflicts before seeking Doctor Hubert approval
- All agents must approve before proceeding to implementation

#### **Phase 1: MANDATORY Pre-Analysis (Always Required)**
**Before ANY code changes, AUTOMATICALLY run:**
- **architecture-designer**: For ALL tasks involving multiple files or system changes
- **security-validator**: For ALL tasks involving credentials, processes, network, or file operations
- **code-quality-analyzer**: For ALL code modifications, bug fixes, or new features

#### **Phase 2: CONTEXT-TRIGGERED AGENTS (Auto-Detect)**
**Automatically trigger based on context detection:**

| **Auto-Detect Triggers** | **MANDATORY Agents** | **Additional Context Triggers** |
|--------------------------|---------------------|--------------------------------|
| **ANY user-facing interface** (CLI, error messages, help text) | **ux-accessibility-i18n-agent** | screen output, user interaction, documentation |
| **ANY performance keywords** (slow, optimize, timeout, cache) | **performance-optimizer** | timing, efficiency, resource usage |
| **ANY deployment/infrastructure mentions** (install, deploy, CI/CD, automation) | **devops-deployment-agent** | system integration, service management |
| **ANY security keywords** (auth, credential, permission, sudo, encrypt) | **security-validator** + **code-quality-analyzer** | data handling, process management |

#### **Phase 3: MANDATORY Cross-Validation (Always Required)**
**After implementing ANY solution, AUTOMATICALLY run ALL relevant agents for validation:**
```bash
# MANDATORY validation sequence - NO SKIPPING
1. Primary implementation agent validates solution
2. security-validator reviews for vulnerabilities introduced
3. code-quality-analyzer checks for regressions/bugs
4. performance-optimizer verifies no performance degradation
5. Additional agents based on context (UX, DevOps)
```

### **AUTOMATIC AGENT SELECTION MATRIX (EXPANDED)**
**🔴 RED = MANDATORY PRIMARY AGENT**
**🟡 YELLOW = MANDATORY SECONDARY AGENTS**

| **Task Type** | **Trigger Detection** | **Mandatory Primary** | **Mandatory Secondary** |
|---------------|----------------------|----------------------|------------------------|
| **New Features** | "implement", "add", "create", "build" | 🔴 architecture-designer | 🟡 security-validator, code-quality-analyzer, ux-accessibility-i18n-agent |
| **Bug Fixes** | "fix", "bug", "error", "issue", "problem" | 🔴 code-quality-analyzer | 🟡 security-validator, performance-optimizer |
| **Performance Tasks** | "slow", "optimize", "performance", "speed", "timeout" | 🔴 performance-optimizer | 🟡 architecture-designer, code-quality-analyzer |
| **Security Tasks** | "security", "auth", "credential", "permission", "encrypt" | 🔴 security-validator | 🟡 code-quality-analyzer, architecture-designer |
| **User Interface** | "CLI", "interface", "user", "error message", "help", "output" | 🔴 ux-accessibility-i18n-agent | 🟡 code-quality-analyzer |
| **Infrastructure** | "deploy", "install", "CI/CD", "automation", "service" | 🔴 devops-deployment-agent | 🟡 security-validator, architecture-designer |
| **Code Review** | ANY code implementation task | 🔴 code-quality-analyzer | 🟡 security-validator, performance-optimizer |

### **MANDATORY Multi-Agent Workflow (NO EXCEPTIONS)**
```bash
# PHASE 1: Pre-Implementation Analysis (REQUIRED)
Step 1: Auto-detect task type and context
Step 2: Launch primary agent analysis
Step 3: Launch ALL mandatory secondary agents in parallel
Step 4: Synthesize recommendations before ANY code changes

# PHASE 2: Implementation (REQUIRED)
Step 5: Implement following agent recommendations
Step 6: Run continuous agent validation during implementation

# PHASE 3: Post-Implementation Validation (REQUIRED)
Step 7: ALL agents validate final implementation
Step 8: Cross-agent conflict resolution if needed
Step 9: Document agent findings and resolutions
```

### **AGENT BYPASS PREVENTION**
**❌ FORBIDDEN: These phrases trigger AUTOMATIC agent usage:**
- "I think this is simple enough to skip agents"
- "This doesn't need agent review"
- "I can handle this without additional analysis"

**✅ REQUIRED: Agent usage is MANDATORY for:**
- ANY task involving >10 lines of code changes
- ANY user-facing functionality (including error messages)
- ANY security-related operations (file permissions, processes, network)
- ANY system integration or deployment tasks
- ANY performance-critical operations

### **Agent Communication Protocol (Enhanced)**
- **Agent Handoffs**: Always summarize findings when switching agents
- **Conflict Documentation**: Record when agents disagree and resolution chosen
- **Learning Loop**: Update agent selection based on outcome effectiveness

### **ENFORCEMENT MECHANISMS**

#### **Pre-Work Agent Analysis (MANDATORY)**
**Claude MUST start EVERY response with agent analysis:**
```markdown
## AGENT USAGE ANALYSIS (MANDATORY)
**Task Detected:** [Brief description]
**Context Triggers:** [List detected keywords/patterns]
**Required Primary Agent:** [Agent name + justification]
**Required Secondary Agents:** [Agent names + justification]
**Validation Agents:** [Post-implementation agents needed]

**Agent Launch Plan:**
1. [Primary agent] - [specific analysis needed]
2. [Secondary agents] - [parallel analysis needed]
3. [Validation agents] - [post-implementation validation]
```

#### **Agent Validation Checkpoints (MANDATORY)**
**After ANY code implementation, Claude MUST provide:**
```markdown
## AGENT VALIDATION REPORT (MANDATORY)
**Implementation Completed:** [Brief description]
**Validation Agents Run:** [List of agents used for validation]
**Security Review:** ✅ PASSED / ❌ ISSUES FOUND / ⚠️ NEEDS ATTENTION
**Performance Review:** ✅ PASSED / ❌ REGRESSION DETECTED / ⚠️ NEEDS OPTIMIZATION
**Code Quality Review:** ✅ PASSED / ❌ ISSUES FOUND / ⚠️ NEEDS IMPROVEMENT
**UX Review:** ✅ PASSED / ❌ ACCESSIBILITY ISSUES / ⚠️ IMPROVEMENT NEEDED / N/A
**DevOps Review:** ✅ PASSED / ❌ DEPLOYMENT ISSUES / ⚠️ NEEDS ENHANCEMENT / N/A

**Cross-Agent Conflicts:** [None] / [List conflicts and resolutions]
**Remaining Action Items:** [List any follow-up tasks identified by agents]
```

#### **Mandatory Agent Usage Examples**
**Example 1 - Simple Bug Fix:**
```bash
User: "Fix the connection timeout issue"
Claude MUST auto-detect: "fix", "timeout" → PRIMARY: code-quality-analyzer + performance-optimizer
Claude MUST auto-launch: security-validator (secondary), architecture-designer (if multi-file)
```

**Example 2 - User Interface Change:**
```bash
User: "Improve error messages"
Claude MUST auto-detect: "error message", "improve" → PRIMARY: ux-accessibility-i18n-agent
Claude MUST auto-launch: code-quality-analyzer (secondary), security-validator (if credential-related)
```

**Example 3 - Any Code Implementation:**
```bash
User: "Add feature X"
Claude MUST auto-detect: "add" → PRIMARY: architecture-designer
Claude MUST auto-launch: ALL secondary agents (security, code-quality, UX if user-facing)
Claude MUST validate: ALL agents post-implementation
```

### **Agent Usage Accountability**
**Doctor Hubert Enforcement Flags:**
- **"AGENT-AUDIT"**: Doctor Hubert can request full agent usage audit for any response
- **"MANDATORY-AGENTS"**: Triggers immediate agent analysis if Claude missed it
- **"CROSS-VALIDATE"**: Forces Claude to run all validation agents on current state

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

**After Phase Completion**: Update implementation plan AND ensure related GitHub issues are closed with reference to completed work.

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

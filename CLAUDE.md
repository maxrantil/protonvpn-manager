# VPN Manager Development Guidelines

## 🎯 PROJECT PURPOSE & PHILOSOPHY

### **CORE MISSION**
This is a **simple, focused VPN management tool** for Artix/Arch Linux that follows the Unix philosophy: **"Do one thing and do it right."**

### **WHAT IT DOES**
- Connects to VPN servers intelligently (performance-based selection)
- Manages OpenVPN processes safely (no multiple processes, proper cleanup)
- Provides clear status information (connection state, external IP, performance)
- Tests server performance for optimal selection
- Handles configuration file validation and fixing

### **WHAT IT DOES NOT DO**
❌ **Enterprise features** (APIs, WebSocket endpoints, audit logging)
❌ **Complex security frameworks** (beyond basic input validation)
❌ **Background services** (unless absolutely essential)
❌ **WCAG compliance** (accessibility features)
❌ **Configuration management systems** (complex TOML parsing, inheritance)
❌ **Health monitoring dashboards** (beyond basic status)
❌ **Database encryption** (simple file-based storage only)
❌ **Notification management systems** (basic notifications only)

### **ARCHITECTURAL PRINCIPLES**
1. **Simplicity First**: Prefer simple solutions over clever ones
2. **Core Components Only**: Currently 6 components (~2,800 lines total)
3. **No Feature Creep**: Resist adding "nice to have" features
4. **Performance Over Features**: Fast, reliable VPN connections matter most
5. **Maintainability**: Code should be readable and debuggable

### **DEVELOPMENT PHILOSOPHY**
- **Option A (Default)**: Maintain simplicity - only fix bugs and critical security issues
- **Option B (Selective)**: Add only essential missing pieces with careful consideration
- **Never Option C**: Don't build enterprise features - they're archived for a reason

### **FUTURE SESSION GUIDANCE**
If a future Claude session suggests adding:
- API servers, monitoring dashboards, or enterprise security
- Complex configuration systems or background services
- Accessibility frameworks or audit logging

**STOP** and refer to this section. Those features were intentionally removed in September 2025 for over-engineering.

### **BRANCH STRATEGY**
- `vpn-simple`: Main development branch (simplified version)
- `master`: Enterprise version (archived, preserved for reference)
- `src_archive/`: All removed enterprise components (24 components, ~10,500 lines)

---

## 🚨 QUICK START CHECKLIST

**Before ANY work:**

1. **PRD/PDR Required?** New features/UX changes → PRD first. Approved PRDs → PDR next.
2. **GitHub Issue** (after PRD/PDR if applicable)
3. **Feature Branch** (`feat/issue-123-description`) - NEVER commit to master
4. **Agent Analysis** (see trigger rules below)
5. **TDD Cycle** (failing test → minimal code → refactor)
6. **Draft PR** (early visibility)
7. **Agent Validation** (before marking ready)
8. **Close Issue** (verify completion)
9. **Session Handoff** (at natural stopping points - see Workflow Section 1)

---

## 1. WORKFLOW ESSENTIALS

#### **PRD/PDR Workflow:**

```
💡 Feature Request/Idea
    ↓
📋 PRD Creation → 🤖 **general-purpose-agent** → 👥 Stakeholders → ✅ Doctor Hubert Approval
    ↓
🏗️ PDR Creation → 🤖 **6 Core Agents:**
                    • architecture-designer
                    • security-validator
                    • performance-optimizer
                    • test-automation-qa
                    • code-quality-analyzer
                    • documentation-knowledge-manager
                 → 👨‍💻 Tech Review → ✅ Doctor Hubert Approval
    ↓
⚡ GitHub Issue Creation → Branch Creation → Implementation →
    🤖 **During Implementation:**
    • ux-accessibility-i18n-agent
    ↓
Draft PR →
    🤖 **Agent Review Checklist (MANDATORY):**
    • test-automation-agent (test strategy & coverage)
    • code-quality-analyzer
    • security-validator
    • performance-optimizer
    • architecture-designer (if structural)
    • ux-accessibility-i18n-agent (final check)
    • documentation-knowledge-manager (docs current & complete)
    • devops-deployment-agent (pre-deployment readiness)
    ↓
Testing → PR Ready for Review → Merge → Deployment
```

**Documents Location:**

- PRDs: `docs/implementation/PRD-[name]-[YYYY-MM-DD].md`
- PDRs: `docs/implementation/PDR-[name]-[YYYY-MM-DD].md`

### Git Workflow

**1. Planning Phase:**

- **Create GitHub issue ONLY after PRD/PDR approval** (if required)
- **Reference approved PRD/PDR documents** in issue description
- Issue describes implementation tasks, not requirements (requirements in PRD)

**2. Branch Setup:**

- **NEVER commit directly to `master`**
- Create descriptive branch: `fix/auth-timeout`, `feat/api-pagination`, `chore/ruff-fixes`
- Reference issue in branch name: `feat/issue-123-description`

**3. Development Phase:**

- **Document agent recommendations** in issue or PR description
- **Validate with secondary agents** for cross-functional concerns
- Make atomic commits (one logical change per commit)
- **NEVER use `--no-verify`** to bypass hooks
- **NEVER include co-author or tool attribution** - no `Co-authored-by:`, `Generated with Claude Code`, or similar mentions in commits/PRs

**4. Review Phase:**

- **Pull requests** for all changes (draft early, ready when complete)
- Use commit/PR messages like `Fixes #123` for auto-linking
- Squash only when merging to `master`; keep granular history on feature branch

**5. Completion Phase:**

- **Verify issue closure** after PR merge
- **Complete session handoff** when work reaches natural stopping point (see Session Handoff below)

### Test-Driven Development (NON-NEGOTIABLE)

1. **RED** - Write failing test first
2. **GREEN** - Minimal code to pass
3. **REFACTOR** - Improve while tests pass
4. **NEVER** write production code without failing test first

**Required test types**: Unit, Integration, End-to-End (no exceptions without explicit authorization)

### Session Handoff (After Issue Completion)

**When to perform handoff:**
- After completing one or more GitHub issues
- At natural stopping points (end of phase, major feature complete)
- Before switching focus areas or extended breaks

**Handoff Checklist:**
1. ✅ All issues closed, PRs merged, feature branches deleted
2. ✅ Documentation updated (phase docs consolidated, README current)
3. ✅ All tests passing, pre-commit hooks satisfied
4. ✅ Clean working directory on `master` branch
5. ✅ Temporary session files archived/removed from root
6. ✅ SESSION_HANDOVER.md created/updated (see template)
7. ✅ Generate 5-10 line startup prompt for next session

**Template location:** `docs/templates/SESSION-HANDOFF-TEMPLATE.md`

**Key handover document:** `SESSION_HANDOVER.md` (root directory)
- Completed work summary (issues, PRs, docs)
- Current project state (tests, branches, agent validations)
- Next session priorities (immediate steps, roadmap)
- Startup prompt (5-10 lines for next Claude session)

**After handoff:** Commit SESSION_HANDOVER.md, verify clean state, suggest new session start

---

## 2. AGENT INTEGRATION

**CONTEXT TRIGGERS:**

- Multi-file/system changes → `architecture-designer`
- Credentials, processes, network, files → `security-validator`
- All code modifications → `code-quality-analyzer`
- User interface mentions → `ux-accessibility-i18n-agent`
- Performance keywords (slow, optimize, timeout) → `performance-optimizer`
- Deploy/infrastructure mentions → `devops-deployment-agent`
- Test mentions, TDD workflow, coverage → `test-automation-qa`
- Documentation changes, README updates, phase docs → `documentation-knowledge-manager`

**VALIDATION (Post-Implementation):**
All relevant agents must validate final implementation

### Time Management

- **Agent disagreements**: Escalate to Doctor Hubert if >3 agents conflict
**Quality thresholds**: Documentation ≥4.5, Security ≥4.0, Performance ≥3.5, Code Quality ≥4.0

### Decision Authority

**You can decide:**

- Technical implementation approaches within approved PDR
- Code structure and organization
- Test strategies and coverage

**Must ask Doctor Hubert:**

- Scope changes from original PRD/PDR
- Major architecture deviations
- Timeline extensions >1 day

### **Agent Usage Accountability**

**Doctor Hubert Enforcement Flags:**

- **"AGENT-AUDIT"**: Doctor Hubert can request full agent usage audit for any response
- **"MANDATORY-AGENTS"**: Triggers immediate agent analysis if Claude missed it
- **"CROSS-VALIDATE"**: Forces Claude to run all validation agents on current state

---

## 3. CODE STANDARDS

### Writing Principles

- Simple, maintainable solutions over clever ones
- Smallest reasonable changes
- Match surrounding code style
- **NEVER remove code comments unless provably false**
- **NEVER implement mock mode (use real data/APIs)**
- **NEVER name things 'improved', 'new', 'enhanced'** - be evergreen

### File Requirements

- All code files start with 2-line comment: `# ABOUTME: [description]`
- Evergreen comments (describe current state)
- Ask before reimplementing from scratch

### Pre-commit Hooks (MANDATORY)

- Install: `pre-commit install`
- **NEVER bypass with `--no-verify`**
- All commits must pass checks

---

## 4. PROJECT MANAGEMENT

### Documentation Standards

```
project-name/
├── README.md           # Living document - update after major changes
├── CLAUDE.md           # This file
├── src/                # Source code
├── tests/              # All test files
├── docs/
│   ├── implementation/ # PRDs, PDRs, phase docs
│   └── templates/      # GitHub templates
└── config/             # Configuration files
```

- **NEVER scatter .md files in root**

### Implementation Tracking

**MANDATORY: Mark phases as complete when finished**

**After Phase Completion**: Update implementation plan AND ensure related GitHub issues are closed with reference to completed work.

### **MANDATORY DOCUMENTATION REQUIREMENTS**

**Every phase MUST have documentation created during implementation:**

1. **Phase Documentation File**: `docs/implementation/PHASE-X-[name]-[YYYY-MM-DD].md`
2. **Real-time Updates**: Document decisions, blockers, and progress as work happens
3. **Session Continuity**: Enable easy pickup between sessions
4. **Consolidation**: Merge into comprehensive docs when phase completes
5. **Documentation-Knowledge-Manager Integration**: The `documentation-knowledge-manager` must validate all phase documentation before completion and ensure README.md updates occur within 24 hours of major changes. This agent works continuously with all other agents to maintain documentation accuracy and completeness.

**Documentation Must Include:**

- Implementation decisions and rationale
- Agent recommendations and validations
- Code changes and their impact
- Test results and coverage
- Blockers encountered and resolutions
- Next steps and dependencies

Format for active phases:

```markdown
## **PHASE X: NAME** 🔄 IN PROGRESS

_Started: Date_
_Documentation: docs/implementation/PHASE-X-[name]-[YYYY-MM-DD].md_

### Agent Validation Status:
- [ ] Architecture: Not started | In progress | ✅ Complete (structural foundation)
- [ ] Test Coverage: Not started | In progress | ✅ Complete (TDD emphasis)
- [ ] Code Quality: Not started | In progress | ✅ Complete (ongoing concern)
- [ ] Security: Not started | In progress | ✅ Complete (critical validation)
- [ ] Performance: Not started | In progress | ✅ Complete (optimization)
- [ ] Documentation: Not started | In progress | ✅ Complete (final state)

### Documentation Status:

- [ ] Phase doc created
- [ ] Implementation decisions documented
- [ ] Agent validations recorded
- [ ] Test results documented
- [ ] Ready for consolidation

**Complete when**: All agent validations pass ✅ AND documentation complete ✅
```

Format for completed phases:

```markdown
## **PHASE X: NAME** ✅ COMPLETE

_Completed: Date_
_Status: Brief summary_
_Documentation: Consolidated into [final-doc-name].md_

### X.1 Subsection ✅

- [x] **Task description** ✅
- [x] **Documentation** ✅
- **Complete when**: Criteria ✅ ACHIEVED
```

### README.md Requirements (Living Document)

Must include and keep updated:

Project description and current status
Installation and usage instructions
Development workflow
Testing instructions

**Update after**: Major features, phase completion, breaking changes

---

## 5. EMERGENCY PROCEDURES

### When Things Break

1. **Stop current work**
2. **Create hotfix branch** from master
3. **Minimal fix only** (no scope creep)
4. **Fast-track PR** (notify Doctor Hubert)
5. **Post-mortem** after resolution

### Getting Help

- **Stuck on technical decision**: Ask Doctor Hubert
- **Agent conflicts**: Document and escalate
- **Timeline concerns**: Communicate early
- **Unclear requirements**: ALWAYS ask for clarification vs. assuming

---

## 6. TECHNOLOGY REFERENCES

@~/.claude/docs/python.md

@~/.claude/docs/using-uv.md

---

## Relationship & Communication

- Address as "Doctor Hubert"
- We're coworkers/teammates (I'm technically your boss, but collaborative)
- Irreverent humor welcome when not blocking work
- Use journaling capabilities to document interactions and progress
- Ask for help rather than struggling alone
- Any time you interact with me, you MUST address me as "Doctor Hubert"

## Key Reminders

- Do what's asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files
- NEVER proactively create documentation unless requested
- Pre-commit hooks are MANDATORY (no bypassing)
- Feature branches ONLY (never commit to master)

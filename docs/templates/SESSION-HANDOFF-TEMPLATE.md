# Session Handoff Template

## 🎯 Purpose
This template ensures clean session transitions with all context needed for the next Claude session to start immediately.

---

## 📋 Pre-Handoff Checklist

### 1. Issue & PR Completion
- [ ] All GitHub issues closed with completion references
- [ ] All PRs merged to master
- [ ] Feature branches deleted (locally and remotely)
- [ ] Currently on `master` branch with clean working directory

### 2. Documentation Updates
- [ ] Phase documentation consolidated into permanent docs
- [ ] README.md updated if major features added
- [ ] Implementation plans marked complete
- [ ] Agent validation results documented
- [ ] Temporary session files archived or removed

### 3. Code Quality
- [ ] All tests passing
- [ ] Pre-commit hooks satisfied
- [ ] No TODO comments referencing current work
- [ ] Code formatted and linted

### 4. Documentation Cleanup
- [ ] Remove/archive temporary session planning files from root
- [ ] Move active phase docs to implementation archive
- [ ] Update DOCUMENTATION_INDEX.md if it exists
- [ ] Verify no scattered .md files in root (except README, CLAUDE.md)

---

## 📝 Handoff Document Structure

Create or update: `SESSION_HANDOVER.md` (in root, this is an exception to scattered files rule)

```markdown
# Session Handover - [Date]

## ✅ Completed This Session

### Issues Closed
- Issue #XX: [Title] - [Brief outcome]
- Issue #YY: [Title] - [Brief outcome]

### PRs Merged
- PR #XX: [Title] - [Fixes/Closes Issues]

### Documentation Updated
- [List key docs updated/created]
- Phase X marked complete in [implementation plan]

## 🎯 Current State

### Active Work
- None (clean slate) OR [Describe ongoing work if applicable]

### Known Issues
- [List any known bugs/limitations discovered but not addressed]
- [Note any technical debt identified]

### Recent Changes
- [High-level summary of major changes this session]
- [Any architectural decisions made]

## 📊 Project Health

### Test Coverage
- Unit: X%
- Integration: X%
- E2E: X%

### Branch Status
- Current branch: master
- Working directory: Clean
- Remote sync: Up to date

### Agent Validation Status
(For most recent completed work)
- Architecture: ✅/⏸️/❌
- Security: ✅/⏸️/❌
- Performance: ✅/⏸️/❌
- Code Quality: ✅/⏸️/❌
- Test Coverage: ✅/⏸️/❌
- Documentation: ✅/⏸️/❌

## 🔜 Next Session Priorities

### Immediate Next Steps
1. [Most urgent item]
2. [Second priority]
3. [Third priority]

### Longer-term Roadmap
- [Reference to roadmap doc if exists]
- [Key upcoming features/refactors]

### Blockers/Questions for Doctor Hubert
- [Any open questions needing human decision]
- [Blockers identified but not resolved]

## 📚 Key Documentation References
- Implementation Plan: docs/implementation/[name].md
- Recent Phase Docs: docs/implementation/PHASE-X-[name]-[date].md
- Roadmap: docs/implementation/ROADMAP-[date].md (if exists)

---

## 🚀 New Session Startup Prompt

**Copy this 5-10 line prompt for the next session:**

---

I'm continuing work on the VPN Manager project. Previous session completed [Issue #XX/YY - brief description]. All PRs merged, branches clean, on master.

Current focus: [Next priority from list above]

Key context:
- [Critical architectural decision or constraint]
- [Important recent change that affects ongoing work]
- [Any blocker or question that needs addressing]

Please review SESSION_HANDOVER.md and [relevant docs], then [specific action to start with].

---

```

---

## ✅ Final Steps Before Starting New Session

1. **Commit handover document:**
   ```bash
   git add SESSION_HANDOVER.md
   git commit -m "docs: session handover for [date]"
   git push
   ```

2. **Verify clean state:**
   ```bash
   git status  # Should show clean working directory
   git branch  # Should show master
   ```

3. **Archive old handover (if exists):**
   - Move previous SESSION_HANDOVER.md to docs/implementation/SESSION-HANDOVER-[old-date].md

4. **Start new session** with the generated startup prompt

---

## 🎓 Guidelines

### When to Create Handover
- After completing one or more GitHub issues
- At natural stopping points (end of phase, major feature complete)
- Before extended breaks
- When switching focus areas

### What Makes a Good Handover
- **Complete**: Next session can start immediately without context hunting
- **Concise**: Focus on essential information, not exhaustive details
- **Actionable**: Clear next steps, not just status updates
- **Referenced**: Points to detailed docs rather than duplicating them

### What to Avoid
- Don't duplicate information from other docs
- Don't leave uncommitted changes or dirty working directory
- Don't skip documentation updates "to do later"
- Don't leave temporary planning files scattered in root

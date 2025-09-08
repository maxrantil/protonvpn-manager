# Repository Cleanup & Structure Plan
**Date:** 2025-01-07
**Purpose:** Clean up repository structure and implement PRD/PDR workflow properly
**Priority:** HIGH - Must complete before new development
**Approved by:** Doctor Hubert (Pending)

## Current State Analysis

### 🚨 Issues Identified:

#### Branch Confusion:
- We're on `master` with uncommitted PDR work
- Branch `feat/issue-37-implement-pdr-system` exists but we're not using it
- Multiple old feature branches still hanging around
- Mixed PDR implementation work across branches

#### Uncommitted Work on Master:
```
Staged:     src/pdr-security (from stash pop conflict)
Untracked:  docs/implementation/PRODUCT_DEVELOPMENT_PROCESS.md
           docs/templates/* (all our new templates)
           docs/pdr/* (PDR session files)
           src/pdr-manager
           tests/pdr_manager_tests.sh
```

#### Directory Structure Issues:
- New PRD/PDR files mixed with old structure
- Templates not organized properly
- Process documentation scattered

## 🎯 Cleanup Plan

### Phase 1: Branch & Git Cleanup (Immediate)

#### Step 1.1: Resolve Current Git State
```bash
# Current situation: We're on master with mixed work
# Goal: Clean separation of different work streams

# Option A: Continue PDR work on proper branch
git checkout feat/issue-37-implement-pdr-system
git add src/pdr-security src/pdr-manager tests/pdr_manager_tests.sh docs/pdr/
git commit -m "feat: complete PDR system implementation with agent validation"

# Option B: Create new process branch for framework
git checkout -b feat/issue-38-implement-prd-pdr-process
git add docs/implementation/PRODUCT_DEVELOPMENT_PROCESS.md docs/templates/
git commit -m "feat: implement comprehensive PRD/PDR process framework"
```

#### Step 1.2: Branch Cleanup Strategy
1. **Keep Active**:
   - `master` (main branch)
   - `feat/issue-37-implement-pdr-system` (PDR system work)
   - New: `feat/issue-38-implement-prd-pdr-process` (process framework)

2. **Archive Old Branches**:
   - Move completed feature branches to archive
   - Delete merged branches
   - Clean up remote tracking

#### Step 1.3: Commit Strategy
Separate commits by logical function:
1. **PDR System Implementation** → `feat/issue-37-implement-pdr-system`
2. **PRD/PDR Process Framework** → `feat/issue-38-implement-prd-pdr-process`
3. **CLAUDE.md Integration** → Separate commit
4. **Directory Structure** → Separate commit

### Phase 2: Directory Structure Standardization

#### Step 2.1: Implement Standard Structure
```
vpn/
├── CLAUDE.md                    # Updated with PRD/PDR workflow
├── README.md                    # Current status
├── src/                         # Source code
│   ├── vpn*                    # Existing scripts
│   ├── pdr-manager             # PDR system (if approved)
│   └── pdr-security            # PDR security (if approved)
├── docs/
│   ├── implementation/         # PRDs, PDRs, implementation plans
│   │   ├── PRODUCT_DEVELOPMENT_PROCESS.md
│   │   ├── PROCESS_QUICK_REFERENCE.md
│   │   ├── PRD-*.md            # Product requirements
│   │   ├── PDR-*.md            # Preliminary design reviews
│   │   └── VPN_PORTING_IMPLEMENTATION_PLAN.md
│   ├── templates/              # Document templates
│   │   ├── PRD-template.md
│   │   ├── PDR-template.md
│   │   └── github-*.md
│   ├── user/                   # User documentation
│   └── archive/                # Completed/historical docs
├── tests/                      # All test files
└── config/                     # Configuration files
```

#### Step 2.2: File Migration Plan
1. **Move existing docs** to proper locations
2. **Organize templates** in dedicated directory
3. **Archive completed** project documentation
4. **Update all references** in existing files

### Phase 3: CLAUDE.md Integration

#### Step 3.1: Update CLAUDE.md with PRD/PDR Workflow
Add comprehensive sections:
```markdown
## PRD/PDR Workflow (MANDATORY)

### When to Create PRD
- All new features (mandatory)
- Significant UX changes
- Business requirement changes
- Major integrations

### When to Create PDR
- All approved PRDs (mandatory)
- Technical architecture changes
- Performance optimizations
- Security enhancements

### Agent Requirements
- PRD: UX/Accessibility + General Purpose agents
- PDR: Architecture + Security + Performance + Quality agents (ALL 4 mandatory)

### Approval Process
1. Author creates document
2. Agent validation (required scores)
3. Stakeholder/team review
4. Doctor Hubert final approval
5. Implementation begins

### File Locations & Naming
- PRDs: docs/implementation/PRD-[name]-[date].md
- PDRs: docs/implementation/PDR-[name]-[date].md
- Use templates from docs/templates/

### GitHub Integration
- Branch naming: prd/[name] or pdr/[name]
- Use issue templates for tracking
- PR templates for approvals
- Reference in all commits/PRs
```

#### Step 3.2: Update Existing Workflows
- Integrate PRD/PDR requirements into TDD workflow
- Update agent analysis requirements
- Modify GitHub issue closure process
- Add quality gates for document approval

### Phase 4: Process Testing & Validation

#### Step 4.1: Create Test Documentation
Use our VPN Status Dashboard PRD as pilot:
1. **Follow full PRD process** with agent validation
2. **Test GitHub integration** with issues and PRs
3. **Validate approval workflow** with Doctor Hubert
4. **Document lessons learned** and refine process

#### Step 4.2: Team Training Materials
1. **Process walkthrough** documentation
2. **Template usage guides** with examples
3. **Agent interaction** best practices
4. **Common pitfalls** and solutions

## 🚨 Critical Decisions Needed

### Decision 1: Branch Strategy
**Question:** How should we handle the current mixed work?
**Options:**
- A: Separate branches for PDR system vs process framework
- B: Combine everything into process framework branch
- C: Start fresh with clean branches

**Recommendation:** Option A - separate concerns cleanly

### Decision 2: PDR System Implementation
**Question:** Should we complete the PDR system implementation or focus only on process framework?
**Context:** We have working PDR code but it's mixed with process work
**Recommendation:** Complete PDR system as separate deliverable, use as test case for new process

### Decision 3: Migration Timeline
**Question:** Should we migrate existing work to new structure immediately or gradually?
**Recommendation:** Immediate cleanup, gradual adoption of new process

## 📋 Implementation Checklist

### Immediate Actions (This Session):
- [ ] **Git State Resolution**: Commit work to proper branches
- [ ] **Directory Structure**: Implement standard organization
- [ ] **CLAUDE.md Update**: Add PRD/PDR workflow requirements
- [ ] **Template Finalization**: Review and approve all templates

### Next Session Actions:
- [ ] **GitHub Setup**: Configure issue templates and workflows
- [ ] **Process Testing**: Run pilot with VPN Status Dashboard PRD
- [ ] **Team Training**: Create usage documentation
- [ ] **Quality Gates**: Implement automated validation

### Future Actions:
- [ ] **Gradual Migration**: Move existing projects to new process
- [ ] **Continuous Improvement**: Refine based on usage feedback
- [ ] **Tool Integration**: Automate agent validation workflows

## 🎯 Success Criteria

### Immediate Success:
- Clean git history with logical separation
- Organized directory structure following standards
- CLAUDE.md properly updated with new workflow
- All templates ready for use

### Long-term Success:
- New features follow PRD/PDR process 100%
- Agent validation integrated into all technical decisions
- Doctor Hubert has clear approval checkpoints
- Team consistently produces high-quality documentation

## 🔄 Next Steps

1. **Doctor Hubert Approval**: Review and approve this cleanup plan
2. **Execute Cleanup**: Follow implementation checklist
3. **Test Process**: Use VPN Status Dashboard as pilot project
4. **Iterate & Improve**: Refine based on initial usage

---
This cleanup ensures we have a solid foundation before implementing any new features. The goal is a clean, organized repository with clear processes that scale as our development grows.

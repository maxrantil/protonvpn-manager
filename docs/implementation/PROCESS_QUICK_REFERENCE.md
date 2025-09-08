# PRD/PDR Process Quick Reference Guide

## When to Use What

### Use PRD When:
- ✅ New features or products
- ✅ Significant UX changes
- ✅ Business requirement changes
- ✅ Major system integrations

### Use PDR When:
- ✅ All approved PRDs (mandatory)
- ✅ Significant technical changes
- ✅ Architecture modifications
- ✅ Performance optimization projects
- ✅ Security enhancements

## Quick Workflow

```
💡 Idea/Request
     ↓
📋 PRD Creation → 🤖 UX Agent → 👥 Stakeholders → ✅ Doctor Hubert
     ↓
🏗️ PDR Creation → 🤖 4 Agents → 👨‍💻 Tech Team → ✅ Doctor Hubert
     ↓
⚡ Implementation (TDD) → 🧪 Testing → 🚀 Deployment
```

## File Locations

```
docs/
├── implementation/
│   ├── PRD-[name]-[date].md     # Product requirements
│   ├── PDR-[name]-[date].md     # Technical design
│   └── PRODUCT_DEVELOPMENT_PROCESS.md
├── templates/
│   ├── PRD-template.md
│   ├── PDR-template.md
│   ├── github-issue-prd-template.md
│   ├── github-issue-pdr-template.md
│   └── github-pr-template.md
└── archive/                      # Completed projects
```

## Agent Requirements

### PRD Agents (2 Required)
- **UX/Accessibility/I18n Agent**: User experience validation
- **General Purpose Agent**: Requirement completeness

### PDR Agents (4 Required - ALL MANDATORY)
- **Architecture Designer**: Score ≥4.0
- **Security Validator**: Risk ≤MEDIUM
- **Performance Optimizer**: Impact assessment
- **Code Quality Analyzer**: Score ≥4.0

## Quick Commands

```bash
# Create PRD from template
cp docs/templates/PRD-template.md docs/implementation/PRD-[name]-$(date +%Y-%m-%d).md

# Create PDR from template
cp docs/templates/PDR-template.md docs/implementation/PDR-[name]-$(date +%Y-%m-%d).md

# Run PRD agent validation
claude-agents validate-prd --document="PRD-[name].md" --agents="ux-accessibility-i18n,general-purpose"

# Run PDR agent validation (all 4 mandatory)
claude-agents validate-pdr --document="PDR-[name].md" --agents="architecture-designer,security-validator,performance-optimizer,code-quality-analyzer"
```

## Approval Checklist

### PRD Approval Requirements:
- [ ] UX Agent score ≥4.0
- [ ] General Purpose Agent approval
- [ ] All stakeholders reviewed
- [ ] Doctor Hubert approval

### PDR Approval Requirements:
- [ ] Architecture Designer score ≥4.0
- [ ] Security Validator risk ≤MEDIUM
- [ ] Performance Optimizer approval
- [ ] Code Quality Analyzer score ≥4.0
- [ ] Technical team review complete
- [ ] Doctor Hubert approval

## GitHub Integration

### Branch Names:
- `prd/[project-name]` - for PRD development
- `pdr/[project-name]` - for PDR development

### Issue Creation:
1. Use GitHub issue templates
2. Link PRD→PDR→Implementation issues
3. Reference in PR titles

### PR Requirements:
- Use PR template
- Show agent validation results
- Get Doctor Hubert approval before merge

## Common Pitfalls

❌ **Don't:**
- Skip agent validation
- Merge without Doctor Hubert approval
- Start implementation without approved PDR
- Mix PRD and PDR in same document

✅ **Do:**
- Follow templates completely
- Get all required agent approvals
- Document agent conflicts and resolutions
- Use TDD for all implementations
- Update roadmaps after approvals

## Emergency Shortcuts

**For Critical Bugs (Skip PRD, Fast-track PDR):**
1. Create minimal PDR with problem statement
2. Run 4 mandatory agents
3. Get Doctor Hubert approval
4. Implement with TDD
5. Document retrospectively

**For Small Changes (Documentation):**
- May skip PRD/PDR for pure documentation
- Still run relevant agents for technical accuracy
- Get peer review + Doctor Hubert approval

---
**Remember:** This process ensures quality, reduces miscommunication, and provides clear decision points. When in doubt, follow the full process.

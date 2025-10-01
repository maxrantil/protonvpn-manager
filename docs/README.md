# Documentation Index

**Last Updated:** October 1, 2025
**Project Status:** Simplified VPN Manager (master branch)

---

## 📚 Quick Reference

For comprehensive documentation structure and index, see:
### **→ [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)**

---

## 🎯 Quick Navigation

### **For Users**
- **[USER_GUIDE.md](USER_GUIDE.md)** - Complete user guide with usage examples
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Installation instructions ⚠️ (Update pending: Issue #61)

### **For Developers**
- **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** - Development workflow and TDD guidelines
- **[ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)** - System design (6 components)
- **[../CLAUDE.md](../CLAUDE.md)** - Project philosophy and guidelines (ESSENTIAL)

### **For Current Roadmap**
- **[implementation/ROADMAP-2025-10.md](implementation/ROADMAP-2025-10.md)** - 4-week execution plan
- **[implementation/ISSUES-CREATED.md](implementation/ISSUES-CREATED.md)** - GitHub issues #56-#77
- **[implementation/BASELINE-SCORES.md](implementation/BASELINE-SCORES.md)** - Quality metrics

---

## 💡 Project Philosophy

**"Do one thing and do it right."** - Unix philosophy

### What It Does ✅
- Connects to VPN servers intelligently
- Manages OpenVPN processes safely
- Tests server performance for optimization
- Provides clear status information

### What It Does NOT Do ❌
- Complex APIs or web interfaces
- Enterprise monitoring systems
- Background services or daemons
- Database management

---

## 🚀 Current Status

### System Overview
- **6 core components** (~2,996 lines total)
- **Quality Score:** 3.2/5.0 (baseline from Issue #53 analysis)
- **Status:** NOT production-ready (22 issues to resolve)
- **Target:** 4.5/5.0 within 4 weeks

### Branch Information
- **`master`**: Current development branch (simplified version)
- **`src_archive/`**: Archived enterprise components (24 components, ~10,500 lines)

### Active Work
See **[../SESSION_HANDOVER.md](../SESSION_HANDOVER.md)** for current session status.

---

## 📁 Documentation Structure

```
docs/
├── README.md                       # This file - quick navigation
├── DOCUMENTATION_INDEX.md          # Complete documentation index (NEW)
├── USER_GUIDE.md                   # User instructions
├── ARCHITECTURE_OVERVIEW.md        # System architecture
├── DEPLOYMENT_GUIDE.md             # Installation guide
├── DEVELOPER_GUIDE.md              # Development workflow
├── implementation/                 # Project tracking
│   ├── AGENT-ANALYSIS-2025-10-01.md    # 8-agent analysis
│   ├── ROADMAP-2025-10.md              # 4-week execution plan
│   ├── BASELINE-SCORES.md              # Quality metrics
│   ├── ISSUES-CREATED.md               # GitHub issues reference
│   ├── SIMPLIFICATION_HISTORY.md       # Simplification context
│   └── NEXT_SESSION_PLAN-2025-10-01.md # Completed task (archived)
└── templates/                      # Issue/PR templates
```

---

## 📋 Getting Started

### For New Users
1. Read **[USER_GUIDE.md](USER_GUIDE.md)** for setup
2. ⚠️ Wait for Issue #61 (installation process) before deploying
3. Use `./src/vpn help` to see commands

### For Developers
1. **MUST READ:** [../CLAUDE.md](../CLAUDE.md) - Project guidelines
2. Review [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) - Workflow
3. Check [implementation/ROADMAP-2025-10.md](implementation/ROADMAP-2025-10.md) - Current priorities

### For Contributors
1. Start with Issue #56 (Remove dead code) from roadmap
2. Follow TDD workflow (RED → GREEN → REFACTOR)
3. Run agent validation before PR

---

## 🔍 Finding Specific Information

| What You Need | Where to Look |
|---------------|---------------|
| Complete doc index | [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) |
| How to use VPN | [USER_GUIDE.md](USER_GUIDE.md) |
| How to develop | [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) |
| System design | [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md) |
| Installation | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) ⚠️ |
| Current roadmap | [implementation/ROADMAP-2025-10.md](implementation/ROADMAP-2025-10.md) |
| Quality scores | [implementation/BASELINE-SCORES.md](implementation/BASELINE-SCORES.md) |
| Project rules | [../CLAUDE.md](../CLAUDE.md) |
| Session status | [../SESSION_HANDOVER.md](../SESSION_HANDOVER.md) |

---

## ⚠️ Important Notes

### Known Issues
- **Documentation inaccuracies** (Issue #57): Some docs reference archived components
- **Installation broken** (Issue #61): Current installers don't work for simplified version
- **Testing docs missing** (Issue #74): README needs testing instructions

### Do Not Use (Archived)
- ~~`proton-auth`~~ - Archived in src_archive/
- ~~`download-engine`~~ - Archived in src_archive/
- ~~`config-validator`~~ - Archived in src_archive/

### Actual Components (6 total)
1. `src/vpn` - Main CLI
2. `src/vpn-manager` - Process management
3. `src/vpn-connector` - Connection logic
4. `src/best-vpn-profile` - Performance testing
5. `src/vpn-error-handler` - Error handling
6. `src/fix-ovpn-configs` - Config validation

---

**Simple VPN Manager** - Simple documentation for a simple tool.

For detailed documentation structure and comprehensive index:
### **→ [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)**

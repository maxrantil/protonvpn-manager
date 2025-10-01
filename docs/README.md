# Documentation Index

**Last Updated:** September 28, 2025
**Project Status:** Simple VPN Manager (vpn-simple branch)

## 📚 **Core Documentation**

### **Getting Started**
- **[`USER_GUIDE.md`](USER_GUIDE.md)** - Complete user guide with installation and usage
- **[`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)** - Simple installation and setup instructions

### **Understanding the System**
- **[`ARCHITECTURE_OVERVIEW.md`](ARCHITECTURE_OVERVIEW.md)** - 6-component system architecture
- **[`../README.md`](../README.md)** - Project overview and quick start

### **Development**
- **[`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md)** - Development guidelines and standards
- **[`../CLAUDE.md`](../CLAUDE.md)** - Project philosophy and development workflow

## 🎯 **Quick Start**

### **For Users**
```bash
# 1. Clone and setup
git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager
git checkout vpn-simple

# 2. Read user guide
cat docs/USER_GUIDE.md

# 3. Start using
./src/vpn help
./src/vpn best
```

### **For Developers**
```bash
# 1. Read the philosophy
cat CLAUDE.md

# 2. Understand the architecture
cat docs/ARCHITECTURE_OVERVIEW.md

# 3. Follow development guidelines
cat docs/DEVELOPER_GUIDE.md
```

## 📁 **Documentation Structure**

```
docs/
├── README.md                   # This file - documentation index
├── USER_GUIDE.md              # Complete user guide
├── ARCHITECTURE_OVERVIEW.md    # System architecture (6 components)
├── DEPLOYMENT_GUIDE.md         # Installation and setup
├── DEVELOPER_GUIDE.md          # Development guidelines
├── implementation/
│   └── SIMPLIFICATION_HISTORY.md  # Why/how system was simplified
├── templates/                  # GitHub templates for issues/PRs
└── user/                      # Additional user documentation
```

## 💡 **Project Philosophy**

This is a **simple, focused VPN management tool** following the Unix philosophy:

**"Do one thing and do it right."**

### What It Does
- Connects to VPN servers intelligently
- Manages OpenVPN processes safely
- Tests server performance for optimization
- Provides clear status information

### What It Does NOT Do
- ❌ Complex APIs or web interfaces
- ❌ Enterprise monitoring systems
- ❌ Background services or daemons
- ❌ Database management
- ❌ Notification frameworks

## 🚀 **Current Status**

### System Overview
- **6 core components** (~2,800 lines total)
- **Simple dependencies** (OpenVPN + bash + curl)
- **Fast performance** (< 2 second connections)
- **Easy maintenance** (minimal complexity)

### Branch Information
- **`vpn-simple`**: Current development branch (simplified system)
- **`master`**: Enterprise version (archived for reference)
- **`src_archive/`**: Removed enterprise components (24 components)

## 📋 **Next Steps**

### For New Users
1. Read [`USER_GUIDE.md`](USER_GUIDE.md) for complete setup instructions
2. Follow [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) for installation
3. Use `./src/vpn help` to see available commands

### For Developers
1. Read [`../CLAUDE.md`](../CLAUDE.md) for project philosophy
2. Review [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md) for coding standards
3. Study [`ARCHITECTURE_OVERVIEW.md`](ARCHITECTURE_OVERVIEW.md) for system design

---

**Simple VPN Manager** - Simple documentation for a simple tool.
**Focus**: VPN connection management
**Philosophy**: Unix simplicity and reliability

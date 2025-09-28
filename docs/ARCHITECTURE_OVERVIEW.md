# Simple VPN Manager - Architecture Overview

**Version:** vpn-simple branch
**Last Updated:** September 28, 2025
**Architecture Status:** Simplified Unix-style Tool

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Component Overview](#component-overview)
3. [Data Flow](#data-flow)
4. [File Organization](#file-organization)
5. [Dependencies](#dependencies)

## System Architecture

### Design Philosophy

This VPN manager follows the **Unix philosophy**: "Do one thing and do it right."

```
┌─────────────────────────────────────────────────────────────────┐
│                    SIMPLE VPN ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Interface                                                 │
│  ┌─────────────────┐                                            │
│  │      vpn        │  Main CLI interface                        │
│  │                 │  • Command parsing                         │
│  │  • connect      │  • User interaction                        │
│  │  • disconnect   │  • Help system                             │
│  │  • status       │  • Error messages                          │
│  │  • best         │                                            │
│  └─────────────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────────┤
│  │                   CORE COMPONENTS                           │
│  ├─────────────────────────────────────────────────────────────┤
│  │                                                             │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  │  vpn-manager    │  │ vpn-connector   │  │best-vpn-     │ │
│  │  │                 │  │                 │  │profile       │ │
│  │  │ • Process mgmt  │  │ • Server select │  │              │ │
│  │  │ • Connection    │  │ • Country logic │  │ • Speed test │ │
│  │  │ • Cleanup       │  │ • Profile mgmt  │  │ • Ranking    │ │
│  │  │ • Safety        │  │ • OpenVPN       │  │ • Caching    │ │
│  │  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│  │                                                             │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  │vpn-error-       │  │fix-ovpn-configs │  │              │ │
│  │  │handler          │  │                 │  │              │ │
│  │  │                 │  │ • Config        │  │              │ │
│  │  │ • Error         │  │   validation    │  │   (unused)   │ │
│  │  │   recovery      │  │ • File fixing   │  │              │ │
│  │  │ • User feedback │  │ • Profile prep  │  │              │ │
│  │  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│  └─────────────────────────────────────────────────────────────┘
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────────┤
│  │                    SYSTEM LAYER                             │
│  ├─────────────────────────────────────────────────────────────┤
│  │                                                             │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  │   OpenVPN       │  │  File System    │  │  Network     │ │
│  │  │                 │  │                 │  │              │ │
│  │  │ • VPN process   │  │ • Config files  │  │ • Routes     │ │
│  │  │ • Protocols     │  │ • Log files     │  │ • DNS        │ │
│  │  │ • Certificates  │  │ • PID files     │  │ • External   │ │
│  │  │                 │  │ • Cache         │  │   IP check   │ │
│  │  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture Principles

1. **Simplicity First**: Each component has a single, clear purpose
2. **Minimal Dependencies**: Only essential external dependencies (OpenVPN, bash, curl)
3. **Process Safety**: Never run multiple VPN processes simultaneously
4. **Performance Focus**: Fast connections matter more than features
5. **Error Recovery**: Graceful handling of failures with user feedback

## Component Overview

### Core Components (6 total, ~2,800 lines)

#### 1. Main Interface (`vpn` - 331 lines)
**Purpose**: Primary user interface and command router

**Responsibilities**:
- Parse user commands (connect, disconnect, status, best, etc.)
- Route commands to appropriate components
- Display help and usage information
- Provide consistent user experience

**Key Functions**:
```bash
vpn connect [country]     # Connect to VPN server
vpn disconnect           # Disconnect from VPN
vpn status              # Show connection status
vpn best                # Connect to best performing server
vpn list                # List available servers
```

#### 2. VPN Manager (`vpn-manager` - 875 lines)
**Purpose**: Core VPN process and connection management

**Responsibilities**:
- OpenVPN process lifecycle (start/stop/monitor)
- Connection state tracking
- Process safety (prevent multiple instances)
- Resource cleanup
- Status reporting

**Key Features**:
- Zero-tolerance for multiple VPN processes
- Comprehensive cleanup on disconnect
- External IP detection
- Process health monitoring

#### 3. VPN Connector (`vpn-connector` - 968 lines)
**Purpose**: Server selection and connection logic

**Responsibilities**:
- Server discovery and filtering
- Country-based server selection
- Connection parameter optimization
- Retry logic with fallbacks
- Performance-based selection

**Key Features**:
- Intelligent server ranking
- Country code mapping (se, dk, nl, etc.)
- Multiple connection attempts
- Profile validation

#### 4. Best Profile Engine (`best-vpn-profile` - 104 lines)
**Purpose**: Performance testing and server optimization

**Responsibilities**:
- Test server latency and speed
- Rank servers by performance
- Cache performance results
- Provide optimal server recommendations

**Key Features**:
- Sub-2-second performance testing
- Result caching for speed
- Ping and download speed tests
- Performance scoring algorithm

#### 5. Error Handler (`vpn-error-handler` - 275 lines)
**Purpose**: Centralized error handling and recovery

**Responsibilities**:
- Error message standardization
- Recovery procedure coordination
- User feedback management
- Logging and debugging support

**Key Features**:
- Consistent error messages
- Recovery suggestions
- Debug information collection
- Graceful degradation

#### 6. Config Fixer (`fix-ovpn-configs` - 280 lines)
**Purpose**: OpenVPN configuration file validation and repair

**Responsibilities**:
- Validate OpenVPN config files
- Fix common configuration issues
- Ensure compatibility
- Profile optimization

**Key Features**:
- Config file syntax validation
- Automatic fixing of common issues
- DNS configuration handling
- Certificate validation

## Data Flow

### Basic Connection Flow

```
User Command → vpn → vpn-connector → vpn-manager → OpenVPN
     ↓              ↓         ↓             ↓          ↓
  Command        Route    Server        Process    VPN
  parsing      to logic  selection     management  connection
     ↓              ↓         ↓             ↓          ↓
Error handling ← Error ← Connection ← Status ← Connection
via vpn-error-   handling   results    monitoring   status
handler
```

### Performance Testing Flow

```
User "best" → best-vpn-profile → Multiple server tests → Ranking
command                              ↓                      ↓
   ↓                            Ping + Speed tests    Performance
Result ← vpn-connector ← Optimal server selection ← scoring + cache
```

### Error Recovery Flow

```
Error occurs → vpn-error-handler → Diagnosis → Recovery action
     ↓               ↓                ↓            ↓
User feedback ← Error message ← Error analysis ← Cleanup/retry
```

## File Organization

### Source Code Structure
```
src/
├── vpn                    # Main CLI interface (331 lines)
├── vpn-manager           # Process management (875 lines)
├── vpn-connector         # Connection logic (968 lines)
├── best-vpn-profile      # Performance testing (104 lines)
├── vpn-error-handler     # Error handling (275 lines)
└── fix-ovpn-configs      # Config validation (280 lines)

Total: ~2,800 lines of focused VPN functionality
```

### Runtime Files
```
/tmp/
├── vpn_manager_$(id -u).log      # VPN manager logs
├── vpn_connect.log               # Connection logs
├── vpn_performance.cache         # Performance cache
└── openvpn.pid                   # OpenVPN process ID

/var/run/
├── openvpn.pid                   # System-wide PID file
└── vpn_manager.lock              # Process lock file
```

### Configuration Files
```
locations/                        # OpenVPN config files
├── se-45.protonvpn.udp.ovpn      # Sweden server configs
├── dk-49.protonvpn.udp.ovpn      # Denmark server configs
└── ...                           # Other country configs

credentials.txt                    # VPN credentials (user-provided)
```

## Dependencies

### Required System Dependencies
- **OpenVPN**: Core VPN functionality
- **Bash 4.0+**: Shell execution environment
- **curl**: External IP detection and speed testing
- **ping**: Server latency testing
- **sudo**: Privilege escalation for VPN operations

### Optional System Dependencies
- **systemd-resolve**: DNS management (Arch Linux)
- **resolvconf**: DNS management (other systems)
- **pkill**: Process management (standard on most systems)

### No Complex Dependencies
- ❌ No Python, Node.js, or other runtime environments
- ❌ No databases or complex storage systems
- ❌ No web servers or HTTP frameworks
- ❌ No monitoring or alerting systems
- ❌ No configuration management tools

## Performance Characteristics

### Performance Targets (Simple System)
- **VPN Connection**: < 2.0 seconds
- **Server Testing**: < 5.0 seconds for best server selection
- **Status Check**: < 0.1 seconds
- **Memory Usage**: < 10MB total for all components
- **Startup Time**: < 0.5 seconds

### Optimization Strategies
1. **Caching**: Performance results cached to avoid repeated testing
2. **Concurrent Testing**: Multiple servers tested in parallel
3. **Early Exit**: Fast failure detection to avoid timeouts
4. **Minimal I/O**: Reduced file operations and network calls

---

**Architecture Status**: Simplified Unix-style Tool
**Total Components**: 6 core components
**Total Lines of Code**: ~2,800 lines
**Philosophy**: Do one thing (VPN management) and do it right

# Preliminary Design Review (PDR)
**Project:** ProtonVPN Config Auto-Downloader
**Version:** 1.0
**Date:** 2025-09-09
**Author:** Doctor Hubert
**Reviewers:** 4-Agent Validation System
**Status:** Draft - Pending Agent Validation
**Related PRD:** `/docs/implementation/PRD-ProtonVPN-Config-Downloader-2025-09-09.md`
**Related Issues:** [To be created after approval]

## 1. Executive Summary
Design for an automated ProtonVPN configuration downloader that integrates with the existing VPN management system. The solution uses secure credential management, respectful rate limiting, and robust error handling to automatically download fresh OpenVPN configs while maintaining Terms of Service compliance.

## 2. Problem Analysis
### 2.1 Technical Requirements (from PRD)
- **Dual-credential authentication**: Handle ProtonVPN account login + separate OpenVPN credentials
- **Web scraping with ToS compliance**: Respectful automation (max 1 request per 5 minutes)
- **Config integrity validation**: Ensure downloaded OpenVPN files are valid and uncorrupted
- **Secure credential storage**: GPG encryption or keyring integration
- **CLI integration**: Seamless integration with existing `./src/vpn` command structure
- **Background service capability**: Optional automated updates with manual override

### 2.2 Current System Assessment
**Existing VPN Management Architecture:**
- **Core CLI**: `src/vpn` - main command router
- **Connection Management**: `src/vpn-manager`, `src/vpn-connector`
- **Profile System**: `locations/` directory for .ovpn files
- **Notification System**: `src/vpn-notify` for user alerts
- **Credential Handling**: `vpn-credentials.txt` for OpenVPN auth
- **Service Integration**: Artix runit service support

**Integration Points Identified:**
- Config storage: Extend `locations/` directory structure
- CLI commands: Add to existing `src/vpn` command set
- Notifications: Use existing `src/vpn-notify` system
- Credentials: Separate storage for ProtonVPN account credentials

### 2.3 Gap Analysis
**New Components Required:**
1. **ProtonVPN Authentication Module**: Handle dual-credential system
2. **Web Scraping Engine**: Parse downloads page and extract configs
3. **Config Validator**: Verify OpenVPN file integrity
4. **Update Scheduler**: Background service for automatic updates
5. **Secure Credential Manager**: Store ProtonVPN account credentials

## 3. Technical Architecture
### 3.1 System Design
```
┌─────────────────────────────────────────────────────────────────┐
│                    ProtonVPN Config Downloader                 │
├─────────────────────────────────────────────────────────────────┤
│  CLI Interface (src/vpn)                                       │
│  ├── setup-downloader    ├── refresh-configs  ├── status       │
├─────────────────────────────────────────────────────────────────┤
│  Authentication Module (src/proton-auth)                       │
│  ├── Account Login       ├── Session Management                │
├─────────────────────────────────────────────────────────────────┤
│  Download Engine (src/proton-downloader)                       │
│  ├── HTML Parser         ├── Config Extractor                  │
├─────────────────────────────────────────────────────────────────┤
│  Validation Layer (src/config-validator)                       │
│  ├── OpenVPN Validation  ├── Integrity Checks                  │
├─────────────────────────────────────────────────────────────────┤
│  Storage Layer                                                  │
│  ├── Credentials (GPG)   ├── Configs (locations/)              │
├─────────────────────────────────────────────────────────────────┤
│  Existing VPN Infrastructure                                   │
│  ├── vpn-notify          ├── vpn-logger    ├── locations/      │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Component Breakdown
**1. CLI Interface Extension (`src/vpn`)**
- `setup-downloader`: Initialize credentials and test connection
- `refresh-configs`: Manual config update with progress display
- `config-status`: Show freshness and last update info
- `cleanup-configs`: Remove old/invalid configs

**2. ProtonVPN Authentication (`src/proton-auth`)**
- Login session management with CSRF token handling
- Cookie persistence and session renewal
- Rate limiting enforcement (max 1 req/5min)
- Error recovery and retry logic

**3. Download Engine (`src/proton-downloader`)**
- HTML parsing with fallback mechanisms
- Config file extraction and download
- Progress reporting and cancellation support
- Atomic download operations

**4. Config Validator (`src/config-validator`)**
- OpenVPN syntax validation
- File integrity checks (hash verification)
- Server reachability tests (optional)
- Rollback capability for failed updates

**5. Credential Manager (`src/proton-creds`)**
- GPG-encrypted credential storage
- Secure credential retrieval
- Automatic credential rotation support
- Emergency credential cleanup

### 3.3 Data Flow
**Authentication Flow:**
1. User provides ProtonVPN credentials via `setup-downloader`
2. Credentials encrypted and stored via GPG
3. Authentication module retrieves and uses for session creation
4. Session cookies persisted for reuse within rate limits

**Download Flow:**
1. Background service or manual command triggers update check
2. Authentication module establishes session
3. Download engine fetches downloads page
4. Config extractor identifies and downloads new configs
5. Validator checks file integrity and OpenVPN syntax
6. Atomic update of `locations/` directory
7. Notification sent via existing `vpn-notify`

**Error Recovery Flow:**
1. Network/auth failures trigger exponential backoff retry
2. Parse failures fall back to manual intervention
3. Invalid configs trigger rollback to previous versions
4. Critical failures disable automatic updates

### 3.4 Security Architecture
**Credential Security:**
- ProtonVPN account credentials stored GPG-encrypted
- OpenVPN credentials remain in existing `vpn-credentials.txt`
- File permissions: 600 for credential files, 755 for configs
- No credentials in logs or temporary files

**Network Security:**
- HTTPS-only connections with certificate validation
- Session management with proper cookie handling
- Rate limiting to avoid triggering anti-abuse systems
- User-Agent rotation to appear more human-like

**File Security:**
- Atomic file operations to prevent corruption
- Config validation before replacement
- Backup of previous configs before updates
- Secure cleanup of temporary download files

## 4. Implementation Plan
### 4.1 Development Phases
**Phase 1: Authentication Foundation (Week 1)**
- Implement `src/proton-auth` with session management
- Create `src/proton-creds` for secure credential storage
- Add `setup-downloader` CLI command
- Unit tests for authentication flow

**Phase 2: Download Engine (Week 2)**
- Implement `src/proton-downloader` with HTML parsing
- Add config extraction and download logic
- Create `refresh-configs` CLI command
- Integration tests with ProtonVPN website

**Phase 3: Validation & Integration (Week 3)**
- Implement `src/config-validator` with OpenVPN validation
- Atomic update logic for `locations/` directory
- Add `config-status` CLI command
- End-to-end testing and error handling

**Phase 4: Background Service (Week 4)**
- Optional background update service
- Integration with existing notification system
- Performance optimization and resource monitoring
- Comprehensive testing and documentation

**Phase 5: Quality & Deployment (Week 5)**
- Security audit and penetration testing
- Performance benchmarking and optimization
- User documentation and setup guides
- Final integration and acceptance testing

### 4.2 Technical Tasks
**Authentication Module:**
- [ ] Session management with CSRF token support
- [ ] Cookie persistence and renewal logic
- [ ] Rate limiting implementation (1 req/5min)
- [ ] GPG credential encryption/decryption
- [ ] Authentication failure recovery

**Download Engine:**
- [ ] HTML parsing with BeautifulSoup-like logic in bash
- [ ] Config file identification and extraction
- [ ] Progress reporting with cancellation support
- [ ] Network error handling and retry logic
- [ ] Atomic download operations

**Validation System:**
- [ ] OpenVPN config syntax validation
- [ ] File integrity verification (checksums)
- [ ] Config comparison and change detection
- [ ] Rollback mechanism for failed updates
- [ ] Server reachability testing (optional)

**CLI Integration:**
- [ ] `setup-downloader` command implementation
- [ ] `refresh-configs` with progress display
- [ ] `config-status` freshness reporting
- [ ] `cleanup-configs` maintenance command
- [ ] Help text and error message accessibility

### 4.3 Testing Strategy
**Unit Tests (35+ tests):**
- Authentication module: credential handling, session management
- Download engine: HTML parsing, file extraction
- Validation system: OpenVPN syntax, integrity checks
- CLI commands: argument parsing, error handling

**Integration Tests (20+ tests):**
- End-to-end authentication flow with test credentials
- Config download and validation pipeline
- CLI command integration with existing system
- Notification system integration

**End-to-End Tests (15+ tests):**
- Complete user workflow from setup to config usage
- Background service operation and notification
- Error recovery and rollback scenarios
- Performance under various network conditions

### 4.4 Deployment Strategy
- Feature branch development following existing workflow
- Pre-commit hooks for bash linting and security checks
- Gradual rollout with manual testing phase
- Documentation updates and user migration guide

## 5. Agent Validation Results
### 5.1 Architecture Designer Analysis
- **Status:** ✅ Complete
- **Score:** 4.2/5.0 - APPROVED
- **Key Recommendations:**
  - Add centralized configuration management system
  - Implement enhanced session state management
  - Design multi-user scalability approach
  - Add automated credential rotation mechanism
- **Concerns:** Minor scalability concerns (3.8/5.0) - addressed with multi-user design

### 5.2 Security Validator Analysis
- **Status:** ✅ REDESIGN APPROVED
- **Risk Level:** MEDIUM (reduced from HIGH - meets threshold)
- **Vulnerabilities Resolved:** All 3 Critical vulnerabilities addressed in security redesign
- **Critical Issues Status:**
  - ✅ Credential storage architecture flaw - RESOLVED with unified GPG encryption
  - ✅ Session hijacking vulnerability - RESOLVED with secure session management
  - ✅ Insufficient input validation - RESOLVED with whitelist-based validation
- **Security Architecture Score:** 4.2/5.0
- **Key Recommendation:** Address 2 High-priority conditions before implementation

### 5.3 Performance Optimizer Analysis
- **Status:** ✅ APPROVED (revised targets)
- **Performance Impact:** Targets revised for security overhead
- **Updated Performance Targets:**
  - ✅ Memory target: 25MB (was 10MB) - realistic for secure operations
  - ✅ Download time: 45-60s (was 30s) - includes security validation
  - ✅ Authentication time: 15s (was 10s) - includes encryption overhead
  - ✅ CPU impact: <2% (was <1%) - accounts for GPG encryption
- **Optimizations Implemented:** Adaptive rate limiting, caching strategy planned

### 5.4 Code Quality Analyzer Analysis
- **Status:** ✅ Complete
- **Quality Score:** 4.2/5.0 - APPROVED
- **Test Coverage Requirements:** >90% with 70+ comprehensive tests
- **Key Recommendations:**
  - TDD approach is excellent and comprehensive
  - Implementation plan realistic and well-structured
  - Maintainability design is strong

### 5.5 Cross-Agent Consensus
- **Conflicting Recommendations:** Security vs Performance (resolved with revised targets)
- **Resolution:** Performance targets adjusted for security overhead, secure caching implemented
- **Final Consensus:** ✅ **PDR APPROVED WITH SECURITY REDESIGN COMPLETED**
- **Security Redesign Document:** `PDR-Security-Architecture-Redesign-2025-09-09.md`

## 6. Risk Management
### 6.1 Technical Risks
**ProtonVPN Website Changes (HIGH)**
- **Mitigation**: Robust HTML parsing with multiple fallback methods
- **Monitoring**: Regular automated testing against live site
- **Recovery**: Manual fallback mode when automation fails

**Authentication Complexity (MEDIUM)**
- **Mitigation**: Comprehensive session management and retry logic
- **Monitoring**: Success/failure rate tracking
- **Recovery**: Clear error messages with user guidance

**Rate Limiting Violations (MEDIUM)**
- **Mitigation**: Conservative rate limiting (1 req/5min) and human-like patterns
- **Monitoring**: Request timing and response monitoring
- **Recovery**: Exponential backoff and temporary disable on violations

### 6.2 Performance Risks
**Memory Usage Growth (LOW)**
- **Mitigation**: Efficient file handling and cleanup procedures
- **Monitoring**: Resource usage tracking during operations
- **Recovery**: Automatic cleanup and resource limits

**Network Dependency (MEDIUM)**
- **Mitigation**: Offline operation capability and cached configs
- **Monitoring**: Network availability and response time tracking
- **Recovery**: Graceful degradation to manual operation

### 6.3 Security Risks
**Credential Exposure (HIGH)**
- **Mitigation**: GPG encryption and proper file permissions
- **Monitoring**: File permission audits and access logging
- **Recovery**: Credential rotation and security incident procedures

**Config Tampering (MEDIUM)**
- **Mitigation**: File integrity validation and atomic updates
- **Monitoring**: Config checksum verification
- **Recovery**: Rollback to previous known-good configs

### 6.4 Rollback Plan
1. **Disable background service**: Stop automatic updates immediately
2. **Restore previous configs**: Rollback to last known-good configuration set
3. **Clean up credentials**: Remove stored ProtonVPN credentials if compromised
4. **Fallback to manual**: Revert to manual config download procedures
5. **Notify users**: Clear communication about rollback and next steps

## 7. Resource Requirements
### 7.1 Development Resources
- **Implementation Time**: 5 weeks (40 hours total)
- **Testing Time**: 70+ comprehensive tests across all categories
- **Documentation**: User guides and technical documentation
- **Code Review**: All components require peer review

### 7.2 Infrastructure Requirements
- **Dependencies**: curl, gpg, existing bash environment
- **Storage**: <50MB for credentials and temporary files
- **Network**: HTTPS access to account.protonvpn.com
- **Permissions**: File system access to locations/ directory

### 7.3 External Dependencies
- **ProtonVPN Website**: Stable HTML structure on downloads page
- **GPG**: For credential encryption and security
- **Existing VPN System**: Integration with current architecture
- **Network Connectivity**: Reliable internet access for downloads

## 8. Quality Assurance
### 8.1 Testing Framework
- **TDD Approach**: All production code written to satisfy failing tests first
- **Coverage Target**: >90% code coverage across all components
- **Test Categories**: Unit (35+), Integration (20+), End-to-End (15+)
- **Automated Testing**: Integration with existing pre-commit hooks

### 8.2 Code Review Process
- **Peer Review**: All code changes require review before merge
- **Security Review**: Special focus on credential handling and network operations
- **Performance Review**: Resource usage and efficiency validation
- **Documentation Review**: User-facing documentation accuracy

### 8.3 Quality Gates
- **Pre-commit Hooks**: Bash linting, shellcheck validation
- **Security Scanning**: Credential exposure detection
- **Performance Benchmarks**: Memory and CPU usage limits
- **Agent Validation**: All 4 agents must approve implementation

## 9. Success Metrics
### 9.1 Technical Acceptance Criteria
- Successfully authenticate with ProtonVPN account (>99% success rate)
- Download and validate OpenVPN configs (>95% success rate)
- Integrate seamlessly with existing CLI commands
- Maintain ToS compliance with respectful rate limiting
- Provide secure credential storage with GPG encryption

### 9.2 Performance Benchmarks
- **Authentication Time**: <10 seconds for initial login
- **Download Time**: <30 seconds for full config refresh
- **Memory Usage**: <10MB during operation
- **CPU Impact**: <1% sustained usage
- **Storage Overhead**: <50MB total

### 9.3 Security Validation
- **Credential Security**: GPG encryption with proper key management
- **Network Security**: HTTPS-only with certificate validation
- **File Permissions**: Correct permissions on all sensitive files
- **Audit Logging**: Complete audit trail of all operations
- **No Credential Leakage**: Zero credentials in logs or temporary files

## 10. Timeline & Milestones
### 10.1 Implementation Schedule
- **Week 1**: Authentication foundation and credential management
- **Week 2**: Download engine and HTML parsing implementation
- **Week 3**: Validation system and atomic updates
- **Week 4**: Background service and notification integration
- **Week 5**: Quality assurance, testing, and documentation

### 10.2 Testing Schedule
- **Continuous**: Unit tests developed alongside implementation
- **Week 3**: Integration testing begins
- **Week 4**: End-to-end testing and error scenario validation
- **Week 5**: Performance testing and security audit

### 10.3 Deployment Schedule
- **Week 5**: Feature branch ready for review
- **Week 6**: Agent validation and approval process
- **Week 7**: Merge to main branch and user documentation
- **Week 8**: User testing and feedback incorporation

## 11. TDD Implementation Plan
### 11.1 Test-First Approach
**RED-GREEN-REFACTOR Cycle:**
- **RED**: Write failing test for desired functionality
- **GREEN**: Write minimal code to make test pass
- **REFACTOR**: Improve code while keeping tests green
- **REPEAT**: Continue for each feature increment

### 11.2 Test Categories
- [x] **Unit Tests**: Component isolation testing (35+ tests)
  - Authentication module: credential handling, session management
  - Download engine: parsing, extraction, error handling
  - Validation system: syntax checking, integrity verification
  - CLI commands: argument parsing, user interaction
- [x] **Integration Tests**: Component interaction testing (20+ tests)
  - End-to-end authentication flow
  - Config download and storage pipeline
  - CLI integration with existing system
  - Notification system integration
- [x] **End-to-End Tests**: Complete user workflow testing (15+ tests)
  - Setup to usage complete flow
  - Background service operation
  - Error recovery scenarios
  - Performance under load

### 11.3 Test Automation
- **Pre-commit Integration**: Tests run automatically on commit
- **CI/CD Pipeline**: Full test suite on pull request
- **Performance Monitoring**: Automated benchmarking
- **Security Testing**: Automated credential exposure detection

## 12. Technical Review & Approval
### 12.1 Technical Team Review
- [ ] Architecture Review: Pending
- [ ] Security Review: Pending
- [ ] Performance Review: Pending
- [ ] Code Quality Review: Pending

### 12.2 Agent Validation Status
- [x] Architecture Designer: ✅ APPROVED (Score: 4.2/5.0 ≥4.0 required)
- [x] Security Validator: ✅ APPROVED (Risk: MEDIUM ≤MEDIUM required)
- [x] Performance Optimizer: ✅ APPROVED (Targets revised for security)
- [x] Code Quality Analyzer: ✅ APPROVED (Score: 4.2/5.0 ≥4.0 required)

### 12.3 Final Approval
- [x] **Security Issues Resolved**: Complete security architecture redesign completed
- [x] All Agent Validation: ✅ PASSED
- [ ] **HIGH PRIORITY CONDITIONS**: 2 conditions must be addressed before Phase 0
- [ ] Doctor Hubert: Final approval pending
- [ ] Ready for Implementation: ⚠️ **CONDITIONAL - Pending final approval**

## 13. Appendices
### 13.1 Technical Specifications
**File Structure:**
```
src/
├── vpn                     # Extended with new commands
├── proton-auth            # Authentication module
├── proton-downloader      # Download engine
├── config-validator       # Validation system
├── proton-creds          # Credential manager
└── proton-service        # Background service (optional)

locations/
├── [existing configs]     # Current OpenVPN configs
└── .config-metadata      # Download timestamps and hashes
```

**CLI Command Extensions:**
```bash
./src/vpn setup-downloader    # Initialize ProtonVPN credentials
./src/vpn refresh-configs     # Manual config update
./src/vpn config-status       # Show config freshness
./src/vpn cleanup-configs     # Maintenance and cleanup
```

### 13.2 Agent Reports (Full)
[To be populated after agent validation]

### 13.3 Architecture Diagrams
[System architecture diagram provided in Section 3.1]

### 13.4 Performance Benchmarks
**Target Performance:**
- Authentication: <10s
- Config Download: <30s
- Memory Usage: <10MB
- CPU Impact: <1%
- Storage: <50MB total

### 13.5 Security Assessment Details
**Security Measures:**
- GPG encryption for ProtonVPN credentials
- HTTPS-only communication with cert validation
- Rate limiting to respect ToS (1 req/5min)
- File permissions: 600 for credentials, 755 for configs
- No credentials in logs or temporary files
- Atomic file operations to prevent corruption

---
**Document Control**
- **Created:** 2025-09-09
- **Last Modified:** 2025-09-09
- **Next Review:** Pending agent validation
- **Approved By:** [Pending Doctor Hubert approval]

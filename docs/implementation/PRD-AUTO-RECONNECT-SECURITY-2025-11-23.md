# PRD: VPN Auto-Reconnect Security Hardening

**Document Version**: 1.0
**Date**: 2025-11-23
**Author**: Doctor Hubert (with Claude Code assistance)
**Status**: Approved (2025-11-23)
**Related Issue**: #227

---

## 1. Executive Summary

### Problem Statement

The existing VPN auto-reconnect implementation (issue #227) successfully handles sleep/wake cycles but contains critical security vulnerabilities identified during agent validation:

1. **Data leak window**: Traffic flows unprotected during VPN establishment on untrusted networks
2. **Race conditions**: Rapid network changes can spawn multiple VPN processes
3. **No rate limiting**: Unlimited reconnect attempts enable timing attacks
4. **No opt-in**: Feature is always active without user consent

### Proposed Solution

Harden the auto-reconnect feature with mandatory security controls:
- Kill switch must be enabled for auto-reconnect to function
- Exclusive locking prevents race conditions
- Rate limiting with exponential backoff
- Opt-in configuration (default: disabled)

### Success Criteria

- Zero data leaks during auto-reconnect (kill switch blocks all traffic until tunnel established)
- No race conditions under rapid network changes
- User must explicitly enable feature
- All existing functionality preserved

---

## 2. Background & Context

### Current State

Two scripts handle auto-reconnect:
1. `/lib/elogind/system-sleep/50-vpn-sleep` - Saves profile and disconnects before sleep
2. `/etc/NetworkManager/dispatcher.d/99-vpn-autoconnect` - Reconnects when network available

### Problem Discovery

During investigation of a network outage (2025-11-23), discovered:
- WiFi roaming between access points caused VPN to die
- Routes remained pointing to dead tun0 interface
- Internet blocked until manual `vpn cleanup`
- Existing auto-reconnect triggered but without security protections

### Agent Validation

Both `architecture-designer` and `security-validator` agents reviewed the approach:
- Architecture: Approved NM dispatcher approach
- Security: Identified 3 critical, 4 high, 3 medium vulnerabilities

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Auto-reconnect MUST only function when kill switch is enabled | P0 |
| FR-2 | Auto-reconnect MUST be opt-in via configuration | P0 |
| FR-3 | System MUST prevent concurrent reconnect attempts (locking) | P0 |
| FR-4 | System MUST rate-limit reconnect attempts (max 3 per 5 min) | P0 |
| FR-5 | System MUST use exponential backoff between attempts | P1 |
| FR-6 | System MUST validate profile integrity before connecting | P1 |
| FR-7 | System MUST log all reconnect attempts for audit | P1 |
| FR-8 | System MUST notify user on reconnect success/failure | P2 |

### 3.2 Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Reconnect attempt must start within 5s of network availability | P1 |
| NFR-2 | Lock acquisition timeout: 1 second (fail fast) | P1 |
| NFR-3 | Log retention: 30 days minimum | P2 |
| NFR-4 | No credentials logged, even on failure | P0 |

### 3.3 Security Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| SR-1 | ZERO traffic allowed before VPN tunnel established | P0 |
| SR-2 | Profile path must be validated (no symlinks, must be in config dir) | P0 |
| SR-3 | State files must have 600 permissions | P0 |
| SR-4 | Dispatcher hook must validate all NM inputs | P0 |

---

## 4. User Stories

### US-1: Automatic VPN Recovery (Primary)

**As a** VPN user on a mobile hotspot
**I want** my VPN to automatically reconnect when WiFi roams between access points
**So that** I don't lose protection or have to manually intervene

**Acceptance Criteria:**
- Given kill switch is enabled AND auto-reconnect is enabled
- When WiFi reconnects after brief outage
- Then VPN reconnects automatically within 10 seconds
- And no traffic leaks during the process

### US-2: Opt-in Configuration

**As a** security-conscious user
**I want** to explicitly enable auto-reconnect
**So that** I control when automatic network actions occur

**Acceptance Criteria:**
- Auto-reconnect is disabled by default
- User can enable via `vpn config auto-reconnect on`
- Setting persists across reboots

### US-3: Security Enforcement

**As a** user concerned about data leaks
**I want** auto-reconnect to require kill switch
**So that** my traffic is never exposed during reconnection

**Acceptance Criteria:**
- If kill switch is disabled, auto-reconnect silently exits
- No traffic flows until VPN tunnel is fully established

---

## 5. Out of Scope

- Trusted network whitelisting (complexity vs. benefit too low)
- WireGuard auto-reconnect (separate issue #223)
- GUI notifications (CLI tool)
- Automatic kill switch enablement (user must explicitly enable)

---

## 6. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Data leak incidents | 0 | Code path analysis + testing |
| Race condition occurrences | 0 | Lock acquisition logging |
| User-reported connectivity issues | Decrease by 50% | GitHub issues |
| Successful auto-reconnects | >90% when conditions met | Logging metrics |

---

## 7. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Kill switch left enabled, blocking internet after failure | Medium | High | Auto-disable after N failures + notification |
| Users disable kill switch to bypass requirement | Low | High | Document security implications clearly |
| Feature complexity increases maintenance burden | Medium | Medium | Keep dispatcher hook minimal (<150 lines) |

---

## 8. Timeline Estimate

| Phase | Description | Effort |
|-------|-------------|--------|
| Phase 1 | State management foundation | 2-3 hours |
| Phase 2 | Kill switch integration | 1-2 hours |
| Phase 3 | Dispatcher hook hardening | 3-4 hours |
| Phase 4 | Configuration option | 1-2 hours |
| Phase 5 | Testing | 3-4 hours |
| **Total** | | **10-15 hours** |

---

## 9. Approval

- [x] Doctor Hubert approval (2025-11-23)
- [x] Security requirements reviewed
- [x] Architecture requirements reviewed

---

## Appendix A: Agent Validation Summary

### Architecture Designer
- **Verdict**: GREEN - Proceed
- **Key recommendation**: NM dispatcher is correct integration point

### Security Validator
- **Verdict**: HIGH RISK - Conditional Proceed
- **Key requirement**: MUST couple with kill switch
- **Critical issues identified**: 3 (all addressed in requirements)

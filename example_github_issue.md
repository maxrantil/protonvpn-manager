# Example GitHub Issue Template

This file demonstrates how to create a GitHub issue following the new workflow requirements in CLAUDE.md.

## Issue Title
"Implement Phase 4: Performance Testing Engine"

## Issue Body
```markdown
## Summary
Implement the Performance Testing Engine (Phase 4) of the VPN porting implementation plan.

## Scope
This phase includes:
- Network connectivity testing (ping, DNS resolution)
- Server performance testing with multi-server latency testing
- Intelligent server selection based on performance scoring

## Acceptance Criteria
- [ ] Network connectivity validation works reliably
- [ ] `best-vpn-profile` can test 8 profiles and rank by performance
- [ ] Smart connection logic selects optimal servers (score < 20)
- [ ] Bad servers are avoided (score > 200)
- [ ] Connection failure limits enforced (max 2 consecutive)

## Implementation Plan
Following VPN_PORTING_IMPLEMENTATION_PLAN.md Phase 4 tasks:
- 4.1 Network Connectivity Testing
- 4.2 Server Performance Testing
- 4.3 Intelligent Server Selection

## Dependencies
- Requires Phase 3 (Connection Management) to be complete ✅
- Must integrate with existing cache system

## Labels
- enhancement
- phase-4
- performance-testing

## Workflow Notes
This issue was created following CLAUDE.md requirements:
- Created BEFORE starting work on Phase 4
- References specific implementation plan sections
- Will be updated when phase marked complete
```

## GitHub CLI Command
To create this issue using GitHub CLI:
```bash
gh issue create --title "Implement Phase 4: Performance Testing Engine" --body "$(cat <<'EOF'
## Summary
Implement the Performance Testing Engine (Phase 4) of the VPN porting implementation plan.

## Scope
This phase includes:
- Network connectivity testing (ping, DNS resolution)
- Server performance testing with multi-server latency testing
- Intelligent server selection based on performance scoring

## Acceptance Criteria
- [ ] Network connectivity validation works reliably
- [ ] `best-vpn-profile` can test 8 profiles and rank by performance
- [ ] Smart connection logic selects optimal servers (score < 20)
- [ ] Bad servers are avoided (score > 200)
- [ ] Connection failure limits enforced (max 2 consecutive)

## Implementation Plan
Following VPN_PORTING_IMPLEMENTATION_PLAN.md Phase 4 tasks:
- 4.1 Network Connectivity Testing
- 4.2 Server Performance Testing
- 4.3 Intelligent Server Selection

## Dependencies
- Requires Phase 3 (Connection Management) to be complete ✅
- Must integrate with existing cache system
EOF
)"
```

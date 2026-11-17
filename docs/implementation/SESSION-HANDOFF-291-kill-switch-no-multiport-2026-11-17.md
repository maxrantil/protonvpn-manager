# Session Handoff: #291 kill switch allows the VPN server without multiport

**Date**: 2026-11-17
**Issue**: #291 - fix(kill-switch): do not depend on the multiport match module
**PR**: #292 - fix(kill-switch): allow the VPN server with one rule per port (draft)
**Branch**: `fix/issue-291-kill-switch-no-multiport`
**Also this session**: PR #290 (#288) squash-merged as `784169f`; #288 closed

## ✅ Completed Work

- **Found in live validation of #290**: `vpn kill-switch enable` failed with
  `Extension multiport revision 0 not supported` and
  `RULE_APPEND failed (No such file or directory)`. Cause: the running kernel is
  `7.2.14`, but only the `7.2.15` modules are on disk (upgraded, not rebooted), so
  `xt_multiport`, which wasn't loaded on this boot, can't load now. The kill switch
  failed closed: no chain was applied.
- **Doctor Hubert chose**: fix now, before #282, and validate without rebooting.
- **Fix** (`src/vpn-kill-switch`): one rule per port,
  `-d IP -p <udp|tcp> -m <udp|tcp> --dport N -j ACCEPT`. This uses only the
  `udp`/`tcp` match, which the chain's DHCP rule already needs. The traffic allowed,
  the 15-port cap and the server record format are all unchanged.
- **Tests** (`tests/unit/test_hardening.sh`):
  - The new `ks_port_rules` helper builds the expected rules.
  - A new assertion checks that no rule uses `multiport`.
  - 13b now expects the literal `-p udp -m udp --dport 1194`.
  - RED 66/77, GREEN 77/77. Full suite with the VPN connected: 126 passed, 0 failed.
- **Docs**: `docs/MACHINE-VALIDATION.md` §6 describes the per-port rules.
- **Live, on this boot (kernel not rebooted), branch build installed**, with a
  3-minute auto-disable watchdog armed:
  - The kill switch enabled with 5 `--dport` rules (udp 1194, 5060, 80, 4569, 51820).
  - `/run/protonvpn-manager-session/kill_switch.server` is root-owned, mode 600.
  - HTTPS works and DNS resolves through the VPN.
  - DNS to the router (172.20.10.1) timed out, so it is blocked as intended.
  - `vpn kill-switch off` removed the chain and the record, and normal browsing
    returned.
- **Not run in §6**: the "`vpn disconnect` turns it off" and country-switch items,
  since they disconnect the VPN. Neither is affected by this change.
- **Noticed**: the `vpn` wrapper only takes `on|off|status|emergency|help`. It has no
  `is-enabled` (only `vpn-kill-switch` itself does). This is pre-existing, and not
  filed.

### Agent Validation Status

- security-validator: **4.5/5**, no blockers. Its optional points were not done:
  - (1) Re-check each port inside the rule loop (defense in depth).
  - (2) Normalize ports with leading zeros, so they dedupe exactly.
  - (3) Run the route-derived IP through `is_ipv4` (pre-existing).
  - (4) More tests: an "any -" record, and 15- and 16-port rule counts.
- code-quality-analyzer: **4.5/5**, no blockers. Its optional points (wider no-multiport
  assertion, naming `xt_multiport` in the docs) were not done. Pre-commit's shellcheck
  then flagged SC2251 on the new assertion, which is fixed.

## 🎯 Current Project State

- **Machine**: VPN connected (dk-120); kill switch off. `/usr/local/bin/vpn-kill-switch`
  is the **#291 branch build**; the rest of `src/` is installed at `41aad5b`.
- **Kernel**: running 7.2.14, modules for 7.2.15. A reboot is pending, and Doctor
  Hubert chooses when.

## 🚀 Next Session Priorities

1. Merge #292 once CI is green and Doctor Hubert agrees. The installed kill switch
   already matches it.
2. #282 (stricter `vpn_is_healthy`), then #277, then #223 WireGuard (PRD)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #291 (kill switch
allows the VPN server without multiport, PR #292).

**Immediate priority**: merge #292 once CI is green and Doctor Hubert agrees; then start #282
**Context**: maintenance phase; #290 merged and validated live except the disconnect items
**Reference docs**: SESSION_HANDOVER.md,
docs/implementation/SESSION-HANDOFF-291-kill-switch-no-multiport-2026-11-17.md
**Ready state**: master `784169f`; `vpn-kill-switch` installed from the #291 branch; VPN connected (dk-120); `~/vpn-recover.sh`
**Expected scope**: #292 merged; #282 issue analysis and TDD started

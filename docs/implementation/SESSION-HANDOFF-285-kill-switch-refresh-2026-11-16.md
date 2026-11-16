# Session Handoff: #285 kill switch refresh fails with the tunnel down

**Date**: 2026-11-16
**Issue**: #285 - fix(kill-switch): refresh fails whenever the tunnel is down, which is every hook reconnect
**PR**: #286 - fix(kill-switch): refresh rules while the tunnel is down (draft, CI green)
**Branch**: `fix/issue-285-kill-switch-refresh-without-tunnel`
**Also this session**: PR #284 (#283) merged as `c79ee29`; `src/` and the reconnect hook installed

## ✅ Completed Work

- **#283 / PR #284**: CI green (10/10), squash-merged, issue closed. Installed:
  `vpn-manager` and `vpn-kill-switch` changed; every component in `/usr/local/bin`
  now matches master `c79ee29`, and `/etc/NetworkManager/dispatcher.d/50-vpn-reconnect`
  matches master (includes #281). VPN stayed up through the install.
- **Root cause of "Kill switch refresh failed"**: the hook calls `vpn-kill-switch refresh`
  only after the VPN has dropped, and `refresh` went through `enable_kill_switch`'s tun0
  check ("VPN interface (tun0) not found"), so it failed on every hook reconnect
  (`reconnect.log`, 2026-11-07/08) and the rules were never refreshed.
- **Fix** (`src/vpn-kill-switch`, `refresh` case): skip the tun0 check, the same override
  `enable --force` uses. Safe because refresh only runs when the kill switch is already
  on; the server IP falls back to the session log or the saved state. `enable` keeps its
  check.
- **Test** (`tests/unit/test_hardening.sh`, 13b): unprivileged, with `sudo`,
  `iptables*`, `ip` and `ps` stubbed on PATH, so no real firewall is touched:
  - refresh succeeds with tun0 absent
  - the saved server IP is still allowed
  - both chains end in DROP
  - with no known server the chain allows no host and still ends in DROP
  - `enable` still refuses, and for the tunnel reason

  Before the fix, the four refresh assertions fail; after it, all five pass.
- **Internet drop at 08:16 (reported by Doctor Hubert)**: an 8 s s2idle suspend.
  The wlan deauth removed the server route, tun0 sat in a routing loop ("Dead loop on
  virtual device tun0") for ~2.5 min, and then the peer was deleted. This is the known
  suspend issue (decided: stay manual); recovered with `vpn cleanup && vpn connect dk`.

## 🎯 Current Project State

- **Tests**: CI green on #286 (Unit Tests exit code 0, so `test_hardening.sh` passed
  there). Locally `run_tests.sh` says 91/0, but that is **not reliable while connected**:
  see #287.
- **Local `test_hardening.sh` with the VPN up**: 2 environmental failures, also on master
  (`find_openvpn_pids returns only the daemon`, `cleanup completes quickly`); the live
  OpenVPN was verified untouched.
- **Branch**: #286 branch pushed and clean; master `c79ee29`
- **Machine**: VPN connected (dk-120); kill switch off; reconnect hook current; sleep hook
  not installed

### Agent Validation Status

- code-quality-analyzer: 4/5, no blockers. The test is not vacuous and leaks no state.
  Suggested pinning `enable`'s refusal reason (done). Optional: a shared skip-tunnel
  helper or an `--allow-no-tunnel` parameter instead of the function override.
- security-validator: 3.5/5 (threshold 4.0). No new fail-open; refresh now creating the
  IPv4 chain from an IPv6-only state is more restrictive, which is accepted. The MEDIUM
  findings are all pre-existing in `get_vpn_server_ip`: Method 1 takes any host route;
  Method 2 trusts `ps` argv from any user; the Method 3 state file is user-writable and
  unchecked; the server ACCEPT is not limited by port or protocol. The hook now reaches
  them more often, so they are filed as **#288**. Test for refresh with no server IP
  added.

## 🚀 Next Session Priorities

1. Doctor Hubert decides on merging #286 (security score 3.5 is below the 4.0 threshold;
   the gap is #288, which predates #286); after the merge, reinstall `vpn-kill-switch`
2. #287: the suite hides `test_hardening.sh` failures while connected (1-2 h, makes local
   results trustworthy again)
3. #288: choose the allowed server IP from trusted sources only (2-3 h)
4. Then #282 (stricter `vpn_is_healthy`), #277, and #223 WireGuard (PRD)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #285 (kill switch
refresh with the tunnel down, draft PR #286, CI green).

**Immediate priority**: merge #286 if Doctor Hubert agrees, reinstall `vpn-kill-switch`;
then #287, so the suite reports `test_hardening.sh` failures while connected (1-2 h)
**Context**: maintenance phase; #283 merged and installed, reconnect hook current
**Reference docs**: SESSION_HANDOVER.md,
docs/implementation/SESSION-HANDOFF-285-kill-switch-refresh-2026-11-16.md
**Ready state**: master `c79ee29` installed; VPN connected (dk-120); `~/vpn-recover.sh`
**Expected scope**: #286 merged and installed; #287 fixed with a test; #288 started

## 📚 Key Reference Documents

- `docs/implementation/SESSION-HANDOFF-283-give-to-real-user-2026-11-16.md`
- Issues #287 and #288 (problem statements and fix directions)

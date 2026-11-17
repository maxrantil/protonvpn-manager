# Session Handoff: #282 vpn_is_healthy counts only this tool's VPN

**Date**: 2026-11-17
**Issue**: #282 - fix(reconnect): vpn_is_healthy treats any openvpn plus any tun0, or any WireGuard interface, as this tool's VPN
**PR**: #293 - fix(reconnect): count only this tool's OpenVPN as a healthy VPN (draft)
**Branch**: `fix/issue-282-strict-vpn-health`
**Also this session**: PR #290 (#288) merged as `784169f`; #291 found live and fixed in
PR #292, merged as `5938332` (see `SESSION-HANDOFF-291-kill-switch-no-multiport-2026-11-17.md`)

## ✅ Completed Work

- **`vpn_is_healthy` in `etc/NetworkManager/dispatcher.d/50-vpn-reconnect`** now counts
  the VPN as healthy only when:
  1. The PID file `/var/run/openvpn.pid` is a regular file (not a symlink) owned by root.
     openvpn writes it via `--writepid` when `vpn-connector` starts it.
  2. That PID's process is owned by root, its `comm` is `openvpn`, and its cmdline has
     `--config /run/protonvpn-manager-session/profile.ovpn`.
  3. `ip -o link show dev tun0 up` lists tun0, meaning tun0 is administratively up.
- **WireGuard no longer counts**: this tool refuses WireGuard until #223, so any
  WireGuard interface belongs to something else. #223 has to add its own record.
- **The paths are fixed constants in the hook** (`VPN_PID_FILE`, `VPN_SESSION_PROFILE`,
  `VPN_TUNNEL_INTERFACE`, `VPN_PROC_DIR`). The hook runs as root and reads no
  environment, so a `VPN_SESSION_DIR` override (dev or test) never reads as healthy.
- **Not done: tying tun0 to the process.** This OpenVPN uses kernel DCO, so it holds no
  tun fd to check (checked in `/proc/<pid>/fd`). A foreign tun0 together with our live
  openvpn still reads as healthy. That is residual and no worse than before.
- **Tests** (`tests/unit/test_auto_reconnect.sh`): the `run_vpn_is_healthy` harness uses
  a fake `/proc`, a fake PID file and PATH stubs (`ip`, `stat`, `wg`, `pgrep`), so the
  result never depends on the live VPN. It runs under the hook's `set -euo pipefail` and
  calls the function as an `if` condition. 13 cases: healthy; stale PID; no tun0; tun0
  down; foreign tun0 with no PID file; other config; not openvpn; user-owned PID file;
  symlinked PID file; foreign WireGuard (two variants); tun0 up with the process gone;
  user-run openvpn on a reused PID.
  - RED: 7 of the first 10 cases failed against the old check. GREEN: 40/40 in that
    file. Full suite: 126 passed, 0 failed, with the VPN connected.
- **Live, read-only, as root**: the function reports the current dk-120 connection as
  healthy, and reports not healthy with a wrong interface name.

### Agent Validation Status

- security-validator: **4.3/5**, no blockers. Points 1 (root-owned process) and 2 (no
  `ip | grep -q` under pipefail) are done. Not done: point 3 (compare
  `/proc/<pid>/exe` to the openvpn binary path); the `VPN_SESSION_DIR` note is recorded
  here.
- code-quality-analyzer: **4.2/5**, no blockers. Done: tests run under
  `set -euo pipefail` as an `if` call, plus the cases `trusted stale up` and
  `trusted ours missing foreign`, and `|| return 1` on the PID read. Not done: argument
  checks in the stubs, and junk-content and no-trailing-NUL cases.

## 🎯 Current Project State

- **Machine**: VPN connected (dk-120); kill switch off; `vpn-kill-switch` installed at
  master `5938332`. The **dispatcher hook in /etc is not updated** (install after merge).
- **Kernel**: reboot pending (running 7.2.14, modules for 7.2.15)

## 🚀 Next Session Priorities

1. Merge #293 once CI is green and Doctor Hubert agrees. Then install the hook:
   `sudo install -o root -g root -m 755 etc/NetworkManager/dispatcher.d/50-vpn-reconnect /etc/NetworkManager/dispatcher.d/`
2. #277, then #223 WireGuard (PRD)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #282 (vpn_is_healthy
counts only this tool's VPN, PR #293).

**Immediate priority**: merge #293 once CI is green and Doctor Hubert agrees; install the dispatcher hook
**Context**: maintenance phase; #290 and #292 merged and installed; kill switch validated live
**Reference docs**: SESSION_HANDOVER.md,
docs/implementation/SESSION-HANDOFF-282-strict-vpn-health-2026-11-17.md
**Ready state**: master `5938332`; VPN connected (dk-120); `~/vpn-recover.sh`
**Expected scope**: #293 merged and installed; then start #277

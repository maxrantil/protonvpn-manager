# Session Handoff: Kill switch and VPN DNS are never left behind

**Date**: 2026-11-09
**Issue**: #238 - Kill switch stays on after the tunnel dies; disconnect and reconnect cannot recover
**PR**: #241 (stacked on #240)
**Branch**: `fix/kill-switch-cleanup`

## ✅ Completed Work

- `vpn disconnect` always releases the kill switch and the VPN's DNS once no
  VPN runs, also when the tunnel had already died (it returned early before)
  and with `AUTO_RECONNECT=true`; INT/TERM/HUP are ignored until it is done
- Every connect command starts with `begin_connect`, which removes a kill
  switch and DNS entries left without a running VPN (they blocked the latency
  checks and every new server)
- Ctrl+C/SIGTERM while connecting undoes the half-made connection; an
  established or pre-existing VPN is left alone
- `is-enabled` sees an IPv6-only leftover; `disable` removes duplicate jumps
- `clear_vpn_dns` removes `<dev>.protonvpn` and stale `tunN.*` entries
- Sleep/NetworkManager hooks pass `VPN_KEEP_KILL_SWITCH=1` so the kill switch
  still stays on across suspend and auto-reconnect
- `tests/unit/test_kill_switch_cleanup.sh` (26 tests, real iptables in a
  private network namespace)

## 🎯 Current Project State

- **Tests**: ✅ all unit suites pass (run from `tests/`)
- **CI/CD**: ✅ all checks green (ShellCheck needed retries: GitHub release
  downloads of shellcheck failed intermittently)
- **Live test** (real ProtonVPN, Tailscale running, 90s automatic rollback):
  kill switch on, IPv6 and router DNS blocked, disconnect left 0 rules and the
  network back on the first try

### Agent Validation Status

- Not run: no specialist agents were used in this session

## 🚀 Next Session Priorities

1. Merge after #240, before #243
2. The installed NetworkManager hook (`/etc/NetworkManager/dispatcher.d/50-vpn-reconnect`)
   is a hand-edited copy from 2025-10-11 that calls `connect <path>` and fails on
   every network change: reinstall it from `etc/` (install.sh does not)
3. `tests/test_exit_codes.sh` makes real VPN connections when `run_tests.sh`
   runs on a machine with credentials: guard it or move it out of the default run

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then review and merge PR #241
(after PR #240), and reinstall the NetworkManager reconnect hook from `etc/`
by hand.

## 📚 Key Reference Documents

- `tests/unit/test_kill_switch_cleanup.sh`, `docs/MACHINE-VALIDATION.md`

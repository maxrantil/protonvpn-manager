# Session Handoff: Faster connect

**Date**: 2026-11-07
**Branch**: `perf/faster-connect`

## ✅ Completed Work

- Connection monitor polls the OpenVPN log every 0.25s (was 1,1,2,2,3,3,4,5,6,8s
  sleeps); same 35s budget, configurable via `CONNECT_TIMEOUT` (5-300s).
- Failover: `connect`/`best`/`fast` try up to `FAILOVER_SERVERS` (default 3)
  fastest servers, one attempt each, when a server does not answer; a single
  candidate keeps 3 attempts; non-timeout failures (bad credentials) stop.
- `connect_openvpn_profile`/`connect_wireguard_profile` return 2 when the server
  did not answer, so callers can tell timeouts from other failures.
- `check_dependencies` needs only openvpn, ip, flock; wg-quick is checked for
  WireGuard profiles; `bc` dropped from install.sh and vpn-doctor (unused).
- `tests/unit/test_exponential_backoff.sh` rewritten for polling (timeout
  budget, CONNECT_TIMEOUT handling, early return); failover and dependency
  tests in `tests/unit/test_latency_selection.sh`.

## 🎯 Current Project State

- No regressions vs master across all test files.

## 🚀 Next Session Priorities

1. Real-machine check: time `vpn connect se`; disconnect a server's network
   path (or use a bogus profile first in line) to see failover.

## 📝 Startup Prompt for Next Session

Validate faster connect and failover on real hardware.

## 📚 Key Reference Documents

- `src/vpn-connector` (`monitor_connection_establishment_with_backoff`,
  `connect_with_failover`, `failover_count`)

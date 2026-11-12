# Session Handoff: Issue #260 - latency ranking left failover one candidate

**Date**: 2026-11-12
**Issue**: #260 - per-profile parallel pings to shared hosts leave failover with one candidate
**PR**: #264 - fix(latency): measure each server once and keep TCP-only servers in the ranking
**Branch**: `fix/issue-260-latency-shared-hosts`

## ✅ Completed Work

- `src/best-vpn-profile` `rank`:
  - measures each distinct `host port` target once (worker `__measure "<host> <port>"`,
    re-validated) and joins the result back to every profile on it; Proton's 23 `se`
    profiles are 3 measurements (~1.4 s)
  - ranks TCP-only servers after the ICMP ones instead of dropping them
  - does not reuse failed (`-`) cache entries; a dead server is probed on every connect
  - `ping` under `timeout $((PING_COUNT + 2))` with `--`; paths with control characters
    skipped; host names lowercased
- Tests (`tests/unit/test_latency_selection.sh`, 39/39, RED first): rate-limited stub host
  (drops a ping while another is in flight), switchable host, hanging host; shared host
  pinged once with no drops; TCP-only kept; failed result re-measured; connector tries 3
  servers; tab path skipped; hanging ping cut off; case-insensitive hosts.
- #262 (#259 doctor) merged and installed; its missing handoff file added before merging.
- **#265 filed**: WireGuard connect reports success, the interface disappears, and
  `vpn status`/`vpn disconnect` don't see WireGuard.

## 🎯 Current Project State

- **Tests**: ✅ `run_tests.sh` 114 passed / 0 failed
- **Machine check (step 7)**: ✅ failover triggered (run from `src/`, not installed):
  "24 of the servers answered", `se-999` timed out after 10 s, next server connected.
  The 1.1.1.1 stand-in in the doc loses the ranking to real servers, and an earlier
  measurement of `se-999` is reused for 15 min: the gateway address plus
  `best-vpn-profile clear` worked. Doc fix pending (after #261).

### Agent Validation Status

- code-quality-analyzer: **4.5/5**, no must-fix. Done: case-insensitive hosts, worker
  comment, failover test comment. Noted in the PR: dead servers are re-measured each run.
- security-validator: **4.3/5**, no must-fix. Done: control-character paths skipped, ping
  under `timeout` with `--`. Not done (pre-existing, low): cache field validation on
  read, clamping `JOBS`/`PING_COUNT`, port range.
- test-automation-qa: **4/5**, no must-fix. Done: drop counter on the rate-limited stub.
  Not done: silent skip of TCP tests without python3, same host on two TCP ports.

## 🚀 Next Session Priorities

1. Merge #261 (blocked for me by the auto-mode classifier) and #264; install
2. Step 7 doc: stand-in on the default gateway, `best-vpn-profile clear` first
3. #265 (WireGuard) or #263 (connector counters)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #260 (✅ PR #264:
latency ranking measures each server once).

**Immediate priority**: merge #261 and #264, install, fix the step 7 fixture in the doc (1 h)
**Context**: maintenance phase; #259 merged; #263 and #265 open
**Reference docs**: SESSION_HANDOVER.md, docs/MACHINE-VALIDATION.md, `src/best-vpn-profile`
**Ready state**: VPN disconnected, kill switch off; `~/vpn-recover.sh` for emergencies
**Expected scope**: doc fixed, then #265 or #263

## 📚 Key Reference Documents

- `src/best-vpn-profile` (`probe_target`, `measure_target`, `rank_profiles`)
- `tests/unit/test_latency_selection.sh` (sections 14-19)

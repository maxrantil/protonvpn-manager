# Session Handoff: Issue #257 - Deterministic flock stress test

**Date**: 2026-11-10
**Issue**: #257 - Flock stress test (T2.4) fails CI on scheduling luck, not on locking bugs
**PR**: see branch `fix/issue-257-flock-stress-deterministic`
**Branch**: `fix/issue-257-flock-stress-deterministic`

## ✅ Completed Work

- T2.4 in `tests/test_flock_lock_implementation.sh` required ≥10 of 1000 non-blocking
  `flock -n` attempts to succeed. That count depends on scheduling only. CI failed with
  8, 9 and 9 (twice on PR #256), while locally it is 12-23. It also could not catch a
  broken lock: two holders at once *raise* the count.
- T2.4 now asserts mutual exclusion and progress. A holder creates an occupancy marker
  with noclobber; if the marker already exists, another process holds the lock too,
  and that overlap fails the test. At least one acquisition is required. The count is
  reported, not asserted.
- Mutation check: with locking removed (`flock -n 200` → `true`) the new test fails
  with 522 overlapping holders; the old test would have passed (1000 ≥ 10).
- Not reproduced locally: the old test passed on 8 loaded cores and on one loaded core
  (15-21); the CI failures are the RED evidence.

## 🎯 Current Project State

- **Tests**: ✅ T2.4 5/5 runs plus a run on one loaded core; `run_tests.sh` 91 passed / 0 failed
- **Branch**: ✅ clean, pushed; **CI**: 🔄

### Agent Validation Status

- Not run: test-only change of one function; the mutation run is the validation

## 🚀 Next Session Priorities

1. Merge the PR
2. Machine checklist steps 6b (switch country with the kill switch on), 7 (failover), 8
3. Markdown lint cleanup; document `BLOCK_IPV6`, `TAILSCALE_DNS`, `VPN_LIVE_TESTS`
4. Quieten "Kill switch refresh failed" logged on every hook reconnect

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #257 (✅ flock
stress test asserts mutual exclusion instead of a scheduling-dependent count).

**Immediate priority**: machine checklist steps 6b, 7, 8 (`docs/MACHINE-VALIDATION.md`) (1 h)
**Context**: maintenance phase; #248-#250, #254, #257 done
**Reference docs**: SESSION_HANDOVER.md, docs/MACHINE-VALIDATION.md
**Ready state**: clean master, installed; `~/vpn-recover.sh` for emergencies
**Expected scope**: checklist done, then the Markdown lint cleanup

## 📚 Key Reference Documents

- `tests/test_flock_lock_implementation.sh` (`test_t2_4_stress_test`)

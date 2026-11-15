# Session Handoff: #280 reconnect hook logs the refusal only when the VPN is down

**Date**: 2026-11-15
**Issue**: #280 - fix(reconnect): log 'Auto-reconnect blocked' only when the VPN is actually down
**PR**: #281
**Branch**: `fix/issue-280-reconnect-log-noise`

## Why

On 2026-11-15 the VPN was down from 17:17 to 17:49. Kernel log: resume from s2idle at
11:49 and 17:17, each followed within a second by "Dead loop on virtual device tun0"
and "tun0: deleting peer ... reason 2". The NetworkManager hook fired seconds later
and refused to reconnect (kill switch off, by design since #227). `reconnect.log`
showed the same SECURITY refusal for every harmless network event too, so the real
outages could not be told apart. Doctor Hubert chose to stay manual (kill switch off,
sleep hook not installed) and to fix the log noise.

## ✅ Completed Work

- `check_kill_switch`: kill switch off and VPN looks up → INFO "Kill switch not
  enabled; VPN up, no reconnect needed"; VPN looks down → SECURITY refusal as before.
  Return codes unchanged.
- Tests (`tests/unit/test_auto_reconnect.sh`): run the hook's real
  `check_kill_switch` with stubbed kill switch, health check and logger; three cases;
  kill switch on must not call the health check. Both kill-switch-off cases fail
  against the hook on master (mutation check).

## 🎯 Current Project State

**Tests**: `test_auto_reconnect.sh` 27/0; `run_tests.sh` 91/0 with the VPN connected
(OpenVPN PID unchanged afterwards)
**Branch**: clean, pushed

### Agent Validation Status

- security-validator: first 3.5/5 (silently dropping the line on a loose
  `vpn_is_healthy` could hide a leak); changed to INFO instead of dropping;
  re-review 4.5/5, no must-fix. Follow-up for the loose health check: #282.
- code-quality-analyzer: 4.3/5, no must-fix. Taken: explicit guard when the
  function cannot be extracted, health-check call recording, no stray `local`.
  Not taken: test for the missing kill switch binary branch.

## 🚀 Next Session Priorities

The installed hook is copied by hand; after merge (Doctor Hubert):

```bash
sudo install -o root -g root -m 755 etc/NetworkManager/dispatcher.d/50-vpn-reconnect /etc/NetworkManager/dispatcher.d/
```

See `SESSION_HANDOVER.md` for the rest.

# Session Handoff: #295 FR5 (stale state after kill -9), R3 (Tailscale restore) and integration test

**Date**: 2026-11-23 (previous: SESSION-HANDOFF-295-fr2-2026-11-23.md)
**Issue**: #295 (DNS leak while connected) open; #294 open
**PR**: #296 (draft) fix(dns): keep the VPN's DNS in force while connected
**Branch**: `feat/issue-295-dns-leak`
**Installed**: unchanged. Nothing from this branch is installed.

## ✅ Completed Work

Commits `76022df..50f5f25`, all pushed:

- **`76022df` FR5**: `vpn cleanup` (`full_cleanup`) never released network state.
  - After kill -9 the `tun0.protonvpn` entry, the DNS and IPv6 guards and the kill switch stayed, yet `vpn status` said "Fix: vpn cleanup".
  - `clear_stale_vpn_state` moved from `vpn-connector` to `vpn-utils` and now runs at the end of a successful `full_cleanup`.
  - The connector also calls `vpn-manager cleanup` itself: before OpenVPN starts, and after an auth failure. No VPN runs at either point, so the release there is a no-op or what's wanted. Reconnect hooks keep the kill switch through `VPN_KEEP_KILL_SWITCH=1`, which the child call inherits.
- **`d1f0589` R3**: in `restore_tailscale_dns`, when the takeover wait finds no `100.100.100.100` but `resolvconf -l tailscale` is non-empty, it runs one `sudo resolvconf -u` and checks again. Nothing is deleted.
- **`adc1c9e` integration**: connect order (the DNS guard is first in both families after the kill switch) and disconnect teardown.
- **`50f5f25` review fixes**:
  - `clear_stale_vpn_state` also treats an existing `tun0` as a running VPN (security M1: a `/proc` hidepid mount hides a root OpenVPN from `pgrep`). This machine has no hidepid.
  - `vpn cleanup` deletes tun0 before the release, so kill -9 recovery still works.
  - **Leak fixed**: each test run left a fake OpenVPN (`sleep 600` with argv `.../fake/openvpn --config ...`), because `connect` ran in a `$(...)` subshell.
    - Those processes match the real `pgrep -f` pattern, so a real `vpn connect` could have seen a phantom VPN.
    - 8 leaked processes were killed by PID.
    - PIDs now go to a file the EXIT trap reads, the fakes are stopped per test, and they live 120 s at most.
  - New case: the PID file names a hung (fake) OpenVPN. Cleanup verifies it through `ps`, stops it, then releases.
  - The fake sudo refuses `..`. The R3 "no entry" case asserts the anchor call, so it can't pass vacuously.
  - `test_kill_switch_cleanup.sh`'s `ip` stub now reports no tunnel.
- **Tests**:
  - `tests/integration/test_dns_persistence.sh`: 34 checks, registered in `tests/unit_tests.sh` focused_suites. It runs the real `vpn`, `vpn-manager`, `vpn-kill-switch` and the connector success path.
  - The sandbox: `fake-firewall`, a fake openresolv with the signature rule, fake `ip`/`pgrep`/`ps`/`sudo`, and a decoy PID that must survive. Every other tool on PATH is real except a deny list.
  - `test_leak_protection.sh`: 50 checks, R3 cases added.
  - Mutation checks made tests fail: no `dns-guard off` in release; no `pin_output_order` after kill switch enable; no `clear_stale_vpn_state` in `full_cleanup` (the original RED).

### Deviations from the PDR (also in the PR description)

1. **§3.5 "`resolvconf -u` runs"**: the tests check the outcome instead.
   - Removing the entry already rebuilds resolv.conf.
   - Without NetworkManager's entry, `restore_system_dns` copies NetworkManager's file back.
   - A foreign resolv.conf (#295 case) keeps the system's DNS.
2. **§5 registration**: in `unit_tests.sh` focused_suites (like `integration/test_best_fast_connection.sh`), not `integration_tests.sh`.
3. **Extra**: the `tun0` check in `clear_stale_vpn_state`. It fails closed: a leftover persistent tun0 keeps a stale kill switch until `vpn cleanup`.

### Process note

- The commit-msg hook rejects the `Co-Authored-By: Claude` trailer (CLAUDE.md forbids attribution), so commits carry none.

## 🎯 Current Project State

**Tests**: ✅ Full unit suite 76/76 locally (with the VPN connected). test_dns_persistence 34, test_leak_protection 50, test_kill_switch_cleanup 28.
**Branch**: ✅ Clean and pushed (`50f5f25` plus this handoff).
**CI/CD**: 🔄 Running on `50f5f25` at handoff time. `adc1c9e`: everything that finished passed; the test suite was still pending.
**Machine**: VPN connected, resolv.conf on 10.96.0.1, no leaked test processes.

### Agent Validation Status (FR5/R3 code, commits 967beac..adc1c9e)

| Agent | Score | Outcome |
|---|---|---|
| code-quality-analyzer | 4.3 | No blockers. #1 (auth failure now releases the kill switch): no change, since the kill switch is only enabled on success and begin_connect already cleared stale state. #6 (R3 anchor): fixed. #3 (`vpn cleanup` from another terminal mid-connect): not a regression, begin_connect has the same window; left. #2, #4, #5: informational |
| security-validator | 4.0 | M1 hidepid: fixed with the tun0 check. L5 `..` in the fake sudo: fixed. L4 builtin kill: the decoy-survives check is the real proof, comment added. L3 R3 `-u` on a dead tailscaled entry: the warning path remains; accepted |
| test-automation-qa | 3.5 | Leaked fake OpenVPN: fixed. PID-file/ps path not exercised: added the hung-OpenVPN case. R3 vacuous zero count: fixed. Not done: `VPN_KILL_SWITCH=0` connect order (covered by test_dns_guard's every-ordering test), a richer openresolv entry format, and `-d` failing for other reasons |
| architecture-designer | not run | Planned before the PR is marked ready |
| documentation-knowledge-manager | not run | Planned at the docs step (§7) |

## 🚀 Next Session Priorities

1. Confirm CI is green on the latest push.
2. **Docs** (PDR §7):
   - README:
     - the DNS guard and `BLOCK_DNS_LEAKS`
     - `install.sh` options and the drop-in
     - the `40-vpn-dns-repair` hook and `journalctl -t vpn-dns-repair`
     - the `vpn-doctor` `dns` check
     - `vpn cleanup` now restoring DNS after a crash
     - R1, which also covers Tailscale short names
   - Also MACHINE-VALIDATION §10 (live steps 1-6), TROUBLESHOOTING and CHANGELOG.
3. architecture-designer and documentation-knowledge-manager validations, then the live §10 run by hand (install the branch first).
4. Still to ask Doctor Hubert: a follow-up issue for the config-reader consolidation.

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; FR6, FR4, FR3, FR2, FR5 and R3
done on draft PR #296, integration test `tests/integration/test_dns_persistence.sh` in place).
**Immediate priority**: docs per PDR §7 (README, MACHINE-VALIDATION §10, TROUBLESHOOTING, CHANGELOG),
then architecture-designer + documentation-knowledge-manager validation
**Context**: `vpn cleanup` now releases stale DNS/guards/kill switch after kill -9; R3 Tailscale rebuild added;
everything tested on fakes only and nothing from the branch is installed
**Reference docs**: docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md (§5, §7),
docs/implementation/SESSION-HANDOFF-295-fr5-r3-2026-11-23.md
**Ready state**: branch `feat/issue-295-dns-leak` clean and pushed; VPN connected, resolv.conf on VPN DNS
**Expected scope**: docs written and validated, PR #296 ready for the live §10 run

## 📚 Key Reference Documents

- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved)
- `src/vpn-utils` (`clear_stale_vpn_state`, `release_vpn_network_state`, `restore_tailscale_dns`), `src/vpn-manager` (`full_cleanup`)
- `tests/integration/test_dns_persistence.sh`, `tests/unit/test_leak_protection.sh`
- Issue #295, PR #296

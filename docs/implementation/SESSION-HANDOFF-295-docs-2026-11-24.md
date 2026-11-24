# Session Handoff: #295 docs (PDR §7) and the final validations

**Date**: 2026-11-24 (previous: SESSION-HANDOFF-295-fr5-r3-2026-11-23.md)
**Issue**: #295 (DNS leak while connected) open; #294 open
**PR**: #296 (draft) fix(dns): keep the VPN's DNS in force while connected
**Branch**: `feat/issue-295-dns-leak`
**Installed**: unchanged. Nothing from this branch is installed.

## ✅ Completed Work

Docs only, no code changes:

- **`9dc5ebb`**: README, TROUBLESHOOTING and CHANGELOG.
  - **README**:
    - DNS section: the guard, `BLOCK_DNS_LEAKS`, the `ALLOW_LAN_DNS` change (Q1), the NetworkManager drop-in and hook, the status/doctor warnings, and recovery after a crash.
    - New "DNS guard" subsection, covering R1 (LAN-only names, Tailscale short names, hostname `remote`s, DoT/DoH, VMs, the DROP fallback).
    - `install.sh --no-nm-dns` and `--uninstall-nm-dns`.
    - The `40-vpn-dns-repair` hook under hooks, and the `etc/` file list.
    - Two troubleshooting entries.
  - **TROUBLESHOOTING**: Scenario 4 (a leftover guard after a crash, with the manual 3-line removal for `~/vpn-recover.sh`, PDR deviation 4) and Scenario 5 (DNS leaving the VPN, the drop-in undo), plus diagnostics.
  - **CHANGELOG**: Security, Added and Fixed entries under Unreleased.
- **`4c3606e`, `0dc00ff`** and the commit with this handoff: MACHINE-VALIDATION.
  - New §10: a script for steps 1-4 that restores everything on exit, Ctrl-C, SIGHUP or a 240 s watchdog. It runs in about 30 s. By hand: step 5 (disconnect), step 6 (kill -9) and step 7 (the hook removes a leftover guard, and keeps it with the kill switch on).
  - Also updated: §1 install checks, the §9 note, "If something fails", and Escape hatches.
  - The script passes `bash -n` and `shellcheck -S warning`. **It has never been run.**

### Environment findings (affect the live run)

1. **Reboot before §10.**
   - The running kernel is 7.2.15, but only 7.3.5's modules are on disk.
   - IPv4 `REJECT` isn't loaded (`ip6t_REJECT` is), so the guard would fall back to DROP and step 1's "fails fast" check would fail.
   - The mangle-table counters might not load either. The script aborts if they don't.
2. **No syslog daemon on this machine** (`/dev/log` doesn't exist; runit, svlogd only for some services).
   - Every `logger` message from `vpn-dns-repair` and `vpn-dns-update` is lost.
   - The docs say so, and §10 checks outcomes, not logs.

## 🎯 Current Project State

**Tests**: ✅ No code changed this session; 76/76 at the last handoff.
**Branch**: ✅ Clean and pushed.
**CI/CD**: ✅ Green on `2ae49bf` at session start. Doc commits since then are pushed; check CI again.

### Agent Validation Status (this session)

| Agent | Score | Outcome |
|---|---|---|
| architecture-designer | 4.2 | **No blockers.** Implementation matches the PDR (ordering, separate no-user-context hook, teardown paths, Q4 fail-closed checks). The connect-to-guard window it called undocumented is in PDR §3.1 (accepted ~1 s). Recommendations below |
| documentation-knowledge-manager | 4.2 → **4.6** | **First pass**: §7 complete and every quoted string correct. Blocker: step 7 ran `vpn-kill-switch enable` with no VPN, which is refused without `--force`, so the fail-closed case was never set up. Also hardened the restore path: traps, sudo, warnings, a leftover moved-aside drop-in, and a `dig` check. **Re-score**: no blockers. Its point that the watchdog was too short was declined, since the run takes about 30 s and sudo's timestamp lasts 5 min |
| security-validator, code-quality-analyzer, test-automation-qa | not re-run | No code changed. Last results in SESSION-HANDOFF-295-fr5-r3-2026-11-23.md |

### Architecture recommendations, not done (waiting on Doctor Hubert)

- **Hook log fallback.** Without syslog the hook has no observability. Suggestion: when `logger` fails, append to a capped, root-private `/run/protonvpn-manager/dns-repair.log`, and have status/doctor show the last line. This changes PDR deviation 3, so it needs Doctor Hubert's call: this PR or a follow-up. Recommendation: follow-up.
- **Cosmetic false WARN.** `remove_leftover_dns_guard` racing a disconnect can log "could not remove". Re-check the chain before warning.
- **Hidepid parity.** The hook could treat an existing tun0 like `clear_stale_vpn_state` does. Root sees all processes, so this is theoretical.

### Follow-up issue candidates (ask Doctor Hubert)

1. Consolidate the config readers (`vpn_config_value`, `config_value`, `connector_config_value`).
2. Remove the development-mode `source` fallback in `50-vpn-reconnect` (lines 16-19). It runs as root and predates this branch.
3. The hook log fallback (above).
4. A WireGuard exemption in the DNS guard (#223).
5. A connect-order test with `VPN_KILL_SWITCH=0`.

## 🚀 Next Session Priorities

1. Doctor Hubert decides on the hook log fallback and on which follow-up issues to open.
2. Reboot, install the branch (`./install.sh`), then run `docs/MACHINE-VALIDATION.md` §10 by hand.
   - Doctor Hubert runs it; Claude must not run it from a session.
   - Steps 6 and 7 take the VPN down, and step 7 briefly blocks all traffic.
3. Fix anything §10 finds (TDD), then mark PR #296 ready.
4. By hand: add the 3 guard-removal lines per family to `~/vpn-recover.sh` (TROUBLESHOOTING Scenario 4).

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; all FRs, R3 and docs done on draft
PR #296; architecture 4.2 and documentation 4.6 validated, no blockers).
**Immediate priority**: the live run of docs/MACHINE-VALIDATION.md §10 (reboot first: kernel modules missing,
so REJECT isn't loaded), then fix whatever it finds and mark PR #296 ready
**Context**: §10's script (steps 1-4) restores everything on exit but has never run; no syslog on this machine,
so hook logs are lost; open decisions: hook log fallback (this PR or follow-up) and 5 follow-up issues
**Reference docs**: docs/implementation/SESSION-HANDOFF-295-docs-2026-11-24.md, docs/MACHINE-VALIDATION.md §10,
docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md (§5)
**Ready state**: branch `feat/issue-295-dns-leak` clean and pushed; nothing from the branch installed
**Expected scope**: §10 passed (or its failures fixed with tests), follow-ups filed, PR #296 ready for review

## 📚 Key Reference Documents

- `docs/MACHINE-VALIDATION.md` §10
- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved; §5 live steps, §8 deviations)
- `docs/TROUBLESHOOTING-KILL-SWITCH.md` Scenarios 4-5
- Issue #295, PR #296

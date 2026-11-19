# Session Handoff: #295 FR4 (status/doctor DNS state) and FR3 (40-vpn-dns-repair hook)

**Date**: 2026-11-19 (previous: SESSION-HANDOFF-295-dns-guard-2026-11-19.md, same day)
**Issue**: #295 (DNS leak while connected) open; #294 open
**PR**: #296 (draft) fix(dns): keep the VPN's DNS in force while connected
**Branch**: `feat/issue-295-dns-leak`
**Installed**: unchanged (nothing from this branch is installed; `src/` and the hook are not live)

## ✅ Completed Work

Commits `a6b5844..db46706`:

- **`a6b5844` fix(kill-switch)**: `dns-guard status` reads OUTPUT through `read_output_chain` with
  `sudo -n`. It never prompts, and without credentials it is `unknown` (exit 2), never `off`.
- **`c84465d` FR4**, in `src/vpn-utils`:
  - `vpn_config_value`: same contract as the kill switch's and connector's readers.
  - `nameserver_set` / `same_nameservers`: bash builtins only, lowercased, compared as sets.
  - `vpn_dns_mismatch`: returns 0 on a mismatch and prints `expected:` / `actual:`. Skipped
    without openresolv, without the `tun0.protonvpn` entry, or with `TAILSCALE_DNS=keep`.
  - `vpn_dns_state <yes|no>`: reads the guard once and sets `VPN_DNS_GUARD` and
    `VPN_DNS_WARNINGS`. Only `0:on`, `1:off` and `2:on (…)` are accepted; anything else is
    `unknown`. Warnings:
    - mismatch, only while connected
    - guard off while connected, unless `BLOCK_DNS_LEAKS=false`
    - guard incomplete (not first, or one family only)
    - leftover guard with no VPN: "Fix: vpn cleanup"
  - Callers: `vpn-manager` `show_dns_state` (plain and accessible) and `vpn-doctor` `check_dns`
    (6th check, `--check=dns`).
- **`7b0f9dc` refactor**: `vpn_is_healthy` moved unchanged into `vpn-utils`.
  - **Deviation from PDR §3.3**: its constants do *not* move as defaults. Sourcing sets none of
    them, so vpn-manager's env-overridable `VPN_PID_FILE` is not clobbered. Each hook sets
    them after sourcing.
- **`f9da4d1` FR3**: `etc/NetworkManager/dispatcher.d/40-vpn-dns-repair`, as PDR §3.3.
  - Repair steps: symlink check → entry → `vpn_is_healthy` → lock dir → `flock` →
    rate limit (3 in 10 s) → `resolvconf -u 9>&-`.
  - Q4 (`remove_leftover_dns_guard`), when there is no entry. It removes the guard only when
    all of these hold:
    - `pgrep -x openvpn` exits exactly 1 (any openvpn at all keeps it)
    - both `iptables -S` reads succeed
    - no `VPN_KILL_SWITCH(_V6)` jump exists
  - Removal uses iptables directly, not `vpn-kill-switch`, which would load user context as
    root.
- **`db46706` review fixes**:
  - `vpn-utils` is sourced only when it and `/usr/local/bin` are root-owned and not writable
    by group or others (`root_owned_safe`).
  - `RUN_DIR` is refused when writable by group or others.
  - A failed `exec 9>` no longer ends the hook with an error.
  - IPv6 nameservers compare case-insensitively.
  - `tests/fakes/fake-firewall` gained `fail_D_<fam>`.
- **Tests** (all registered in `tests/unit_tests.sh`):
  - `test_dns_mismatch.sh` 40
  - `test_dns_repair_hook.sh` 68
  - `test_dns_guard.sh` 68
  - `test_vpn_doctor.sh` 31
  - `test_auto_reconnect.sh` 41
  - Mutation checks: dropping `9>&-` or the IPv6 kill-switch condition each makes a test fail.
- **Live, read-only check**: `src/vpn-manager status` on the connected machine shows
  `DNS guard: off` plus the warning. That is correct: the installed connector predates the
  guard. No mismatch is shown, because resolv.conf is on the VPN's DNS.

## 🎯 Current Project State

- **Tests**: the full unit suite passed 74/74 locally (before `db46706`). After `db46706` these
  suites pass: dns_repair_hook, dns_guard, dns_mismatch, vpn_doctor, auto_reconnect,
  suite_safety 97, kill_switch_cleanup, leak_protection.
- **CI**: green on `20fd4d7`. The run on `db46706` was pending at handoff.
- **Branch**: clean and pushed. The PR #296 description is updated.
- **Machine**: VPN connected. resolv.conf on the VPN's DNS.

### Agent Validation Status (FR4/FR3 code)

| Agent | Score | Outcome |
|---|---|---|
| security-validator | 4.5 | Fixed: RUN_DIR mode (M1), root-owned check before sourcing vpn-utils (M2), `exec` failure (L3), comment for resolvconf failure = no entry (L6). Declined: retry or ERROR level for a rate-limited event (L4: the PDR says WARN; the guard fails closed). L5 (`pgrep -x openvpn` must widen when #223 adds WireGuard) is noted for #223 |
| code-quality-analyzer | 4.2 | Fixed: `exec` failure (#1), `set` renamed and lowercase (#4), dead `rc=2` (#5), `-s` in the corrupt-times test (#10). Deferred: **config-reader consolidation (#2)** to a follow-up issue (four readers; vpn-manager's differs: no symlink guard, first-wins), with a pointer comment added. Declined: dropping `export -f` (consistent with the file), a guard for empty arrays (bash ≥5 here), a debug log when an openvpn keeps the guard (noise on every dns-change) |
| test-automation-qa | 4.0 | Added: a byte-identical times file after a limited run, a held lock recording nothing and a repair after release, static checks that the constants come after `source`, a visible root skip, mkdir failure, group-writable RUN_DIR, a lock file that is a directory, leftover chain without a jump, no ip6tables, `-D` failure leaving the chain whole, guard intact after an unreadable status |

Not yet run: architecture-designer and documentation-knowledge-manager (planned at FR2 and docs).

## 🚀 Next Session Priorities

1. Check that CI is green on `db46706`.
2. **FR2** (PDR §3.4):
   - `etc/NetworkManager/conf.d/protonvpn-manager-dns.conf` and `install_nm_dns` in
     `install.sh`, with every skip condition, atomic write, reload, and rollback when the
     reload fails.
   - Hook install (Q3): `install -o root -g root -m 755 40-vpn-dns-repair`.
   - `--uninstall-nm-dns` / `--no-nm-dns`.
   - Tests in `tests/unit/test_install_nm_dns.sh`.
3. FR5 kill -9 tests, R3 Tailscale restore, the integration test
   `tests/integration/test_dns_persistence.sh`, then docs (§7). The docs need the `vpn-doctor`
   `dns` check and `journalctl -t vpn-dns-repair`.
4. Open a follow-up issue for the config-reader consolidation (ask Doctor Hubert first).

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; FR6 guard, FR4
status/doctor DNS state and FR3 `40-vpn-dns-repair` hook done on draft PR #296).
**Immediate priority**: confirm CI green on `db46706`, then FR2 (NetworkManager drop-in
`rc-manager=resolvconf`, `install.sh` install_nm_dns + hook install + `--uninstall-nm-dns`/
`--no-nm-dns`, tests in `tests/unit/test_install_nm_dns.sh`)
**Context**: the hook and status are tested on fakes only; nothing from the branch is installed
**Reference docs**: docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md (§3.4, §5),
docs/implementation/SESSION-HANDOFF-295-fr4-fr3-2026-11-19.md
**Ready state**: branch `feat/issue-295-dns-leak` clean and pushed; VPN connected, resolv.conf
on VPN DNS
**Expected scope**: FR2 implemented TDD with tests registered, PR #296 updated

## 📚 Key Reference Documents

- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved)
- `etc/NetworkManager/dispatcher.d/40-vpn-dns-repair`, `src/vpn-utils`
- `tests/unit/test_dns_repair_hook.sh`, `tests/unit/test_dns_mismatch.sh`, `tests/fakes/fake-firewall`
- Issue #295, PR #296

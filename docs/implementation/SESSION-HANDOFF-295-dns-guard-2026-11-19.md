# Session Handoff: #295 PDR approved, guard refactor + FR6 DNS guard implemented

**Date**: 2026-11-19 (previous: #295 PDR v0.2, 2026-11-17)
**Issue**: #295 (DNS leak while connected) open; #294 open
**PR**: #296 (draft) fix(dns): keep the VPN's DNS in force while connected
**Branch**: `feat/issue-295-dns-leak`
**Installed**: unchanged (nothing from this branch is installed; `src/` changes are not live)

## ✅ Completed Work

- **PDR approved** (2026-11-19). Doctor Hubert took every recommendation (PDR §10, §12):
  - Q1: the guard wins over `KILL_SWITCH_ALLOW_LAN_DNS`; the connector prints a note.
  - Q2: `install.sh --uninstall-nm-dns` / `--no-nm-dns`.
  - Q3: `install.sh` installs `40-vpn-dns-repair` in this issue.
  - Q4: the hook removes a leftover guard on `dns-change` only when no openvpn of ours runs,
    there's no `tun0.protonvpn` entry, and the kill switch is **off**.
- **Step 1, refactor** (`2bc7970`): `guard_chain_on` / `guard_chain_off` in
  `src/vpn-kill-switch`. The IPv6 guard uses them, with no behaviour change.
- **FR6, DNS guard** (`79f77fc`, `c672e07`, hardened in `20fd4d7`):
  - `vpn-kill-switch dns-guard on|off|status`. `VPN_DNS_GUARD` in v4 and v6: RETURN for
    lo / tun+ / tailscale0, udp and tcp 53 REJECT, DROP fallback.
  - `pin_output_order` keeps it first in OUTPUT: re-pinned after each kill-switch family
    loads, after `ipv6-guard on` and after `dns-guard on`. It also collapses duplicate jumps.
  - `status` output and exit codes:
    - `on` exits 0.
    - `off` exits 1.
    - `on (not first in OUTPUT)`, `on (IPv4 only)` and `unknown` (firewall unreadable) all
      exit 2.
  - `emergency` removes the guard. `disable` leaves it (it belongs to the connection).
  - `apply_leak_protection` order: IPv6 guard, Tailscale pause, DNS guard. Opt out with
    `BLOCK_DNS_LEAKS=false`.
  - `release_vpn_network_state` removes the guard right after `clear_vpn_dns`, before
    system and Tailscale DNS are restored. It does this also with `VPN_KEEP_KILL_SWITCH=1`.
  - Without ip6tables, `dns-guard on` warns and returns 0, and `status` requires IPv4 only.
    (The PDR left the exit code open.)
- **Tests**:
  - `tests/fakes/fake-firewall`: a stateful iptables/ip6tables/-restore fake. Restores are
    all or nothing.
    - Failure injections, as files in `FAKE_FW_DIR`: `no_reject`, `no_restore_<fam>`,
      `restore_fails_on`, `fail_S_<fam>`, `fail_X_<fam>`.
    - It rejects a reject-with of the wrong family.
    - It has no `.sh` suffix on purpose: the suite-safety orphan scan only checks `*.sh`.
  - `tests/unit/test_dns_guard.sh`: 65 cases, registered in `tests/unit_tests.sh`. It runs in a
    sandbox PATH made of the fakes plus `/usr/bin` minus the firewall, sudo, ip, resolvconf,
    nmcli and tailscale tools.
  - `tests/unit/test_leak_protection.sh`: 45 cases (7 new).

## 🎯 Current Project State

- **Tests**:
  - Full unit suite 72/72 locally (before `20fd4d7`).
  - After `20fd4d7`, these related suites pass: dns_guard 65, leak_protection 45,
    kill_switch_cleanup 28, suite_safety 97, errexit 23, hardening 77, kill_switch.
- **CI**: all green on `c672e07`. The run on `20fd4d7` was pending at handoff.
- **Branch**: clean, pushed.
- **Machine**: VPN connected. resolv.conf on `10.96.0.1` (VPN DNS).

### Agent Validation Status (FR6 code)

| Agent | Score | Outcome |
|---|---|---|
| security-validator | 4.0 | Fixed: pin skipped on a partial kill-switch load (M1), pin result unchecked (M2), flushing a chain whose jump remains. Declined: strict fail-closed mode (M3, scope change; the PDR says warn), keeping the guard during `VPN_KEEP_KILL_SWITCH=1` reconnect (L1, PDR + Q1), teardown warning (L2, fails closed; FR4 reports it). The `tun+` blanket exemption and DoT/853 go in the docs step (L3) |
| code-quality-analyzer | 3.8 | Fixed: pin failure aborting `enable` under set -e (#1), v6 not removed when v4 `-X` fails (#2), status "off" on an unreadable firewall → `unknown` (#3), on/status disagreeing without ip6tables (#4), fake fidelity and test gaps (#6, #7). Declined #5 (DROP fallback only on REJECT-specific errors): nft and legacy backends word the error differently, and a narrow match risks losing the #291 fallback |

Not yet run on the code: test-automation-qa, architecture-designer,
documentation-knowledge-manager (planned at FR3/FR2 and docs).

## 🚀 Next Session Priorities

1. Check that CI is green on `20fd4d7`.
2. **FR4**: `vpn_dns_mismatch` in `vpn-utils`, and status/doctor lines for guard state,
   including "leftover guard". Tests go in `tests/unit/test_dns_mismatch.sh` (PDR §3.2, §5).
   Use the new `dns-guard status` exit codes (`unknown` is never "off").
3. **FR3**: the `40-vpn-dns-repair` hook (with Q4's leftover removal) and the move of
   `vpn_is_healthy` to `vpn-utils`. Tests: `tests/unit/test_dns_repair_hook.sh`.
4. Then FR2 (drop-in + installer flags + hook install), FR5 tests, R3, docs (§7).

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; PDR approved, guard
refactor + FR6 DNS guard done on draft PR #296).
**Immediate priority**: confirm CI green on `20fd4d7`, then FR4 (`vpn_dns_mismatch` + status/
doctor guard state), then FR3 (`40-vpn-dns-repair` hook with Q4 leftover-guard removal)
**Context**: `vpn-kill-switch dns-guard on|off|status` works on a stateful iptables fake
(`tests/fakes/fake-firewall`); status exit 0 on / 1 off / 2 not-first, partial or unknown
**Reference docs**: docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md (§3.2, §3.3, §5),
docs/implementation/SESSION-HANDOFF-295-dns-guard-2026-11-19.md
**Ready state**: branch `feat/issue-295-dns-leak` clean and pushed; VPN connected, resolv.conf
on VPN DNS; nothing from the branch installed
**Expected scope**: FR4 and FR3 implemented TDD with tests registered, PR #296 updated

## 📚 Key Reference Documents

- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved)
- `docs/implementation/PRD-VPN-DNS-PERSISTENCE-2026-11-17.md`
- `tests/unit/test_dns_guard.sh`, `tests/fakes/fake-firewall`
- Issue #295, PR #296

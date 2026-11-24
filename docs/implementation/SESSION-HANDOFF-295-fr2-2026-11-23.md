# Session Handoff: #295 FR2 (NetworkManager drop-in and installer)

**Date**: 2026-11-23 (previous: SESSION-HANDOFF-295-fr4-fr3-2026-11-19.md)
**Issue**: #295 (DNS leak while connected) open; #294 open
**PR**: #296 (draft) fix(dns): keep the VPN's DNS in force while connected
**Branch**: `feat/issue-295-dns-leak`
**Installed**: unchanged. Nothing from this branch is installed; the drop-in and the hook are not live.

## ✅ Completed Work

Commits `2261f00..67be7fd`, all pushed:

- **`2261f00` fix(lint)**: CI ShellCheck failed on `2221a8c` (SC2034).
  - CI runs `-S warning` without the `-e SC2034` the pre-commit hook passes, so these warnings only show in CI.
  - The `VPN_*` paths in both dispatcher hooks and the test stub variables got annotated `disable=SC2034`. They are read by sourced code.
  - The assignments stay at column 0: `test_auto_reconnect.sh` and `test_dns_repair_hook.sh` grep for `^VPN_...=`.
  - Check locally with CI's settings: `~/.cache/pre-commit/repo*/py_env-python3/bin/shellcheck -S warning`.
- **`8b0990b` FR2**:
  - New drop-in `etc/NetworkManager/conf.d/protonvpn-manager-dns.conf` (`[main]` / `rc-manager=resolvconf`).
  - New functions in `install.sh`: `nm_dns_skip_reason`, `install_nm_dns` (after `install_dns_helper`), `uninstall_nm_dns`, `usage`.
  - New options: `--uninstall-nm-dns` (only the undo) and `--no-nm-dns` (everything else plus the undo).
- **`5c916c4` review hardening**, from the security, code-quality and test agents:
  - Failures and writes:
    - A failed write warns and leaves NetworkManager as it was. This covers the hook, a directory, the drop-in backup, the temp file and the rename.
    - The hook is written atomically like the drop-in: a dot-named temp file, then `mv -T`.
    - A failed reload restores an older drop-in of ours from `.protonvpn-manager-dns.conf.previous`.
  - New skips: a symlinked `dispatcher.d`, and an `rc-manager` in `/usr/lib/NetworkManager/conf.d` or `/run/NetworkManager/conf.d` (`NM_OTHER_CONF_DIRS`).
  - Undo:
    - It does nothing unless our drop-in or hook exists, so a user's own `rc-manager=resolvconf` is left alone.
    - It touches resolvconf only after `reload conf` succeeds.
    - It reads the VPN entry with `sudo` (`vpn_dns_registered`, `VPN_DNS_ENTRY`).
    - If tun0 is up but the entry can't be read, it leaves DNS alone and prints a warning.
- **`67be7fd`**: also skip when `dns=none` is set (Doctor Hubert approved 2026-11-23).
- **Tests**:
  - `tests/unit/test_install_nm_dns.sh`: 124 checks, registered in `tests/unit_tests.sh`.
  - Runs under `set -e`, using fake `sudo`/`install`/`mv`/`nmcli`/`resolvconf`/`pgrep`/`ip` with injectable failures. The sandbox has an allowlist of system tools.
  - Mutation checks, each made tests fail: no rollback; `-u` while disconnected; no idempotency `cmp`; own drop-in counted as foreign; no "nothing installed" check; no backup restore.

### Deviations from PDR §3.4 (also in the PR description)

1. **Undo while disconnected**: it skips `resolvconf -u`. It runs `-f -d NetworkManager`, then `nmcli general reload dns-full`.
   - Reason: with no openresolv entries, `-u` leaves resolv.conf without a nameserver.
   - `-d` must come before `dns-full`: deleting an openresolv entry regenerates resolv.conf and would overwrite NetworkManager's file. (The security review suggested the reverse order; this is why it was declined.)
2. **More skip conditions**: an unreadable NetworkManager config file, a symlinked dispatcher.d, `rc-manager` in `/usr/lib` or `/run`, and `dns=none`.
3. **The undo is gated**: it only runs when our files are installed, and only after NetworkManager reloads.

### Machine findings (2026-11-23)

- **Tailscale "failed to fetch the DNS configuration: exit status 2"**:
  - tailscaled's openresolv probe (`resolvconf -i` / `-l`) exits 2 when nothing is registered.
  - Without the drop-in, that is the state whenever the VPN is down or reconnecting: NetworkManager isn't registered with openresolv.
  - The warning is cosmetic here (accept-dns=false) and stays until tailscaled re-applies DNS. `sudo sv restart tailscaled` cleared it.
  - FR2 fixes it for good, because NetworkManager's entry is then always present.
- **Bare tailnet names (`ssh raspi`) don't resolve while connected**: Tailscale DNS is off, and resolv.conf is the VPN's DNS alone. `raspi.tail81c84e.ts.net` resolves (public ts.net). Doctor Hubert deferred `/etc/hosts` entries.
- **Expected DNS behaviour to document**: R1 "LAN-only names stop resolving" covers this, Tailscale short names included.

## 🎯 Current Project State

**Tests**: ✅ The full unit suite passes locally (75/75). test_install_nm_dns 124, suite_safety 97.
**Branch**: ✅ Clean and pushed (`67be7fd`).
**CI/CD**: ✅ All checks pass on `67be7fd`, including ShellCheck.
**Machine**: VPN connected, resolv.conf on the VPN's DNS (10.96.0.1). Tailscale has no health warnings.

### Agent Validation Status (FR2 code)

| Agent | Score | Outcome |
|---|---|---|
| security-validator | 3.5 | Fixed: set -e partial state (M1); rollback lost an older drop-in (M2); the undo now runs only after reload, gated on our files, with the recovery command on failure (M3, order kept, see Deviations); the `/usr/lib` and `/run` conf.d scan plus `dns=none` (M4); a symlinked dispatcher.d and an atomic hook write (L5); the VPN entry read with sudo plus the tun0 check (L7). Declined: content-checking before `rm` on uninstall (L6: only root can plant files in root-owned dirs); a second reload after rollback; `NetworkManager --print-config` (not needed with the dir scan) |
| code-quality-analyzer | 3.8 | Fixed: unguarded installs (#1); unconditional undo (#2); closing line for `--uninstall-nm-dns` (#3); backup restore (#4); usage to stderr (#5); more conf dirs (#6); `VPN_DNS_ENTRY` constant (#8). Skipped: `have_nmcli` local (#7, the code changed so it no longer applies) |
| test-automation-qa | 3.5 | Fixed: the harness now really runs under set -e, with exact rc; the vacuous `command -v a b c` check; an allowlist sandbox; anchored skip reasons; idempotency asserts no install/mv; uninstall order includes `rm`. Added: the missing cases (hook reinstalled, missing dispatcher.d, older drop-in restored, hook state on reload failure, no nmcli, dns-full failure, `--help`, two options, mv and install failures) |
| architecture-designer | not run | Planned before the PR is marked ready |
| documentation-knowledge-manager | not run | Planned at the docs step (§7) |

## 🚀 Next Session Priorities

1. **FR5** (PDR §3.5): kill -9 path tests for `clear_vpn_dns` / `release_vpn_network_state` / `vpn cleanup`. Fix whatever they show.
2. **R3** (PDR §3.6): in `restore_tailscale_dns`, when the takeover finds no `100.100.100.100` but `resolvconf -l tailscale` is non-empty, run one `sudo resolvconf -u` and re-check. Test it in `test_leak_protection.sh`.
3. **Integration**: `tests/integration/test_dns_persistence.sh` (PDR §5), registered in `tests/integration_tests.sh`.
4. **Docs** (PDR §7):
   - README:
     - the DNS guard and `BLOCK_DNS_LEAKS`
     - `install.sh` options and the drop-in
     - the `40-vpn-dns-repair` hook and `journalctl -t vpn-dns-repair`
     - the `vpn-doctor` `dns` check
     - R1, which also covers Tailscale short names
   - Also MACHINE-VALIDATION §10, TROUBLESHOOTING and CHANGELOG.
5. Then the architecture-designer and documentation-knowledge-manager validations, and the live §10 run by hand.
6. Still to ask Doctor Hubert: a follow-up issue for the config-reader consolidation.

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; FR6 guard, FR4 status/doctor,
FR3 `40-vpn-dns-repair` hook and FR2 NetworkManager drop-in + `install.sh` options done on draft PR #296).
**Immediate priority**: FR5 kill -9 stale-entry tests (PDR §3.5), then R3 Tailscale restore (§3.6) and
the integration test `tests/integration/test_dns_persistence.sh`
**Context**: CI green on `67be7fd`; everything is tested on fakes only and nothing from the branch is installed
**Reference docs**: docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md (§3.5, §3.6, §5),
docs/implementation/SESSION-HANDOFF-295-fr2-2026-11-23.md
**Ready state**: branch `feat/issue-295-dns-leak` clean and pushed; VPN connected, resolv.conf on VPN DNS
**Expected scope**: FR5 and R3 implemented TDD with tests registered, PR #296 updated

## 📚 Key Reference Documents

- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved)
- `install.sh`, `etc/NetworkManager/conf.d/protonvpn-manager-dns.conf`, `etc/NetworkManager/dispatcher.d/40-vpn-dns-repair`
- `tests/unit/test_install_nm_dns.sh`, `src/vpn-utils` (`clear_vpn_dns`, `restore_system_dns`, `restore_tailscale_dns`)
- Issue #295, PR #296

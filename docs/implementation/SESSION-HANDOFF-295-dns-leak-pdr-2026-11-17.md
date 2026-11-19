# Session Handoff: #295 S1 spike complete, PDR v0.2 agent-reviewed

**Date**: 2026-11-17 (previous: #295 PRD, same day)
**Issues**: #295 open (PRD approved, PDR awaiting approval); #294 open (fix direction decided)
**Branch**: `feat/issue-295-dns-leak` (docs only: PRD, PDR, handoffs; no code yet)
**Installed**: unchanged (`vpn-kill-switch` at `5938332`, dispatcher hook at `46fd0e8`, rest of `src/` at `41aad5b`)

## ✅ Completed Work

- **S1 spike, Tailscale part** (two live runs, auto-teardown). Results are in PRD §3; S1 is
  marked done:
  - With the drop-in, a restarted tailscaled uses **openresolv mode**: an exclusive `tailscale`
    entry, no `/etc/resolv.pre-tailscale-backup.conf`. Its entry added later wins over the
    VPN's, so the Tailscale pause stays needed.
  - Real disconnect/connect with the drop-in on:
    - MagicDNS short names resolve after disconnect.
    - Connect re-pauses Tailscale and records `mode=resolvconf`.
  - Wifi re-activation (`nmcli connection up`) and `reload dns-full` with the VPN up:
    resolv.conf stayed on the VPN's DNS, and **0 port-53 packets** left wlan0 (v4/v6).
  - **Side effect**: after the wifi re-activation the tunnel stopped passing traffic (tun0 UP,
    lookups timed out). Doctor Hubert had to run `vpn reconnect`. This looks like #294 (server
    host route lost). The spike script had no connectivity check. All later live runs need
    one, with a stop on failure.
  - Open: the 19:52 reconnect (after teardown) recorded `mode=direct` again. Cause unknown; the
    PDR's R3 fix makes restore work for either record.
- **PDR** `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md`:
  - v0.1 was reviewed by the 6 core agents. **v0.2** folds in their points (PDR §11).
  - Main changes from the review:
    - FR3 becomes a **separate hook** `40-vpn-dns-repair` (no user context);
      `50-vpn-reconnect` is untouched apart from `vpn_is_healthy` moving to `vpn-utils`.
    - A `pin_output_order` helper keeps `VPN_DNS_GUARD` first in OUTPUT.
    - Shared guard helpers, done as a refactor step first.
    - Stateful iptables fake + fake sudo in tests; unit tests registered in `tests/unit_tests.sh`.
    - Installer hardening; doc-impact and traceability sections.
  - Two security findings were checked and rejected with evidence:
    - `resolvconf -u` *does* rewrite NetworkManager's file (S1, #295).
    - All profiles use IP `remote`s (0 hostnames).

## 🎯 Current Project State

- **Tests**: not run (no code changes); last full suite 126/0 on #282's branch.
- **Machine**:
  - VPN connected (after Doctor Hubert's reconnect); resolv.conf `nameserver 10.96.0.1`.
  - NetworkManager back on default `rc-manager=symlink`; no spike files in conf.d; counter rules removed.
  - tailscaled was restarted by the spike and runs in openresolv mode until its next restart.
  - The pause record `~/.local/state/vpn/tailscale-dns-paused` says `mode=direct`, written at
    19:52. Disconnect restores Tailscale DNS. If MagicDNS fails after disconnect, run
    `sudo resolvconf -u` (this is R3).
- **Caution**: until #295 ships, any NetworkManager DNS update can leak DNS again. Check
  `head -2 /etc/resolv.conf` and fix with `sudo resolvconf -u`.

### Agent Validation Status (PDR v0.1)

| Agent | Score |
|---|---|
| architecture-designer | 4.0 |
| security-validator | 3.8 |
| performance-optimizer | 4.0 |
| test-automation-qa | 3.0 |
| code-quality-analyzer | 3.5 |
| documentation-knowledge-manager | 4.0 |

All points are folded into v0.2 or rejected with reasons (PDR §11). v0.2 hasn't been
re-reviewed.

## 🚀 Next Session Priorities

1. **Doctor Hubert decides Q1-Q4** (PDR §10):
   - Q1: guard wins over `ALLOW_LAN_DNS`.
   - Q2: `install.sh --uninstall-nm-dns`.
   - Q3: install the `40-vpn-dns-repair` hook in this issue.
   - Q4: auto-remove a leftover guard when no VPN runs and the kill switch is off. This
     changes the PRD's "fails closed". Without it, DNS stays dead after every suspend until
     `vpn cleanup`.
2. After approval: TDD in PDR §1 order (guard refactor → FR6 → FR4 → FR3 → FR2 → FR5 → R3 → docs), draft PR early.
3. Then the #294 PRD (host route), #277, #223 WireGuard.

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue #295 (DNS leak; S1 spike done,
PDR v0.2 agent-reviewed, waiting on Doctor Hubert's Q1-Q4 and approval).

**Immediate priority**: get Q1-Q4 answered and the PDR approved, then start TDD with step 1
(shared guard helpers in `vpn-kill-switch`, IPv6 guard tests green), then FR6 (DNS guard)
**Context**: FR3 is now a separate hook `40-vpn-dns-repair`; the guard is pinned first in OUTPUT;
tests use a stateful iptables fake + fake sudo, never the live firewall
**Reference docs**: docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md, PRD of the same
name (S1 results), SESSION_HANDOVER.md
**Ready state**: branch `feat/issue-295-dns-leak` (docs only, clean); VPN connected,
resolv.conf on VPN DNS (re-check; `sudo resolvconf -u` if not)
**Expected scope**: PDR approved, guard refactor + FR6 implemented with tests, draft PR open

## 📚 Key Reference Documents

- `docs/implementation/PDR-VPN-DNS-PERSISTENCE-2026-11-17.md` (v0.2)
- `docs/implementation/PRD-VPN-DNS-PERSISTENCE-2026-11-17.md` (S1 results in §3)
- `docs/implementation/SESSION-HANDOFF-295-dns-leak-pdr-2026-11-17.md`
- Issue #295, issue #294

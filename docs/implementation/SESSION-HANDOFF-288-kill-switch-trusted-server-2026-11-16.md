# Session Handoff: #288 kill switch allows the VPN server from trusted sources only

**Date**: 2026-11-16
**Issue**: #288 - fix(kill-switch): choose the allowed VPN server IP from trusted sources only
**PR**: #290 - fix(kill-switch): allow the VPN server only from trusted sources (draft)
**Branch**: `fix/issue-288-kill-switch-trusted-server-ip`
**Also this session**: PR #289 (#287) squash-merged as `73124a8` (tests only, nothing to install)

## ✅ Completed Work

- **Design decision (Doctor Hubert, 2026-11-16)**: the issue proposed trusting the user's
  `kill_switch.state` when it is private. security-validator rejected that, because any of
  the user's processes could still rewrite it, and projected 3.5–4 for that design.
  Doctor Hubert chose a **root-written record** at
  `/run/protonvpn-manager-session/kill_switch.server` instead. The user state file is now
  informational only.
- **`src/vpn-kill-switch`**: `get_vpn_server_ip` is replaced by `get_vpn_server_allow`,
  which emits `<ip> <proto> <ports>` lines (or `<ip> any -` for an IP given on the
  command line that the profile does not list). Sources, in order:
  1. The session log's server, accepted only if the root-owned profile lists it. A
     mismatch allows **nothing** and prints a warning.
  2. A host route via the default interface, only while tun0 is really up (checked by
     `tunnel_is_up`, which the refresh/`--force` override cannot fake) and only if the
     profile lists it.
  3. The root record. It outlives disconnect, which removes only profile and
     credentials, and is removed by `disable` or a reboot.

  Other changes in the script:
  - **Trust checks** (`is_root_private`): not a symlink, uid 0, no group or world write
    bit, applied to both the directory and the file. As root, `VPN_SESSION_DIR` is
    ignored.
  - **Removed**: the `ps aux --remote` source.
  - **Rules**: one per protocol,
    `-d IP -p udp|tcp -m multiport --dports <profile's ports for IP>`, so
    `remote-random` reconnects on another port still work.
  - **Profile parsing**: per-remote protocol overrides, comments, CRLF, `port`/`rport`
    defaults; ports validated (1–65535, at most 15, with a warning when more are
    dropped).
  - **Record write**: temp file plus rename, with a warning on failure.
- **Tests** (`tests/unit/test_hardening.sh`):
  - 13c: 28 checks, unprivileged. `sudo`, `iptables*`, `ip` and `ps` are stubbed, and
    `stat` reports uid 0 for the session fixtures; one case uses real user-owned files
    that must be rejected. `ks_expect` also requires exit 0, so "no rule" can't hide a
    crash.
  - 13b now uses the record.
  - Results: master's kill switch 51/76, the fix 76/76.
- **Docs**: `docs/TROUBLESHOOTING-KILL-SWITCH.md` (where the server is recorded),
  `docs/MACHINE-VALIDATION.md` §6 (rule limited by protocol and ports).
- Read-only check against the live session: resolves to `<server> udp 4569,1194,5060,80,51820`,
  matching the profile.
- **CI-only failure, fixed**: the record was never written on the GitHub runner, where
  `install -m 600 /dev/stdin <file>` fails with "No such file or directory". A temporary
  debug step (added and reverted on the branch) showed this. The record is now written
  with `tee` into the `mktemp` file (already mode 600). A fixture also set its log mode
  explicitly, since a 0002 umask made it group-writable. Note: `vpn-connector` also uses
  `sudo install ... /dev/stdin` for the session files. That works on this machine, but
  if it ever fails elsewhere, this is why.
- **Pre-existing**: the `.github/workflows/release.yml` run fails on every branch (also
  #287's); unrelated to these PRs and not investigated.

## 🎯 Current Project State

- **Tests**: full suite with the VPN connected: 126 passed, 0 failed. The live OpenVPN
  and firewall were untouched. CI: all checks green on `408fb22`.
- **Branch**: pushed, clean
- **Machine**: VPN connected (dk-120); kill switch off; `src/` installed at `41aad5b`
  (the #288 change is **not installed** yet)

### Agent Validation Status

- security-validator:
  - Design review: the original plan was projected at 3.5–4; the root record replaced it.
  - Implementation: **4.3/5**, no blockers. Its optional points 1, 2, 3, 4 and 5 were
    done in `ae2c87c`.
  - Not done: (6) recovery hint in the no-server warning; (7) the default interface
    name unescaped in a grep (cosmetic).
- code-quality-analyzer:
  - First review: **3.5/5**. Its two "blockers" were `set -e` aborts inside `$(...)`.
    They don't trigger here (no `inherit_errexit`; tests now pin rc == 0), but the
    constructs were made explicit anyway.
  - Its parsing findings (trailing comments dropping a remote, and others) are fixed and
    tested.
  - Re-review: **4.3/5**, no blockers. Its optional point (a failed temp-file `rm`
    could exit before the warning under `set -e`) was fixed, and the leftover-temp-file
    case was documented.
- Not done: splitting `get_vpn_server_allow` into one function per source; `proto`
  inside `<connection>` blocks (Proton profiles don't use them).

## 🚀 Next Session Priorities

1. Doctor Hubert approves the merge of #290 (CI green)
2. After the merge, install `vpn-kill-switch`:
   `sudo install -o root -g root -m 755 src/vpn-kill-switch /usr/local/bin/`
   Then run `docs/MACHINE-VALIDATION.md` §6: `vpn kill-switch enable` while connected,
   check the multiport rule with `sudo iptables -S VPN_KILL_SWITCH`, and confirm
   `/run/protonvpn-manager-session/kill_switch.server` is root-owned and 600; then
   `disable`.
3. Then #282 (stricter `vpn_is_healthy`), #277, #223 WireGuard (PRD)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then continue from Issue #288 (kill switch
allows the VPN server from trusted sources only, draft PR #290).

**Immediate priority**: merge #290 once CI is green and Doctor Hubert agrees; install
`vpn-kill-switch` and run MACHINE-VALIDATION §6 with the VPN up (1 h)
**Context**: maintenance phase; #287 and #285 merged; server record is root-owned in /run
**Reference docs**: SESSION_HANDOVER.md,
docs/implementation/SESSION-HANDOFF-288-kill-switch-trusted-server-2026-11-16.md
**Ready state**: master `73124a8`; `src/` installed at `41aad5b`; VPN connected (dk-120); `~/vpn-recover.sh`
**Expected scope**: #290 merged, installed and validated live; then start #282

## 📚 Key Reference Documents

- `docs/implementation/SESSION-HANDOFF-287-suite-reports-sub-script-failures-2026-11-16.md`
- `docs/TROUBLESHOOTING-KILL-SWITCH.md`, `docs/MACHINE-VALIDATION.md` §6

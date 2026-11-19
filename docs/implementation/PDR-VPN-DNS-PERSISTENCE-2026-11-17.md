# PDR: Keep the VPN's DNS in force while connected

**Document Version**: 0.2 (revised after the 6-agent review)
**Date**: 2026-11-17
**Author**: Doctor Hubert (with Claude Code assistance)
**Status**: Approved 2026-11-19 (Q1-Q4 decided as recommended)
**PRD**: `docs/implementation/PRD-VPN-DNS-PERSISTENCE-2026-11-17.md` (approved, S1 done)
**Issue**: #295 (related: #294)

---

## 1. Summary

| PRD | What | Where |
|---|---|---|
| FR6 (guarantee) | `VPN_DNS_GUARD` chain, IPv4 + IPv6, on while connected | `src/vpn-kill-switch` (`dns-guard on/off/status`, shared guard helpers), `src/vpn-connector` (`apply_leak_protection`), `src/vpn-utils` (`release_vpn_network_state`) |
| FR4 (visible) | resolv.conf vs. `tun0.protonvpn` mismatch, guard state | `src/vpn-utils` (`vpn_dns_mismatch`), `src/vpn-manager` (status), `src/vpn-doctor` |
| FR3 (repair) | `dns-change` handled by a **separate hook** with no user context | `etc/NetworkManager/dispatcher.d/40-vpn-dns-repair` (new file) |
| FR2 (prevent) | NetworkManager drop-in `rc-manager=resolvconf` | `etc/NetworkManager/conf.d/protonvpn-manager-dns.conf`, `install.sh` |
| FR5 (stale) | leftover `tun0.protonvpn` and guard after kill -9 | existing `clear_vpn_dns` / `release_vpn_network_state`, plus tests |
| R3 | Tailscale restore with a stale mode record | `src/vpn-utils` (`restore_tailscale_dns`) |

**Implementation order**, TDD each step, atomic commits:

1. **Refactor**: shared guard helpers in `vpn-kill-switch`, with the existing IPv6 guard tests
   green and no behaviour change.
2. FR6
3. FR4
4. FR3: the `40-vpn-dns-repair` hook, and `vpn_is_healthy` moved to `vpn-utils`
5. FR2: drop-in + installer
6. FR5 tests
7. R3
8. Docs (§7)

## 2. S1 findings that shape the design

(Full results in the PRD, section 3.)

- In resolvconf mode NetworkManager registers the entry `NetworkManager`; the VPN's `-x`
  entry wins. `nmcli general reload conf` applies the mode (`dns-rc` does not).
- `dns-change` reaches dispatcher hooks with an **empty interface**.
- **`resolvconf -u` rewrites resolv.conf whoever wrote it**: it repaired NetworkManager's file
  in S1 and in #295. Only `-a` refuses a foreign signature. So the repair is a plain `-u`.
- tailscaled chooses its DNS mode at **start**, from resolv.conf's header.
  - With the drop-in on, a restarted tailscaled uses openresolv mode: an exclusive `tailscale`
    entry that wins over the VPN's when added later.
  - So the Tailscale pause stays, and FR6 stops tailscaled's upstream queries from leaking.
- Wifi re-activation and `reload dns-full` with the drop-in on: 0 port-53 packets left
  wlan0. The tunnel itself died after the wifi re-activation: that's #294, not this PDR.
- The profiles here use **IP addresses** in `remote` (0 hostnames in the session profile and
  in `~/.config/vpn/locations`). So OpenVPN never needs DNS outside the tunnel to reconnect.

## 3. Design

### 3.1 FR6: DNS guard (`src/vpn-kill-switch`)

**Refactor first.** Shared helpers serve the IPv6 guard and the DNS guard:

- `guard_chain_on <family> <chain> <rules>`: one `*-restore --noflush` transaction, with a
  REJECT → DROP fallback.
- `guard_chain_off <family> <chain>`: built on the existing `remove_output_jumps`.
- `pin_output_order <family>`: puts the jumps in OUTPUT in this order:
  1. `VPN_DNS_GUARD`
  2. then `VPN_IPV6_GUARD` / the kill-switch chain, in their current relative order

`pin_output_order` details:

- It reads `-S OUTPUT` once and acts only when the order is wrong. In that case one
  restore transaction deletes the jump and re-inserts it.
- `enable_kill_switch` (and so `refresh`), `ipv6_guard_on` and `dns_guard_on` all call it.
- None of the chains needs to know about the others beyond this one function.

Chain `VPN_DNS_GUARD`, the same for `iptables` and `ip6tables`:

```text
-A VPN_DNS_GUARD -o lo -j RETURN
-A VPN_DNS_GUARD -o tun+ -j RETURN
-A VPN_DNS_GUARD -o tailscale0 -j RETURN
-A VPN_DNS_GUARD -p udp -m udp --dport 53 -j REJECT --reject-with icmp(6)-port-unreachable
-A VPN_DNS_GUARD -p tcp -m tcp --dport 53 -j REJECT --reject-with tcp-reset
```

Decisions:

- **RETURN, not ACCEPT**: the guard only denies. Whatever it doesn't reject goes on to the
  kill switch and the IPv6 guard unchanged.
- **OUTPUT position 1**: the guard rejects before:
  - the IPv6 guard's `fe80::/10` ACCEPT
  - the kill switch's `ESTABLISHED` ACCEPT. An open UDP/53 "connection" to the router is
    rejected too.
  - the kill switch's optional gateway:53 ACCEPT
- **One rule per protocol, no multiport** (#291).
- **REJECT, with a DROP fallback** (#291: modules that can't load until reboot).
  - REJECT makes the resolver fail over at once.
  - DROP stalls each lookup by the resolver timeout (5 s × attempts). It's only used when
    REJECT can't load, and the guard prints a one-line note when that happens.
- **Exempt interfaces**: `lo`, `tun+`, `tailscale0` only. `wg+` is deliberately **not**
  exempt (a test pins this), so the WireGuard PRD (#223) has to decide it explicitly.
- **Out of scope**: forwarded traffic (VMs, containers), as for the IPv6 guard.
- **IPv4 still works without ip6tables**: a warning, and the IPv4 chain still loads.
- **`dns-guard status`**: exit 0 when the jump exists in both families **and** is at
  position 1. It prints `on`, `off` or `on (not first in OUTPUT)`.
- **`emergency_disable`**: removes the guard, the same best-effort `sudo` form as the IPv6
  guard. `disable_kill_switch` leaves it alone: it belongs to the connection.

**Connector** (`apply_leak_protection`): `dns-guard on` runs after `ipv6-guard on` and after
`pause_tailscale_dns`, unless `BLOCK_DNS_LEAKS=false`. A failure prints
`WARNING: DNS may leak outside the tunnel`. Q1 covers `KILL_SWITCH_ALLOW_LAN_DNS`.

- **Before the tunnel is up, the guard is off.** Leak window left: about 1 s between tunnel up
  (`vpn-dns-update` already applied the VPN's DNS) and `apply_leak_protection`.
- That window is accepted. The guard is **not** moved into OpenVPN's root up-script, which
  must not read user config.

**Teardown**:

- `release_vpn_network_state` runs `dns-guard off` next to `ipv6-guard off`. That covers
  disconnect, `vpn cleanup`, `clear_stale_vpn_state` and the interrupt path.
- With `VPN_KEEP_KILL_SWITCH=1` (sleep and reconnect hooks) the guard is removed too.
  - During that reconnect the kill switch is the only barrier. It blocks DNS outside the
    tunnel unless `ALLOW_LAN_DNS=true` (Q1).
  - The reconnect turns the guard back on.

**Leftover guard after OpenVPN exits on its own** (resume, crash, #294): see Q4.

### 3.2 FR4: mismatch and guard state (`vpn-utils`, status, doctor)

`vpn_dns_mismatch` (in `vpn-utils`) returns 0 on a mismatch and prints both sets:

- **Expected**: the `nameserver` lines of `resolvconf -l tun0.protonvpn`.
- **Actual**: the `nameserver` lines of `${VPN_RESOLV_CONF:-/etc/resolv.conf}`.
- Comments and `search` lines are ignored; multiple nameservers are compared as a set.
  Parsing uses bash builtins (no grep/sort pipelines).
- Skipped, with no warning:
  - `resolvconf` missing or not openresolv
  - `tun0.protonvpn` not registered
  - `TAILSCALE_DNS=keep`
- An empty or unreadable resolv.conf counts as a mismatch.

`vpn status` and `vpn-doctor`:

- On a mismatch, print
  `DNS is not using the VPN (resolv.conf: 172.20.10.1). Fix: sudo resolvconf -u`.
- Add one line for the guard: `DNS guard: on|off|not first`. Warnings:
  - Connected, guard off, not opted out.
  - Guard on, **no VPN running**: "DNS is blocked by a leftover DNS guard. Fix: vpn cleanup".
- Status computes this once and stays read-only and unprivileged. `resolv.conf` and
  `resolvconf -l` need no root. The guard state comes from the existing sudo-able kill-switch
  `status` call path.

### 3.3 FR3: separate hook `40-vpn-dns-repair` (deviation from the PRD's "branch in 50-vpn-reconnect")

The reason for a separate hook: `50-vpn-reconnect` resolves the real user at top level, and
its `log_event`/`as_user` need that user. Restructuring it is the riskiest change the review
found (R4, architecture-designer). A separate hook has no user context at all, and
`50-vpn-reconnect` stays unchanged.

`vpn_is_healthy` moves from `50-vpn-reconnect` into `src/vpn-utils`, unchanged:

- Its fixed constants (`VPN_PID_FILE`, `VPN_SESSION_PROFILE`, `VPN_TUNNEL_INTERFACE`,
  `VPN_PROC_DIR`) move with it, as defaults that the hooks' tests reassign after sourcing.
- Both hooks use it. The existing `run_vpn_is_healthy` tests move with it.

`40-vpn-dns-repair` (root, `set -euo pipefail`, fixed `PATH`):

```text
ACTION=$2; [[ $ACTION == dns-change ]] || exit 0      # interface ($1) ignored, may be empty
VPN_DIR=/usr/local/bin; [[ -f $VPN_DIR/vpn-utils ]] || exit 0
# never sources user-writable code: no development-mode fallback
source "$VPN_DIR/vpn-utils"
RESOLV_CONF=/etc/resolv.conf                           # top-level constants, reassigned by tests
RUN_DIR=/run/protonvpn-manager
LOCK_FILE=$RUN_DIR/dns-repair.lock
TIMES_FILE=$RUN_DIR/dns-repair.times
main → repair_vpn_dns
```

`repair_vpn_dns` runs these steps, cheapest first:

1. `[[ -L $RESOLV_CONF ]]` → log `WARN` "resolv.conf is a symlink; not touching it", return.
2. `[[ -n $(resolvconf -l tun0.protonvpn 2>/dev/null) ]]` must hold, or return. It's a
   command substitution, not a pipeline (`pipefail`).
3. `vpn_is_healthy`, or return. Q4 adds the leftover-guard case here.
4. Lock directory:
   - Create it with `umask 077`.
   - Verify it's a directory, not a symlink, and owned by root (`-O`). Otherwise log and
     return.
   - Then `exec 9>"$LOCK_FILE"` and `if ! flock -n 9`. A busy lock means another repair is
     running, so return.
5. Rate limit:
   - `TIMES_FILE` holds at most the last 3 epoch seconds. Lines that aren't digits only are
     dropped, and so are timestamps in the future (clock moved back).
   - If 3 runs fell within the last 10 s, log `WARN` "dns-change loop suspected" and return,
     **without recording** this run.
   - The file is rewritten with only the kept entries (never grows).
6. `resolvconf -u 9>&-`. On failure, log `ERROR`; the hook exits 0.

- **Logging**: `dns_log` → `logger -t vpn-dns-repair` only, `|| true`. There's no user log by
  design: no user context exists. `vpn-doctor` points at `journalctl -t vpn-dns-repair` /
  syslog.
- **No content comparison** (PRD FR3): `-u` is idempotent and rebuilds from openresolv's own
  state.
- **Loops**:
  - S1 saw one `dns-change` per reload, and in resolvconf mode NetworkManager doesn't watch
    resolv.conf.
  - The rate limit catches anything else, and the guard keeps a rate-limited state leak-free.

### 3.4 FR2: NetworkManager drop-in (`install.sh`)

The repo file `etc/NetworkManager/conf.d/protonvpn-manager-dns.conf` holds two ABOUTME
comment lines plus `[main]` / `rc-manager=resolvconf`.

`install_nm_dns`, after `install_dns_helper`. It **skips with a message** unless all hold:

- NetworkManager runs (`nmcli -t general status`).
- `resolvconf --version` names openresolv.
- `pgrep -x systemd-resolve` finds nothing. Process names are cut to 15 characters, so this
  matches systemd-resolved.
- `/etc/resolv.conf` is not a symlink, and `/etc/NetworkManager/conf.d` is not a symlink.
- No `rc-manager=` in `/etc/NetworkManager/NetworkManager.conf` or in another conf.d file.

This list adds two skips the PRD didn't list: the symlinks, and an `rc-manager` the user
already set. The PDR extends FR2 here.

Install steps:

1. Write the file atomically: `install -T -o root -g root -m 644` to a temp name in conf.d,
   then `mv -T`.
2. `nmcli general reload conf`. **If the reload fails, remove the drop-in again** and warn.
3. When `tun0.protonvpn` is registered (install while connected), also run `resolvconf -u`.
4. Print what changed and how to undo it.

Re-running is idempotent: same content, no reload.

**Undo**: `install.sh --uninstall-nm-dns` (Q2):

1. Remove the drop-in and the `40-vpn-dns-repair` hook.
2. `nmcli general reload conf`.
3. `resolvconf -f -d NetworkManager` (S1: NetworkManager leaves it behind).
4. `resolvconf -u`.

`install.sh --no-nm-dns` installs everything else and runs the same undo.

**Hook install** (Q3): `install.sh` installs `40-vpn-dns-repair`
(`install -o root -g root -m 755`) under the same conditions as the drop-in. Without the
hook, FR3 never runs. `50-vpn-reconnect` stays an opt-in, by-hand install.

### 3.5 FR5: stale entries after a crash

`clear_vpn_dns`, `clear_stale_vpn_state` and `vpn cleanup` already exist. The work is tests
for the kill -9 path:

- **State before cleanup**: the entry is still registered, the guard is still there, and no
  openvpn runs.
- **After cleanup**: both are removed and `resolvconf -u` runs.

Fix whatever the tests show. `~/vpn-recover.sh` is machine-local, not in the repo. **This
deviates from the PRD's FR5/FR6 text**: the handoff gives its 3 lines per family
(`-D OUTPUT -j VPN_DNS_GUARD`, `-F`, `-X`) for Doctor Hubert to add by hand.

### 3.6 R3: Tailscale restore with a stale mode record

`restore_tailscale_dns`, after `accept-dns=true`: when the takeover wait finds no
`100.100.100.100` but `resolvconf -l tailscale` is non-empty, run `sudo resolvconf -u` once
and re-check.

- Tailscale's entry is exclusive, so `-u` makes resolv.conf Tailscale's.
- Nothing is deleted.
- Then the existing warning applies.

Open (not blocking): why a reconnect at 19:52 recorded `mode=direct` (PRD S1, "Open"). This
fix restores correctly for either record.

### 3.7 Configuration

| Key (`~/.config/vpn/config`) | Default | Effect |
|---|---|---|
| `BLOCK_DNS_LEAKS` | `true` | `false` skips the DNS guard |
| `KILL_SWITCH_ALLOW_LAN_DNS` | `false` | existing; with the guard on, it only matters while the tunnel is down (Q1) |
| `TAILSCALE_DNS` | `pause` | existing. `keep` + guard: non-tailnet names resolve only if the tailnet sets global nameservers (tailscaled's LAN upstream is blocked). |

Root-run code never reads these.

## 4. Security

- **The `40-vpn-dns-repair` hook takes no user input.** It has:
  - fixed paths and a fixed `VPN_DIR` (no development-mode sourcing)
  - no `$HOME` or user files, and ignores the interface argument
  - a lock directory verified as root-owned and not a symlink
  - rate-limit entries that are digits-only and size-bounded
  - the lock fd closed for `resolvconf`
- **The guard only adds REJECTs**, so it can't widen access. Failure modes:
  - It fails to load → warning, behaviour as today.
  - It's left over → DNS fails closed. Status says so (Q4 decides auto-removal).
- **The installer** never overwrites a foreign `rc-manager`, writes atomically, refuses
  symlinked paths and rolls back on a failed reload.
- **Residual risks**:
  - DoT/DoH (out of scope).
  - The ~1 s window before the guard loads.
  - Forwarded VM/container DNS.
  - Custom profiles with a hostname `remote`: they can't re-resolve the server while the
    guard is on. Documented.

## 5. Testing (TDD, never on the live VPN)

**Registration**:

- Unit scripts in `tests/unit_tests.sh`, integration in `tests/integration_tests.sh`.
- `tests/unit/test_suite_safety.sh` must pass (every script registered and sandboxed, #273).
- Every new script carries the 2-line ABOUTME header.

**Shared fakes**, in the style of `tests/unit/test_leak_protection.sh`:

- A fake `sudo` first on `PATH` that runs `"$@"` from the fake directory. `sudo` resets
  `PATH`, so without it the real iptables could be reached.
- A guard test that fails if any real `/usr/bin/iptables`, `ip6tables`, `resolvconf` or
  `nmcli` is called.
- **Stateful** fake `iptables`/`ip6tables`/`*-restore`: a file-backed table supporting
  `-C -D -I -A -S -L -N -F -X`. It makes "single jump", "position 1" and "every jump removed"
  meaningful.
- Fake `resolvconf` (with `-l`/`-u`/`-i`/`--version`), `nmcli`, `pgrep`, `logger`, `flock`.
- The existing overrides: `VPN_RESOLV_CONF`, `VPN_SESSION_DIR`, `VPN_CONFIG_DIR`.

**Unit**:

- **`tests/unit/test_dns_guard.sh`**:
  - Rule text for both families: RETURN for lo/tun+/tailscale0, udp and tcp REJECT, no
    `multiport`, `wg+` not exempt.
  - DROP fallback.
  - A failed restore leaves no half-applied chain.
  - `on` twice gives one jump.
  - `pin_output_order` gives the guard first for **every ordering** of kill switch enable,
    `ipv6-guard on` and `dns-guard on`.
  - `status` for on, off and not-first.
  - `off` removes every jump and the chain, and is a no-op when absent.
  - `emergency_disable` removes it.
  - Without ip6tables, IPv4 still loads.
  - The existing IPv6-guard tests pass unchanged after the refactor (step 1).
- **`tests/unit/test_leak_protection.sh`** (extended):
  - `apply_leak_protection` order: IPv6 guard, Tailscale pause, then DNS guard.
  - `BLOCK_DNS_LEAKS=false` skips the guard; Q1 behaviour.
  - `release_vpn_network_state` removes it, also with `VPN_KEEP_KILL_SWITCH=1`.
- **`tests/unit/test_dns_mismatch.sh`**:
  - match, mismatch, order-insensitive, several nameservers
  - comments and `search` lines ignored
  - empty or unreadable file → mismatch
  - skipped cases: no entry, not openresolv, `keep`
  - status lines for the guard states, including "leftover guard"
- **`tests/unit/test_dns_repair_hook.sh`**. Functions are extracted with `sed` and sourced,
  the way `test_auto_reconnect.sh` does it. Top-level constants are reassigned after sourcing.
  Cases:
  - healthy + entry → `-u` once
  - unhealthy → no-op
  - no entry → no-op
  - symlinked resolv.conf → refuse
  - lock directory a symlink or foreign-owned → refuse
  - held lock → skip
  - 3 runs in 10 s → the 4th is limited and not recorded
  - corrupt times file
  - pruning to 3 entries
  - clock moved back
  - `resolvconf` missing or `-u` failing → exit 0
  - `logger` failing under `set -e`
  - a non-`dns-change` action → exit 0 at once
  - **static check**: the hook never references `detect_real_user`, `HOME`, `as_user` or
    `VPN_DIR` fallbacks
- **`tests/unit/test_auto_reconnect.sh`**: `vpn_is_healthy` tests now source it from
  `vpn-utils`. Every existing case stays green.
- **`tests/unit/test_install_nm_dns.sh`**:
  - each skip condition, including both symlinks and a foreign `rc-manager`
  - install writes, reloads and is idempotent
  - while connected, also `-u`
  - reload failure → rollback
  - uninstall order
  - `--no-nm-dns`
- **R3** (in `tests/unit/test_leak_protection.sh`): Tailscale entry registered + foreign
  resolv.conf → one `-u`. No entry → no `-u`.

**Integration**: `tests/integration/test_dns_persistence.sh`, with all fakes.

- Connect sequence: IPv6 guard, DNS guard, then kill switch enabled afterwards. The guard is
  **still first** in both families.
- Disconnect removes every chain.
- Kill -9 path: fake `pgrep`, `kill` and PID file, and **no real PID is ever signalled**.
  `vpn cleanup` removes the stale entry and the guard.

**End-to-end / live**:

- A new `docs/MACHINE-VALIDATION.md` section, §10, run by hand.
- **Every run**:
  - a pre-check that aborts unless this tool's VPN is up and resolv.conf is on its DNS
  - a trap plus a timeout watchdog that removes counter rules, restores the drop-in state,
    runs `dns-guard off` if the run added it, and `resolvconf -u`
  - a connectivity check (`getent hosts`) after each step, stopping on failure
- **Steps**:
  1. Port-53 counters on the physical interface.
  2. With the drop-in removed, run `reload dns-full`.
     - resolv.conf goes wrong; lookups fail fast; 0 packets leave.
     - The hook repairs it within 2 s.
  3. With the drop-in on, resolv.conf never changes.
  4. Kill switch on/off × guard on/off: lookups work.
  5. Disconnect: router DNS and Tailscale MagicDNS work, and the guard is gone.
  6. kill -9 openvpn: DNS fails closed, `vpn status` says so, and `vpn cleanup` restores it
     (or Q4's auto-removal).
  - Wifi re-activation is **excluded until #294 is fixed** (S1: it kills the tunnel).

## 6. Traceability

| Requirement | Design | Tests |
|---|---|---|
| FR1 resolv.conf from openresolv, VPN exclusive | §3.4 + §3.3 (+ existing `vpn-dns-update`) | install_nm_dns, dns_repair_hook, E2E 2-3 |
| FR2 drop-in | §3.4 | install_nm_dns, E2E 3 |
| FR3 dns-change repair | §3.3 | dns_repair_hook, auto_reconnect (moved health check), E2E 2 |
| FR4 warning | §3.2 | dns_mismatch, E2E 6 |
| FR5 stale cleanup | §3.5 | integration kill -9, E2E 6 |
| FR6 guard | §3.1 | dns_guard, leak_protection, integration, E2E 2/4/5 |
| FR7 unchanged without VPN | §3.1 teardown, §3.3 step 3 | leak_protection (release), integration (disconnect), E2E 5 |
| NFR security | §4 | dns_repair_hook static check, fake-sudo guard test |
| NFR portability | §3.4 skips | install_nm_dns skip cases |
| NFR tests off the live VPN | §5 fakes | suite_safety |
| R3 | §3.6 | leak_protection R3 cases |

## 7. Documentation impact

- **README.md**:
  - "DNS (no leaks)" (~L935): `BLOCK_DNS_LEAKS=false` in the settings block. Also: the
    guard, and that LAN-only names stop resolving while connected (R1).
  - "IPv6 (no leaks)" (~L963): a "DNS guard" subsection beside it.
  - "Sleep / network hooks" (~L985): `40-vpn-dns-repair`, and what `install.sh` installs.
  - The `etc/` file list: the conf.d drop-in.
- **docs/MACHINE-VALIDATION.md**:
  - "Escape hatches": a `BLOCK_DNS_LEAKS` row and the `ALLOW_LAN_DNS` note.
  - §9 hooks.
  - A new §10 (live DNS validation, §5).
- **docs/TROUBLESHOOTING-KILL-SWITCH.md**: a "DNS fails after a crash: leftover DNS guard"
  entry, plus the drop-in undo.
- **CHANGELOG.md**: an entry under Unreleased.
- **PRD**: it's not edited. The deviations are listed in §8 of this PDR.

## 8. Deviations from the PRD

1. FR3 is a separate hook `40-vpn-dns-repair`, not a branch in `50-vpn-reconnect` (R4
   removed).
2. FR2 skips two more cases: a symlinked resolv.conf or conf.d, and an `rc-manager` the user
   already set.
3. FR3 logs to syslog only (no user log).
4. FR5/FR6: `~/vpn-recover.sh` is updated by hand (it's not in the repo).
5. R3 fix added (small, nothing deleted).

## 9. Risks

- **R1, LAN-only names stop resolving while connected**: documented, opt-out.
- **R2, another tool inserts at OUTPUT 1**: `pin_output_order` runs on every kill-switch
  enable/refresh and guard on. Status reports "not first".
- **R3**: §3.6.
- **R4, hook restructuring**: removed by the separate hook. The `vpn_is_healthy` move is
  covered by its existing tests.
- **R5, side effects of `nmcli general reload conf`**: S1 saw no wifi drop. The installer runs
  it once, with rollback.
- **R6, leftover guard blocks DNS after OpenVPN exits on its own**: Q4.

## 10. Questions for Doctor Hubert

**Decided 2026-11-19: Doctor Hubert took the recommendation on all four** (Q1 guard wins;
Q2 `--uninstall-nm-dns` / `--no-nm-dns`; Q3 `install.sh` installs `40-vpn-dns-repair`;
Q4 the hook removes a leftover guard only when the kill switch is off).

- **Q1, `KILL_SWITCH_ALLOW_LAN_DNS=true` vs. the guard.** Recommendation (architecture and
  security agree; this changes v0.1's proposal):
  - The guard wins.
  - `ALLOW_LAN_DNS` then only matters while the tunnel is down (reconnect).
  - The connector prints one line when both are set: "for LAN DNS while connected, set
    BLOCK_DNS_LEAKS=false".
- **Q2, undo path.** Recommendation: `install.sh --uninstall-nm-dns` (and `--no-nm-dns`).
  The legacy `uninstall.sh` gets its own issue.
- **Q3, install the hook.** Recommendation: `install.sh` installs `40-vpn-dns-repair` with
  the drop-in (FR3 is unreachable otherwise). `50-vpn-reconnect` stays by hand. Code quality
  preferred a separate issue; architecture and security want it here.
- **Q4, leftover guard when OpenVPN exits on its own** (resume, crash, #294).
  - This changes the PRD's "fails closed".
  - Today's suspend behaviour (resume kills tun0, kill switch off, manual reconnect) means
    DNS would stay dead after **every** suspend until `vpn cleanup` or `vpn connect`.
  - Recommendation (architecture): the `40-vpn-dns-repair` hook removes the guard on any
    `dns-change` when **all** of these hold:
    - no openvpn of ours runs
    - no `tun0.protonvpn` entry
    - the kill switch is **off**
  - With the kill switch on, the guard stays (fail closed, as before).
  - Alternative: keep fail-closed and rely on the status warning.

## 11. Agent review (2026-11-17, v0.1)

| Agent | Score | Folded into v0.2 |
|---|---|---|
| architecture-designer | 4.0 | separate hook (§3.3), `pin_output_order` (§3.1), Q1/Q2/Q3 recommendations, Q4 |
| security-validator | 3.8 | position check in status, no dev-mode sourcing, lock fd closed, installer hardening (§3.4), ESTABLISHED-rejected test. Two findings checked and rejected with evidence: `-u` does rewrite NetworkManager's file (S1, #295); the profiles use IP remotes |
| performance-optimizer | 4.0 | cheapest checks first, bounded times file, re-pin only when out of order, DROP stall documented. The content comparison before `-u` was declined (PRD FR3) |
| test-automation-qa | 3.0 | extraction-based hook tests, registration in `unit_tests.sh`, fake sudo, stateful iptables fake, missing cases, live-run watchdog |
| code-quality-analyzer | 3.5 | shared guard helpers as a refactor step, `dns_log`, `set -e` guards, ABOUTME. `pgrep -x systemd-resolve` kept: process names are cut to 15 characters |
| documentation-knowledge-manager | 4.0 | §6 traceability, §7 doc impact, §8 deviations |

## 12. Approval

- [x] Agent review (6 core agents, v0.1)
- [x] Doctor Hubert: Q1-Q4 (2026-11-19, all as recommended)
- [x] Doctor Hubert: PDR approval (2026-11-19)

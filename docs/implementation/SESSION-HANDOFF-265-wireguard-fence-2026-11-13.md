# Session Handoff: Issue #265 - refuse WireGuard profiles until #223

**Date**: 2026-11-13
**Issue**: #265 - WireGuard connect reports success, but the tunnel disappears and status/disconnect don't see WireGuard
**PR**: #267 - fix(wireguard): refuse WireGuard profiles until WireGuard support is complete
**Branch**: `fix/issue-265-fence-off-wireguard`

## Root cause (reproduced on the machine)

- `wg-quick up` by hand on `wg-SE-374`: the interface stayed up 3 minutes, handshakes
  renewing, traffic flowing. Through `vpn custom` it stayed up until Doctor Hubert
  removed it with `~/vpn-recover.sh` (16:04:21; `ip -ts monitor` plus a process sampler
  show `wg-quick down` from the recovery script). Nothing else removes it.
- What breaks is DNS: `/etc/resolv.conf` is Tailscale's (`nameserver 100.100.100.100`).
  wg-quick's rule `5209: not from all fwmark 0xca6c lookup 51820` comes before
  Tailscale's `5270: lookup 52`, so DNS and tailnet traffic go into the Proton tunnel.
  The OpenVPN path pauses Tailscale DNS (`pause_tailscale_dns`) and installs the VPN's
  DNS; the WireGuard path does neither (the profile's `DNS =` is commented out, #223).
- NetworkManager marks wlan0 "limited connectivity" (default route metric 600 → 20600),
  likely the `connectivity-change` dispatcher event seen on 2026-11-10.
- `vpn status`/`vpn disconnect` only know OpenVPN, so the broken tunnel was invisible.
- Repro scripts: the session scratchpad (`wg-repro.sh`, `wg-watch.sh`); not kept.

## Decision

Doctor Hubert chose to fence off WireGuard until #223 (full support needs a PRD),
rather than a minimal WireGuard fix.

## ✅ Completed Work

- `src/vpn-connector`: `get_cached_profiles` leaves out `.conf` (every listing and
  selection: connect/best/fast/random, `vpn secure`, interactive, `vpn countries`);
  the unfiltered list is `cached_profile_paths`. `refuse_wireguard` (exit 1, so failover
  stops) in `connect_to_profile` and `connect_custom_profile` (also the reconnect hook).
  Control characters stripped from the refusal message and log. `connect_wireguard_profile`
  kept for #223.
- `src/vpn` (`vpn list`) and `src/best-vpn-profile` (`rank`, `test`): `.ovpn` only.
- `tests/unit/test_wireguard_fence.sh` (new, 21 tests, RED first), registered in
  `tests/unit_tests.sh`; `tests/unit/test_country_selection.sh` expectation updated.
- PR #266 (checklist step 7 uses the default gateway; fixed known issues dropped) merged.

## 🎯 Current Project State

**Tests**: ✅ `run_tests.sh` 114/114; fence 21/21, latency 39/39, suite safety 55/55
(`tests/unit/test_profile_cache.sh` exits 1 on master too: pre-existing, not in the suite)
**Branch**: `fix/issue-265-fence-off-wireguard`, pushed
**Machine**: no WireGuard interface, no wg rules or nft tables, VPN disconnected

### Agent Validation Status

- code-quality-analyzer: 4/5. Must-fix: secure core and interactive read the cache
  unfiltered → fixed by filtering in `get_cached_profiles`. Nits done: `vpn list`,
  `best-vpn-profile`, the "Only .ovpn" message.
- security-validator: 4/5, no must-fix; no path brings up WireGuard; refusal fails closed
  (kill switch kept under `VPN_KEEP_KILL_SWITCH=1`). Low: control characters in the
  refusal → fixed and tested.
- test-automation-qa: 4/5, no must-fix. Added: cache/list/best-vpn-profile exclusion,
  WireGuard-only country, failover stops on refusal, sanitizing, sourcing check.

## 🚀 Next Session Priorities

1. README still describes WireGuard as supported (lines ~242, ~272, ~960); edit it together
   with the markdown lint cleanup (README has 91 findings, 88 auto-fixable)
2. #263 `((x++))` under `set -e` in `src/vpn-connector` (`rebuild_cache`, `cached_profile_paths`)
3. #223 WireGuard support needs a PRD: Tailscale DNS, Proton DNS, status/disconnect,
   kill switch for `wg-*`

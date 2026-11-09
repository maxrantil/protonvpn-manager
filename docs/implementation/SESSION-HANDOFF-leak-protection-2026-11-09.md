# Session Handoff: IPv6 and DNS stay inside the tunnel

**Date**: 2026-11-09
**Issue**: #242 - IPv6 and DNS leak outside the tunnel; Tailscale DNS breaks the kill switch
**PR**: #243 (stacked on #241)
**Branch**: `fix/ipv6-and-tailscale-dns-leaks`

## ✅ Completed Work

- While connected, `vpn-kill-switch ipv6-guard` blocks outgoing IPv6
  (`VPN_IPV6_GUARD`; loopback, link-local, multicast, tun, tailscale0 and virbr
  allowed; REJECT, or DROP when the module cannot load). Opt-out: `BLOCK_IPV6=false`
- While connected, Tailscale DNS is paused (`--accept-dns=false`, recorded with
  its mode) and resolv.conf rebuilt from resolvconf; restored on release, only
  if it was paused by us. Opt-out: `TAILSCALE_DNS=keep`
- openresolv only rewrites a resolv.conf carrying its own signature. The DNS
  helper now forces the rewrite (`resolvconf -u`) over NetworkManager's file, so
  the VPN's DNS is applied at all on such systems (it never was)
- After disconnect, NetworkManager's DNS is put back when resolvconf leaves no
  nameservers (disconnect left DNS dead before); Tailscale in resolvconf mode
  gets `resolvconf -u` instead; a warning if Tailscale does not take DNS back
- Removed the false "Skipping DNS operations" disconnect message
- `tests/unit/test_leak_protection.sh` (31 tests, incl. a fake openresolv with
  the real signature rule and real ip6tables in a namespace)

## 🎯 Current Project State

- **Tests**: ✅ all unit suites pass
- **CI/CD**: ✅ all checks green (pre-commit needed a retry: HTTP 504 building
  shellcheck_py)
- **Live test** (Tailscale running, rollback in place), with and without kill
  switch: IPv6 blocked, DNS answered by ProtonVPN, websites resolve with the kill
  switch; after disconnect DNS, IPv6 and MagicDNS are back on the first try
- A first live run left DNS dead after disconnect (fixed above); the test
  harness now rolls back at once when DNS fails instead of cancelling the watchdog

### Agent Validation Status

- Not run: no specialist agents were used in this session

## 🚀 Next Session Priorities

1. Merge after #241
2. Document `BLOCK_IPV6` and `TAILSCALE_DNS` in README.md and CHANGELOG.md once
   their Markdown lint debt is cleaned (only `docs/MACHINE-VALIDATION.md` has them)
3. After a reboot (kernel upgraded to 7.2.14, running 7.2.11) the guard uses
   REJECT instead of DROP
4. The kill switch's IPv6 chain accepts ESTABLISHED flows, so IPv6 connections
   opened before it was enabled keep flowing; the guard does not (worth aligning)

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then merge PR #243 after #241 and
document BLOCK_IPV6/TAILSCALE_DNS in README.md and CHANGELOG.md.

## 📚 Key Reference Documents

- `tests/unit/test_leak_protection.sh`, `src/vpn-utils` (release path),
  `src/vpn-dns-update`

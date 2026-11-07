# Session Handoff: DNS leak fix and root-owned session files

**Date**: 2026-11-07
**Branch**: `fix/dns-and-profile-copy`

## ✅ Completed Work

- `src/vpn-dns-update`: root-owned OpenVPN up/down helper; registers pushed
  `dhcp-option DNS/DOMAIN` with `resolvconf` (`-x` exclusive on openresolv),
  removes them on down; validates every pushed value.
- Connector passes it via `--script-security 2 --up/--down` only if the helper
  and all parent directories are root-owned and not group/other-writable;
  warns about possible DNS leaks otherwise (`DNS_MODE=none` silences).
- Kill switch: no DNS-to-gateway exception unless `KILL_SWITCH_ALLOW_LAN_DNS=true`;
  reads the OpenVPN log from the session directory.
- TOCTOU fix: profile and credentials are read once, validated from memory and
  written as root-owned copies to `/run/protonvpn-manager-session/`; OpenVPN and
  wg-quick only use those; the OpenVPN log lives there too (root:user 640).
- `install.sh` installs the helper root-owned; `uninstall.sh` removes it.

## 🎯 Current Project State

- Hardening suite 50/50 (new: session copies, swap rejection, DNS helper trust,
  helper script behaviour, kill-switch DNS rules in a network namespace).
- Not validated with a real ProtonVPN connection or real resolvconf.

## 🚀 Next Session Priorities

1. Real-machine check: `vpn connect se`, then `cat /etc/resolv.conf` shows the
   VPN DNS; `vpn disconnect` restores the previous DNS.
2. DNS leak test (e.g. dnsleaktest.com) with and without the kill switch.

## 📝 Startup Prompt for Next Session

Validate DNS handling and session files on real hardware.

## 📚 Key Reference Documents

- `src/vpn-dns-update`, `src/vpn-connector` (`start_openvpn_daemon`,
  `dns_helper_usable`), `src/vpn-kill-switch`
- README "DNS (no leaks)" and "Root-owned session files"

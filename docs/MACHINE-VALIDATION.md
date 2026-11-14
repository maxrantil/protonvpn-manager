# Validating the November 2026 changes on your machine

These changes were tested with mocks and an isolated network namespace, but
never against a real ProtonVPN connection. This checklist checks the parts
that only your machine can: real DNS, real servers, real `sudo`.

Work through it top to bottom. Each step says what you should see. If a step
doesn't match, stop and collect the logs listed in
[If something fails](#if-something-fails).

Changes covered: #231 hardening, #233 fastest server, #234 DNS and session
files, #235 clean-up, #236 faster connect, #237 tests/CI, #241 kill switch
clean-up, #243 IPv6/DNS leaks, #245 country selection, #247 and #255 test-suite
safety.

---

## 0. Prerequisites

```bash
sudo pacman -S --needed openvpn openresolv iproute2 iptables git
```

- [ ] `command -v resolvconf` prints a path. If it doesn't, DNS can't be routed
      through the VPN, and `vpn connect` will warn about it.

## 1. Update and install

```bash
cd ~/path/to/protonvpn-manager
git checkout master && git pull
./install.sh            # as your normal user, NOT with sudo
```

- [ ] The installer ends with "Installation complete!"
- [ ] The DNS helper is root-owned and not writable by others:
      ```bash
      stat -c '%U %a %n' /usr/local/lib/protonvpn-manager /usr/local/lib/protonvpn-manager/vpn-dns-update
      ```
      Expect `root 755` for both.
- [ ] `/etc/protonvpn-manager.conf` contains `VPN_USER=<your username>`.
- [ ] Every installed script is root-owned:
      `ls -l /usr/local/bin/vpn*` shows `root root` and `-rwxr-xr-x`.

## 2. Profiles and credentials

- [ ] The `.ovpn` files are in `~/.config/vpn/locations/`.
- [ ] `~/.config/vpn/vpn-credentials.txt` has the OpenVPN username on line 1
      and the password on line 2, and is mode 600 (`stat -c %a` prints `600`).

Profiles that run scripts are now rejected. Stock ProtonVPN profiles don't, but
if you uncommented `up /etc/openvpn/update-resolv-conf` in any of them, comment
it out again. DNS is handled by the new helper now.

## 3. Latency measurement (fastest server)

```bash
best-vpn-profile test se
```

- [ ] A table of RTT values in milliseconds, lowest first.
- [ ] If you see `Note: no server answered ping`, your network blocks ICMP and
      TCP timing is used instead. That still works, but it's less accurate.
      Worth noting.

## 4. Connect (speed, fastest server, DNS)

```bash
cat /etc/resolv.conf > /tmp/resolv.before     # remember the normal DNS
time vpn connect se
```

- [ ] It prints `Checking latency to N servers...`, then `Fastest server: se-XX (NN ms; ...)`.
- [ ] No warning about DNS or resolvconf.
- [ ] It reports `Connected` a few seconds after the tunnel is up. The old code
      could add up to 8 seconds of waiting.
- [ ] `vpn status` shows CONNECTED with a ProtonVPN external IP.

DNS while connected:

```bash
cat /etc/resolv.conf
resolvconf -l | grep -A3 protonvpn
```

- [ ] The nameserver is the VPN's (usually `10.2.0.1`), not your router.
- [ ] A DNS leak test (e.g. <https://dnsleaktest.com>, extended test) shows
      **only** ProtonVPN servers.

Root-owned session files:

```bash
ls -l /run/protonvpn-manager-session/
```

- [ ] `profile.ovpn` and `credentials` are `-rw------- root <your group>`.
- [ ] `openvpn.log` is `-rw-r----- root <your group>`, and you can read it
      without sudo: `tail -3 /run/protonvpn-manager-session/openvpn.log`.

## 5. Disconnect and cleanup

```bash
vpn disconnect
diff /tmp/resolv.before /etc/resolv.conf && echo "DNS restored"
ls /run/protonvpn-manager-session/
time vpn cleanup
```

- [ ] `DNS restored` is printed (no diff).
- [ ] `profile.ovpn` and `credentials` are gone from the session directory.
- [ ] `vpn cleanup` finishes in well under a second when nothing is running.
- [ ] With a connection up, `vpn cleanup` takes about a second, not about 8.
      Try it: `vpn connect se`, then `time vpn cleanup`.

## 6. Kill switch

```bash
vpn connect se --kill-switch
vpn kill-switch status
```

- [ ] Status shows ENABLED, plus a rule for the VPN server IP.
- [ ] Browsing works, and DNS still resolves (through the VPN).
- [ ] DNS to the router is blocked:
      ```bash
      ip route show default        # note the gateway IP, e.g. 192.168.1.1
      dig +time=2 +tries=1 @192.168.1.1 example.com   # should time out
      ```
- [ ] `vpn disconnect` turns the kill switch off (also with auto-reconnect
      enabled: only the sleep and network hooks keep it), and normal browsing
      works again.

Switching country with the kill switch on (verified 2026-11-10, `se` → `dk`;
use any country you have profiles for):

- [ ] `vpn connect dk --kill-switch` while connected is refused
      ("OpenVPN process(es) already running"). The current connection and
      the kill switch stay as they were.
- [ ] `vpn disconnect`, then `vpn connect dk --kill-switch`, connects. The
      kill switch allows only the new server's IP (`sudo iptables -S
      VPN_KILL_SWITCH`), not the old one.

## 7. Failover to the next-fastest server

This adds a "server" that answers ping but isn't an OpenVPN server: a copy
of a real profile (OpenVPN rejects a profile without its CA before it tries
the server) with every `remote` pointing at your default gateway (your
router). The router answers ping faster than any real server, so `se-999`
is ranked first. A public address such as 1.1.1.1 doesn't work: real
servers are often faster, and then the failover never happens.

Clear the latency cache first: the ranking reuses recent measurements, so
an older result for `se-999` (or for the real servers) can change the order.

```bash
gw=$(ip route show default | awk '{print $3; exit}')
src=$(ls ~/.config/vpn/locations/se-*.ovpn | head -1)
sed -E "s/^remote .*/remote $gw 1194/" "$src" > ~/.config/vpn/locations/se-999.ovpn
echo "CONNECT_TIMEOUT=10" >> ~/.config/vpn/config
best-vpn-profile clear
best-vpn-profile test se   # se-999 should be at the top
vpn connect se
```

- [ ] `vpn connect se` prints `Fastest server: se-999 (... ms; N of the servers
      answered)` with N above 1.
- [ ] After about 10 s it prints
      `Server did not answer; trying the next fastest: se-XX`, then connects
      to a real server.

Clean up afterwards:

```bash
vpn disconnect
rm ~/.config/vpn/locations/se-999.ovpn
sed -i '/^CONNECT_TIMEOUT=10$/d' ~/.config/vpn/config
best-vpn-profile clear
```

## 8. Smaller checks

- [ ] `vpn secure` with no Secure Core profiles (names like `ch-se-01` or
      `se-au-01`) prints an error. It does **not** connect to a regular
      server. With Secure Core profiles it connects to one of them.
- [ ] A profile that runs scripts is rejected:
      ```bash
      cp "$(ls ~/.config/vpn/locations/se-*.ovpn | head -1)" ~/.config/vpn/locations/se-998.ovpn
      printf 'up /bin/true\n' >> ~/.config/vpn/locations/se-998.ovpn
      vpn custom ~/.config/vpn/locations/se-998.ovpn   # expect "directives that would run commands"
      rm ~/.config/vpn/locations/se-998.ovpn
      ```
- [ ] `vpn help` no longer lists `download-configs` or `service`.
- [ ] `vpn doctor` runs without errors about missing `bc`. While
      disconnected it still runs every check and prints the summary.

## 9. Optional: sleep and network hooks

`install.sh` doesn't install these. Only do this if you want auto-reconnect.

```bash
sudo install -o root -g root -m 755 etc/elogind/system-sleep/50-vpn-sleep /lib/elogind/system-sleep/
sudo install -o root -g root -m 755 etc/NetworkManager/dispatcher.d/50-vpn-reconnect /etc/NetworkManager/dispatcher.d/
vpn-manager config auto-reconnect on      # requires the kill switch to be enabled
```

- [ ] Suspend and resume while connected with `--kill-switch`: it reconnects.
      Check `~/.local/state/vpn/sleep-hook.log` and `journalctl -t vpn-sleep`.
- [ ] Network hook (auto-reconnect must be on, see above; start disconnected):
      simulate a dropped tunnel, then bring the network back. It reconnects with
      the kill switch still on, and nothing leaks in between.
      (`nmcli device reconnect` doesn't exist in nmcli 1.58; use disconnect + connect.)
      ```bash
      dev=$(nmcli -t -f DEVICE,STATE device | awk -F: '$2=="connected"{print $1; exit}')
      vpn connect se --kill-switch
      sudo pkill -x openvpn            # traffic is now blocked, not leaked
      nmcli device disconnect "$dev" && nmcli device connect "$dev"
      ip link show tun0                # back within a few seconds
      sudo tail -1 /run/protonvpn-manager/reconnect.attempts   # "<epoch seconds>:success"
      ```
- [ ] Wait out the cooldown (30 s by default), then repeat the `pkill` and the
      nmcli pair: the second drop must reconnect too (#248). Afterwards
      `find ~/.local/state/vpn ! -user "$USER"` prints nothing.

---

## Running the test suite on this machine

`cd tests && ./run_tests.sh` is safe while you work, also next to a running VPN:
every suite runs with a temporary HOME and a `sudo` that refuses, `cleanup` and
`kill` are skipped while a session runs, and `tests/unit/test_suite_safety.sh`
checks all of this with a fake OpenVPN (#250). Two parts can still use the real
VPN:

- `tests/test_exit_codes.sh` connects with your real profiles and credentials.
  It is skipped unless you ask for it:
  `vpn disconnect && VPN_LIVE_TESTS=1 ./tests/test_exit_codes.sh`
- The process safety tests run the real `vpn cleanup`. They are skipped while
  a VPN is running.

`tests/cleanup_tests.sh`, `health_command_functionality_tests.sh`,
`command_completion_tests.sh` and `emergency_reset_vs_cleanup_tests.sh` run the
real `vpn cleanup`, `kill` and `emergency-reset` too. They are part of the unit
suite, use a temporary HOME with sudo blocked, and are skipped while a VPN is
running (#271).

In tests the PID file (`VPN_PID_FILE`, normally `/var/run/openvpn.pid`) and the
session directory (`VPN_SESSION_DIR`) are inside the temporary directory, and
`curl` is blocked, so nothing looks up your external IP (#273). One limit
remains: a user-owned OpenVPN started in the middle of a test run can be ended
by a test. The root-owned one this tool starts cannot (sudo is blocked). How
the suite is organised: `tests/README_TESTING.md`.

## If something fails

Collect these and paste them into a new Claude session:

```bash
vpn doctor
vpn logs 100
tail -50 ~/.local/state/vpn/vpn_connect.log
tail -50 /run/protonvpn-manager-session/openvpn.log
journalctl -t vpn-dns-update -n 20
cat /etc/resolv.conf
sudo iptables -S VPN_KILL_SWITCH 2>/dev/null
```

Also say which step failed, and what you saw versus what was expected.

## Escape hatches

These go in `~/.config/vpn/config`, one per line.

| Setting | Effect |
|---|---|
| `DNS_MODE=none` | Don't touch DNS (and no warning) |
| `KILL_SWITCH_ALLOW_LAN_DNS=true` | Let DNS reach the router while the kill switch is on (leaks DNS) |
| `SERVER_SELECTION=random` | `vpn connect` picks a random server, as before |
| `FAILOVER_SERVERS=1` | No failover: retry the same server |
| `CONNECT_TIMEOUT=35` | Seconds to wait per server (5-300) |
| `ALLOW_PROFILE_SCRIPTS=true` | Allow `up`/`down`/… in profiles you trust |
| `BLOCK_IPV6=false` | Don't block IPv6 outside the tunnel while connected (leaks IPv6) |
| `TAILSCALE_DNS=keep` | Keep Tailscale's DNS while connected (leaks DNS; with the kill switch, no names resolve) |

To go back to the version from before these changes:

```bash
git checkout 2465731 && ./install.sh   # master as of 2026-11-05
```

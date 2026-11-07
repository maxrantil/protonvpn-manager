# Validating the November 2026 changes on your machine

These changes were tested with mocks and an isolated network namespace, but
never against a real ProtonVPN connection. This checklist checks the parts
that only your machine can: real DNS, real servers, real `sudo`.

Work through it top to bottom. Each step says what you should see. If a step
doesn't match, stop and collect the logs listed in
[If something fails](#if-something-fails).

Changes covered: #231 hardening, #233 fastest server, #234 DNS and session
files, #235 clean-up, #236 faster connect, #237 tests/CI.

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
- [ ] A DNS leak test (e.g. https://dnsleaktest.com, extended test) shows
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
- [ ] `vpn disconnect` turns the kill switch off (unless auto-reconnect is
      enabled), and normal browsing works again.

Not yet verified anywhere, so worth trying: with the kill switch on, disconnect
and connect to a **different** country (`vpn connect nl --kill-switch`). If
that hangs or fails, note it. The kill switch may only allow the previous
server's IP.

## 7. Failover to the next-fastest server

This makes the fastest-looking "server" one that answers ping but isn't an
OpenVPN server:

```bash
printf 'client\ndev tun\nproto udp\nremote 1.1.1.1 1194\n' > ~/.config/vpn/locations/se-999.ovpn
echo "CONNECT_TIMEOUT=10" >> ~/.config/vpn/config
vpn connect se
```

- [ ] `se-999` is picked first. After about 10 s it prints
      `Server did not answer; trying the next fastest: se-XX`, then connects.

Clean up afterwards:

```bash
vpn disconnect
rm ~/.config/vpn/locations/se-999.ovpn
sed -i '/^CONNECT_TIMEOUT=10$/d' ~/.config/vpn/config
```

## 8. Smaller checks

- [ ] `vpn secure` with no Secure Core profiles (names like `ch-se-01`) prints
      an error. It does **not** connect to a regular server.
- [ ] A profile that runs scripts is rejected:
      ```bash
      cp ~/.config/vpn/locations/se-1*.ovpn /tmp/x.ovpn 2>/dev/null; printf 'up /bin/true\n' >> /tmp/x.ovpn
      cp /tmp/x.ovpn ~/.config/vpn/locations/se-998.ovpn
      vpn custom ~/.config/vpn/locations/se-998.ovpn   # expect "directives that would run commands"
      rm ~/.config/vpn/locations/se-998.ovpn /tmp/x.ovpn
      ```
- [ ] `vpn help` no longer lists `download-configs` or `service`.
- [ ] `vpn doctor` runs without errors about missing `bc`.

## 9. Optional: sleep and network hooks

`install.sh` doesn't install these. Only do this if you want auto-reconnect.

```bash
sudo install -o root -g root -m 755 etc/elogind/system-sleep/50-vpn-sleep /lib/elogind/system-sleep/
sudo install -o root -g root -m 755 etc/NetworkManager/dispatcher.d/50-vpn-reconnect /etc/NetworkManager/dispatcher.d/
vpn-manager config auto-reconnect on      # requires the kill switch to be enabled
```

- [ ] Suspend and resume while connected with `--kill-switch`: it reconnects.
      Check `~/.local/state/vpn/sleep-hook.log` and `journalctl -t vpn-sleep`.

---

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

To go back to the version from before these changes:

```bash
git checkout 2465731 && ./install.sh   # master as of 2026-11-05
```

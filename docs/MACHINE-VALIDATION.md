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
safety, #295 DNS guard and NetworkManager DNS (§10).

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
- [ ] With NetworkManager and openresolv, the installer prints
      `Installed: /etc/NetworkManager/dispatcher.d/40-vpn-dns-repair` and
      `Installed: /etc/NetworkManager/conf.d/protonvpn-manager-dns.conf`, or
      `Skipping NetworkManager DNS setup: <reason>`. Both files are
      `root root`, mode 755 (hook) and 644 (drop-in):
      ```bash
      stat -c '%U %G %a %n' /etc/NetworkManager/dispatcher.d/40-vpn-dns-repair /etc/NetworkManager/conf.d/protonvpn-manager-dns.conf
      ```
- [ ] Running `./install.sh` again prints `Unchanged: .../protonvpn-manager-dns.conf`.

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

- [ ] Status shows ENABLED, plus one rule per port for the VPN server IP,
      limited to the profile's protocol (`-p udp -m udp --dport ...`). This
      also works after a kernel upgrade without a reboot.
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

`install.sh` doesn't install these two (it does install `40-vpn-dns-repair`,
see §10). Only do this if you want auto-reconnect.

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

## 10. DNS while connected: guard, NetworkManager, crash recovery (#295)

This checks that the VPN's DNS stays in force while NetworkManager rewrites
DNS, that nothing leaves on port 53 outside the tunnel, and that a crash
doesn't leave DNS broken. Steps 1-4 run as one script that restores
everything when it ends; steps 5-7 are done by hand.

Before you start:

- [ ] **Reboot if the kernel was upgraded since boot** (`uname -r` isn't in
      `ls /usr/lib/modules`). Until then REJECT may not load (#291): the guard
      falls back to DROP and prints `Note: REJECT is unavailable ...`, and
      step 1 reports slow lookups to the router.
- [ ] This branch is installed (§1), and the installer installed the drop-in
      and `40-vpn-dns-repair`.
- [ ] Connected with this tool (`vpn connect se`), and `vpn status` shows
      `DNS guard: on` and no DNS warning.
- [ ] Note whether a syslog daemon runs (`ls /dev/log`). Without one, the
      hooks' `logger` messages (`vpn-dns-repair`, `vpn-dns-update`) are lost,
      so the checks below look at resolv.conf and the firewall, not logs.

### Steps 1-4 (script)

Save the script, then run it as your normal user (it calls sudo itself). It
aborts unless this tool's VPN is up, resolv.conf is on the VPN's DNS and the
guard is on. On exit, Ctrl-C or after 240 s (watchdog) it removes its
counters, puts the drop-in back, restores the kill switch to how it was, turns
the guard back on and runs `resolvconf -u`. It stops at the first failed
lookup.

```bash
cat > ~/dns-validation.sh <<'EOF'
#!/bin/bash
# MACHINE-VALIDATION §10 steps 1-4 (#295). Restores everything on exit.
set -uo pipefail
dropin=/etc/NetworkManager/conf.d/protonvpn-manager-dns.conf
aside=/etc/NetworkManager/conf.d/.protonvpn-manager-dns.conf.dnsval  # dot files are ignored
hook=/etc/NetworkManager/dispatcher.d/40-vpn-dns-repair
dev=$(ip route show default | awk '{print $5; exit}')
gw=$(ip route show default | awk '{print $3; exit}')
fail=0 wd="" ks0=off
ok() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
stop() { bad "$*"; exit 1; }
vpn_ns() { resolvconf -l tun0.protonvpn 2>/dev/null | awk '$1=="nameserver"{print $2}' | sort; }
cur_ns() { awk '$1=="nameserver"{print $2}' /etc/resolv.conf | sort; }
on_vpn_dns() { [[ -n $(vpn_ns) && $(vpn_ns) == "$(cur_ns)" ]]; }
lookup() { timeout 5 getent hosts example.com >/dev/null || stop "lookups fail ($1)"; }
now_ms() { echo $(($(date +%s%N) / 1000000)); }
counted() { # port-53 packets that left $dev, IPv4 + IPv6
	local n=0 t c
	for t in iptables ip6tables; do
		c=$(sudo "$t" -t mangle -L DNSVAL -v -x -n 2>/dev/null | awk 'NR>2{s+=$1} END{print s+0}')
		n=$((n + c))
	done
	echo "$n"
}
leak_probe() { { printf 'x' >"/dev/udp/$gw/53"; } 2>/dev/null; sleep 0.5; } # one byte to the router's DNS port
guard() { vpn-kill-switch dns-guard status 2>/dev/null | head -1; }

# Pre-check
sudo -v || exit 1
[[ -n $dev && $dev != tun* && -n $gw ]] || { echo "ABORT: no default route outside the tunnel"; exit 1; }
pgrep -f '(^|/)openvpn .*--config /run/protonvpn-manager-session/' >/dev/null ||
	{ echo "ABORT: this tool's VPN is not running"; exit 1; }
on_vpn_dns || { echo "ABORT: resolv.conf is not on the VPN's DNS"; exit 1; }
[[ $(guard) == on ]] || { echo "ABORT: DNS guard is not on"; exit 1; }
[[ -e $aside ]] && { echo "ABORT: leftover $aside; run: sudo mv -T $aside $dropin && sudo nmcli general reload conf"; exit 1; }
[[ -f $dropin && -x $hook ]] || { echo "ABORT: drop-in or hook missing (install the branch)"; exit 1; }
command -v dig >/dev/null || { echo "ABORT: dig not installed (pacman -S bind)"; exit 1; }
sudo iptables -S OUTPUT | grep -q -- '-j VPN_KILL_SWITCH$' && ks0=on

restore() {
	trap '' INT TERM HUP # a second Ctrl-C must not cut the restore short
	trap - EXIT
	[[ -n $wd ]] && kill "$wd" 2>/dev/null
	sudo -v || echo "WARNING: no sudo; restore may be incomplete"
	if [[ -e $aside ]]; then
		sudo mv -T "$aside" "$dropin" && sudo nmcli general reload conf ||
			echo "WARNING: drop-in not restored; run: sudo mv -T $aside $dropin && sudo nmcli general reload conf"
	fi
	if [[ $ks0 == on ]]; then
		vpn-kill-switch enable >/dev/null || echo "WARNING: kill switch not re-enabled; run: vpn kill-switch on"
	else
		vpn-kill-switch disable >/dev/null || echo "WARNING: kill switch not disabled; run: vpn kill-switch off"
	fi
	vpn-kill-switch dns-guard on >/dev/null || echo "WARNING: DNS guard not back on; run: vpn-kill-switch dns-guard on"
	for t in iptables ip6tables; do
		sudo "$t" -t mangle -D POSTROUTING -o "$dev" -j DNSVAL 2>/dev/null
		sudo "$t" -t mangle -F DNSVAL 2>/dev/null
		sudo "$t" -t mangle -X DNSVAL 2>/dev/null
	done
	sudo resolvconf -u
	if on_vpn_dns; then echo "Restored: resolv.conf on the VPN's DNS"; else echo "WARNING: resolv.conf is not on the VPN's DNS; run: sudo resolvconf -u"; fi
	[[ $fail == 0 ]] && echo "Result: all passed" || echo "Result: FAILURES above"
}
trap restore EXIT
trap 'exit 1' INT TERM HUP
(sleep 240 && echo "Watchdog: 240 s passed, restoring" && kill -TERM $$) &
wd=$!

echo "== 1. Port-53 counters on $dev; DNS to the router ($gw) while connected"
for t in iptables ip6tables; do
	command -v "$t" >/dev/null || continue
	{ sudo "$t" -t mangle -N DNSVAL &&
		sudo "$t" -t mangle -A DNSVAL -p udp --dport 53 &&
		sudo "$t" -t mangle -A DNSVAL -p tcp --dport 53 &&
		sudo "$t" -t mangle -I POSTROUTING -o "$dev" -j DNSVAL; } ||
		stop "could not add the $t counters (reboot after a kernel upgrade?)"
done
c0=$(counted)
t0=$(now_ms)
dig +time=3 +tries=1 "@$gw" example.com >/dev/null 2>&1 && bad "dig @$gw answered"
ms=$(($(now_ms) - t0))
((ms < 1500)) && ok "DNS to the router fails fast (${ms} ms)" ||
	bad "DNS to the router took ${ms} ms (DROP fallback? reboot)"
(($(counted) == c0)) && ok "0 port-53 packets left $dev" || bad "port-53 packets left $dev"
lookup "step 1"

echo "== 2. Drop-in removed: NetworkManager rewrites resolv.conf, the hook repairs it"
c0=$(counted)
sudo mv -T "$dropin" "$aside" && sudo nmcli general reload conf || stop "could not move the drop-in aside"
sudo nmcli general reload dns-full
saw_wrong=0 back_ms="" wrong_ns=""
t0=$(now_ms)
for _ in $(seq 30); do
	if on_vpn_dns; then
		[[ $saw_wrong == 1 && -z $back_ms ]] && back_ms=$(($(now_ms) - t0))
	else
		saw_wrong=1
		[[ -n $wrong_ns ]] || wrong_ns=$(cur_ns | head -1)
	fi
	sleep 0.1
done
if [[ $saw_wrong == 1 ]]; then
	echo "info: NetworkManager rewrote resolv.conf (nameserver ${wrong_ns:-none})"
	if [[ -n $wrong_ns ]]; then # what lookups met while resolv.conf was wrong
		t1=$(now_ms)
		dig +time=3 +tries=1 "@$wrong_ns" example.com >/dev/null 2>&1 && bad "the rewritten nameserver $wrong_ns answered"
		ms=$(($(now_ms) - t1))
		((ms < 1500)) && ok "lookups to $wrong_ns fail fast (${ms} ms)" || bad "lookups to $wrong_ns took ${ms} ms"
	fi
else
	echo "WARN: resolv.conf never looked wrong (repaired within 0.1 s, or not rewritten): step 2 tested little"
fi
on_vpn_dns && ok "resolv.conf on the VPN's DNS after 3 s${back_ms:+ (back after ${back_ms} ms)}" ||
	bad "resolv.conf still off the VPN's DNS after 3 s: $(cur_ns | tr '\n' ' ')"
[[ -n $back_ms ]] && ((back_ms > 2000)) && bad "repair took over 2 s"
(($(counted) == c0)) && ok "0 port-53 packets left $dev" || bad "port-53 packets left $dev"
sudo resolvconf -u
lookup "step 2"
sleep 10 # the hook allows 3 runs in 10 s; let that window pass

echo "== 3. Drop-in on: resolv.conf never changes"
sudo mv -T "$aside" "$dropin" && sudo nmcli general reload conf || stop "could not put the drop-in back"
sleep 3 # let NetworkManager hand its DNS to openresolv first
snap=$(cat /etc/resolv.conf)
changed=0
sudo nmcli general reload dns-full
for _ in $(seq 30); do
	[[ $(cat /etc/resolv.conf) == "$snap" ]] || changed=1
	sleep 0.1
done
[[ $changed == 0 ]] && ok "resolv.conf unchanged through reload dns-full" || bad "resolv.conf changed"
on_vpn_dns && ok "still on the VPN's DNS" || bad "off the VPN's DNS"
lookup "step 3"

echo "== 4. Kill switch on/off x guard on/off (only off/off may reach the router)"
for ks in on off; do
	for g in on off; do
		if [[ $ks == on ]]; then vpn-kill-switch enable >/dev/null; else vpn-kill-switch disable >/dev/null; fi
		vpn-kill-switch dns-guard "$g" >/dev/null
		lookup "kill switch $ks, guard $g"
		ok "kill switch $ks, guard $g: lookups work"
		c0=$(counted)
		leak_probe
		d=$(($(counted) - c0))
		if [[ $ks == off && $g == off ]]; then
			((d > 0)) && ok "  counter works: the probe reached $dev with both off" ||
				bad "  probe not counted with both off (counter broken?)"
		else
			((d == 0)) && ok "  probe blocked" || bad "  probe left $dev"
		fi
	done
done
vpn-kill-switch dns-guard on >/dev/null
[[ $(guard) == on ]] && ok "guard back on and first in OUTPUT" || bad "guard not on/first"
EOF
chmod 700 ~/dns-validation.sh && ~/dns-validation.sh
```

- [ ] Every line is `PASS:` or `info:`, and it ends with `Result: all passed`
      and `Restored: resolv.conf on the VPN's DNS`. A `WARN:` in step 2 means
      the rewrite wasn't seen; run the script again once.
- [ ] No `WARNING:` lines from the restore. If there are, run the command
      each one names.
- [ ] Afterwards: `vpn status` shows `DNS guard: on` and no DNS warning;
      `vpn kill-switch status` is as it was before;
      `ls -a /etc/NetworkManager/conf.d/` shows `protonvpn-manager-dns.conf`
      and no `.dnsval` file; `sudo iptables -t mangle -S | grep DNSVAL`
      prints nothing.

Step 4 sends one byte (no query) to the router's port 53 with the kill switch
and the guard both off. That's the check that the counter can see a packet at
all; the other three cases must count none. The probe is IPv4 only; the
counters also count IPv6, so any IPv6 DNS that leaves shows up too. The
counters see all port-53 traffic on the interface, so another program's DNS
could add to them; with the guard or kill switch on, that is blocked too.

Wifi re-activation is left out until #294 is fixed: it kills the tunnel.

### Step 5: disconnect

```bash
vpn disconnect
vpn-kill-switch dns-guard status
cat /etc/resolv.conf
getent hosts example.com
```

- [ ] The guard status is `off`, and `sudo iptables -S | grep VPN_DNS_GUARD`
      (and `ip6tables`) prints nothing.
- [ ] resolv.conf is back to the router (or `100.100.100.100` with Tailscale
      DNS), and the lookup works.
- [ ] With Tailscale: within about 10 s, MagicDNS works again:
      `getent hosts "$(tailscale status --json | jq -r .Self.DNSName)"`.

### Step 6: kill -9 (crash)

```bash
vpn connect se
sudo pkill -9 -x openvpn          # OpenVPN dies without cleaning up
sleep 2
vpn status
time getent hosts example.com
vpn cleanup
vpn-kill-switch dns-guard status
getent hosts example.com
```

- [ ] `vpn status` warns `DNS is blocked by a leftover DNS guard. Fix: vpn cleanup`.
- [ ] The lookup fails in about a second or less (rejected, not leaked).
- [ ] After `vpn cleanup`: the guard status is `off`, `resolvconf -l
      tun0.protonvpn` prints nothing, `vpn status` shows no DNS warning,
      and the lookup works.

### Step 7: a leftover guard removed by the hook (kill switch off)

Start with no VPN running (after step 6). With no VPN running, no VPN DNS entry and the kill switch off, the
`40-vpn-dns-repair` hook removes a leftover guard on the next DNS change:

```bash
vpn-kill-switch status              # must be DISABLED for this step
vpn-kill-switch dns-guard on        # a leftover guard, as after a resume
getent hosts example.com            # fails: DNS fails closed
sudo nmcli general reload dns-full
sleep 2
vpn-kill-switch dns-guard status
getent hosts example.com
```

- [ ] After the reload the guard status is `off` and the lookup works.

The same with the kill switch on: the guard must stay (fail closed). With no
VPN the kill switch blocks all traffic, so there is no internet until the
last line:

```bash
vpn-kill-switch enable --force      # no VPN: everything is blocked
vpn-kill-switch dns-guard on
sudo nmcli general reload dns-full
sleep 2
vpn-kill-switch dns-guard status    # still on
vpn-kill-switch disable && vpn-kill-switch dns-guard off
```

- [ ] The guard status after the reload is `on`; after the last line both
      are off and `getent hosts example.com` works.

Reconnect afterwards: `vpn connect se`.

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
journalctl -t vpn-dns-update -n 20     # needs a syslog daemon, see §10
journalctl -t vpn-dns-repair -n 20
cat /etc/resolv.conf
resolvconf -l
vpn-kill-switch dns-guard status
sudo iptables -S OUTPUT; sudo ip6tables -S OUTPUT
sudo iptables -S VPN_KILL_SWITCH 2>/dev/null
ls -l /etc/NetworkManager/conf.d/ /etc/NetworkManager/dispatcher.d/
```

Also say which step failed, and what you saw versus what was expected.

## Escape hatches

These go in `~/.config/vpn/config`, one per line.

| Setting | Effect |
|---|---|
| `DNS_MODE=none` | Don't touch DNS (and no warning) |
| `KILL_SWITCH_ALLOW_LAN_DNS=true` | Let DNS reach the router while the kill switch is on and the tunnel is down (leaks DNS). While connected the DNS guard still blocks it; see `BLOCK_DNS_LEAKS` |
| `BLOCK_DNS_LEAKS=false` | No DNS guard while connected: router and LAN-only names resolve again (leaks DNS) |
| `SERVER_SELECTION=random` | `vpn connect` picks a random server, as before |
| `FAILOVER_SERVERS=1` | No failover: retry the same server |
| `CONNECT_TIMEOUT=35` | Seconds to wait per server (5-300) |
| `ALLOW_PROFILE_SCRIPTS=true` | Allow `up`/`down`/… in profiles you trust |
| `BLOCK_IPV6=false` | Don't block IPv6 outside the tunnel while connected (leaks IPv6) |
| `TAILSCALE_DNS=keep` | Keep Tailscale's DNS while connected (leaks DNS; with the kill switch, no names resolve) |

To leave NetworkManager's DNS handling as it was: `./install.sh --no-nm-dns`
(or `./install.sh --uninstall-nm-dns` to undo only that part).

To go back to the version from before these changes:

```bash
git checkout 2465731 && ./install.sh   # master as of 2026-11-05
```

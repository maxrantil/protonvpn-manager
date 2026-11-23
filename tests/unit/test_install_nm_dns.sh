#!/bin/bash
# ABOUTME: Tests for install.sh's NetworkManager DNS setup: the rc-manager drop-in, the 40-vpn-dns-repair hook and their undo
# ABOUTME: install.sh's functions run against fake sudo, install, mv, nmcli, resolvconf, pgrep and ip, with every path in a sandbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$PROJECT_ROOT/install.sh"
REPO_DROPIN="$PROJECT_ROOT/etc/NetworkManager/conf.d/protonvpn-manager-dns.conf"
REPO_HOOK="$PROJECT_ROOT/etc/NetworkManager/dispatcher.d/40-vpn-dns-repair"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

T_GREEN='\033[1;32m'
T_RED='\033[1;31m'
T_BLUE='\033[1;34m'
T_NC='\033[0m'

test_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${T_GREEN}✓${T_NC} $1"
}

test_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
    echo -e "  ${T_RED}✗${T_NC} $1"
    [[ -n "${2:-}" ]] && echo -e "    $2"
}

# check <name> <detail> <command...>: passes when the command succeeds
check() {
    local name=$1 detail=$2
    shift 2
    if "$@"; then
        test_pass "$name"
    else
        test_fail "$name" "$detail"
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Sandbox: the fakes plus an allowlist of harmless tools. Nothing that
# touches DNS, NetworkManager, the network, processes or privileges is
# reachable; install and mv are faked so failures can be injected.
FAKES="$WORK/fakes"
SYSBIN="$WORK/sysbin"
STATE="$WORK/state"
mkdir -p "$FAKES" "$SYSBIN"
for tool in bash sh env sed grep cat cmp cp ls mkdir rm stat tr head tail cut chmod printf \
    dirname basename id touch sort wc true false; do
    [[ -x /usr/bin/$tool ]] && ln -s "/usr/bin/$tool" "$SYSBIN/$tool"
done

# sudo: records the command and runs it unprivileged from the sandbox PATH
cat > "$FAKES/sudo" << 'EOF'
#!/bin/bash
echo "sudo $*" >> "$STATE/calls"
exec "$@"
EOF
# install: fails when an argument contains the text in $STATE/install_fails;
# otherwise drops -o/-g (no root here) and runs the real install
cat > "$FAKES/install" << 'EOF'
#!/bin/bash
if [[ -s $STATE/install_fails ]]; then
    for a in "$@"; do [[ $a == *"$(cat "$STATE/install_fails")"* ]] && exit 1; done
fi
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o | -g) shift 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
exec /usr/bin/install "${args[@]}"
EOF
# mv: fails when an argument contains the text in $STATE/mv_fails
cat > "$FAKES/mv" << 'EOF'
#!/bin/bash
if [[ -s $STATE/mv_fails ]]; then
    for a in "$@"; do [[ $a == *"$(cat "$STATE/mv_fails")"* ]] && exit 1; done
fi
exec /usr/bin/mv "$@"
EOF
# nmcli: "-t general status" exits $STATE/nm_status_rc (default 0); reloads
# are recorded; "reload conf" exits $STATE/reload_rc and "reload dns-full"
# $STATE/dnsfull_rc (default 0)
cat > "$FAKES/nmcli" << 'EOF'
#!/bin/bash
case "$*" in
    "-t general status")
        rc=$(cat "$STATE/nm_status_rc" 2> /dev/null || echo 0)
        [[ $rc -eq 0 ]] && echo "connected:full"
        exit "$rc"
        ;;
    "general reload conf")
        echo "nmcli $*" >> "$STATE/calls"
        exit "$(cat "$STATE/reload_rc" 2> /dev/null || echo 0)"
        ;;
    "general reload dns-full")
        echo "nmcli $*" >> "$STATE/calls"
        exit "$(cat "$STATE/dnsfull_rc" 2> /dev/null || echo 0)"
        ;;
esac
echo "nmcli $*" >> "$STATE/calls"
exit 0
EOF
# resolvconf: --version prints $STATE/rc_version (missing: fails); -l
# tun0.protonvpn prints $STATE/entry when present; -u and -d are recorded
cat > "$FAKES/resolvconf" << 'EOF'
#!/bin/bash
case "$1" in
    --version)
        [[ -f $STATE/rc_version ]] || exit 1
        cat "$STATE/rc_version"
        exit 0
        ;;
    -l)
        [[ $2 == tun0.protonvpn && -f $STATE/entry ]] && cat "$STATE/entry"
        exit 0
        ;;
esac
echo "resolvconf $*" >> "$STATE/calls"
exit 0
EOF
# pgrep: exits $STATE/pgrep_rc (default 1: nothing runs)
cat > "$FAKES/pgrep" << 'EOF'
#!/bin/bash
echo "pgrep $*" >> "$STATE/calls"
exit "$(cat "$STATE/pgrep_rc" 2> /dev/null || echo 1)"
EOF
# ip: "-o link show dev tun0 up" prints a line when $STATE/tun0 exists
cat > "$FAKES/ip" << 'EOF'
#!/bin/bash
[[ "$*" == "-o link show dev tun0 up" && -e $STATE/tun0 ]] && echo "42: tun0: <UP> mtu 1500"
exit 0
EOF
chmod +x "$FAKES"/*
SANDBOX_PATH="$FAKES:$SYSBIN"

ETC="$WORK/etc/NetworkManager"
DROPIN="$ETC/conf.d/protonvpn-manager-dns.conf"
HOOK="$ETC/dispatcher.d/40-vpn-dns-repair"

# Fresh state: NetworkManager runs, openresolv, no systemd-resolved, plain
# resolv.conf, nothing installed, VPN not connected
reset_state() {
    rm -rf "${STATE:?}" "${WORK:?}/etc" "${WORK:?}/lib" "${WORK:?}/run" "${WORK:?}/resolv.conf"
    mkdir -p "$STATE" "$ETC/conf.d" "$ETC/dispatcher.d" "$WORK/lib/conf.d" "$WORK/run/conf.d"
    printf '[main]\nplugins=keyfile\n' > "$ETC/NetworkManager.conf"
    printf '[connectivity]\nenabled=false\n' > "$WORK/lib/conf.d/20-connectivity.conf"
    printf 'nameserver 192.168.50.1\n' > "$WORK/resolv.conf"
    echo "openresolv 3.17.4" > "$STATE/rc_version"
    touch "$STATE/calls"
}

# Run install.sh functions as the installer does, under set -e (a failure
# the code doesn't handle ends the run), from the project root, with its
# path constants pointed into the sandbox.
# $1: shell code run after sourcing (e.g. "install_nm_dns" or stubs + main).
# Prints the output, then "rc=<exit status>".
run_installer() {
    (
        cd "$PROJECT_ROOT" || exit 1
        env -i PATH="$SANDBOX_PATH" STATE="$STATE" WORK="$WORK" HOME="$WORK/home" \
            INSTALLER="$INSTALLER" CODE="$1" "$BASH" -c '
            # shellcheck disable=SC1090
            source <(sed -n "/^[a-z_]*() {\$/,/^}\$/p" "$INSTALLER")
            # shellcheck disable=SC1090
            source <(grep -E "^log_[a-z]+\(\) \{.*\}\$" "$INSTALLER")
            # shellcheck disable=SC1090
            source <(grep -E "^(NM_DNS_DROPIN|DNS_REPAIR_HOOK|VPN_DNS_ENTRY)=" "$INSTALLER")
            NM_CONF_DIR=$WORK/etc/NetworkManager/conf.d
            NM_MAIN_CONF=$WORK/etc/NetworkManager/NetworkManager.conf
            NM_OTHER_CONF_DIRS=("$WORK/lib/conf.d" "$WORK/run/conf.d")
            NM_DISPATCHER_DIR=$WORK/etc/NetworkManager/dispatcher.d
            RESOLV_CONF=$WORK/resolv.conf
            trap "echo rc=\$?" EXIT
            set -e
            eval "$CODE"
        ' 2>&1
    )
}

calls() { cat "$STATE/calls"; }
count_calls() { grep -cxF -- "$1" "$STATE/calls"; }
count_matching() { grep -cE -- "$1" "$STATE/calls"; }
# line number of the first call matching $1 (0 when absent)
call_line() { grep -nxF -- "$1" "$STATE/calls" | head -1 | cut -d: -f1 | grep . || echo 0; }
has_rc() { grep -qx "rc=$1" <<< "$2"; }

nothing_installed() {
    [[ ! -e $DROPIN && ! -e $HOOK ]] && ! grep -q 'reload' "$STATE/calls"
}
no_temp_files() {
    [[ -z $(find "$ETC" -name '.*' 2> /dev/null) ]]
}

# Assert a skip: rc 0, "Skipping ...: <reason>", nothing installed
expect_skip() {
    local name=$1 reason=$2 out
    out=$(run_installer install_nm_dns)
    check "$name: skipped with a message" "$out" \
        grep -qE "Skipping NetworkManager DNS setup: $reason" <<< "$out"
    check "$name: nothing installed, no reload" "$out; $(calls)" nothing_installed
    check "$name: the installer goes on (rc 0)" "$out" has_rc 0 "$out"
}

# === Sandbox ===

test_sandbox() {
    local t ok=1
    for t in nmcli resolvconf sudo install mv pgrep ip; do
        [[ $(PATH="$SANDBOX_PATH" command -v "$t") == "$FAKES/$t" ]] || ok=""
    done
    check "the sandbox resolves nmcli, resolvconf, sudo, install, mv, pgrep and ip to fakes" "" \
        test -n "$ok"
    ok=1
    for t in nmcli resolvconf sudo install mv pgrep ip systemctl sv tailscale wg-quick iptables \
        pkill killall nsenter unshare chattr openvpn; do
        PATH="$SYSBIN" command -v "$t" > /dev/null && ok=""
    done
    check "the sandbox's system tools reach nothing that touches DNS, the network or privileges" "" \
        test -n "$ok"
}

# === Repo files ===

test_repo_dropin() {
    check "the repo has the drop-in" "$REPO_DROPIN" test -f "$REPO_DROPIN"
    check "the drop-in starts with two ABOUTME lines" "$(head -2 "$REPO_DROPIN" 2> /dev/null)" \
        test "$(head -2 "$REPO_DROPIN" 2> /dev/null | grep -c '^# ABOUTME: ')" -eq 2
    check "the drop-in sets [main] rc-manager=resolvconf and nothing else" \
        "$(cat "$REPO_DROPIN" 2> /dev/null)" \
        test "$(grep -vE '^(#|$)' "$REPO_DROPIN" 2> /dev/null)" == $'[main]\nrc-manager=resolvconf'
}

test_installer_static() {
    check "install.sh never installs 50-vpn-reconnect (opt-in, by hand)" "" \
        bash -c '! grep -q "50-vpn-reconnect" "$1"' _ "$INSTALLER"
}

# === Skip conditions ===

test_skip_conditions() {
    reset_state
    echo 1 > "$STATE/nm_status_rc"
    expect_skip "NetworkManager not running" "NetworkManager is not running"

    reset_state
    mv "$FAKES/nmcli" "$FAKES/nmcli.off"
    expect_skip "no nmcli" "NetworkManager is not running"
    mv "$FAKES/nmcli.off" "$FAKES/nmcli"

    reset_state
    echo "resolvconf 1.91" > "$STATE/rc_version"
    expect_skip "resolvconf is not openresolv" "resolvconf is not openresolv"

    reset_state
    rm -f "$STATE/rc_version"
    expect_skip "no resolvconf" "resolvconf is not openresolv"

    reset_state
    echo 0 > "$STATE/pgrep_rc"
    expect_skip "systemd-resolved running" "systemd-resolved is running"
    check "systemd-resolved is looked up as systemd-resolve (15-char process name)" "$(calls)" \
        test "$(count_calls "pgrep -x systemd-resolve")" -eq 1

    reset_state
    rm "$WORK/resolv.conf"
    ln -s /run/somewhere/resolv.conf "$WORK/resolv.conf"
    expect_skip "resolv.conf a symlink" ".*/resolv\.conf is a symlink"

    reset_state
    rm -rf "$ETC/conf.d"
    mkdir -p "$WORK/elsewhere"
    ln -s "$WORK/elsewhere" "$ETC/conf.d"
    expect_skip "conf.d a symlink" ".*/conf\.d is a symlink"
    check "conf.d a symlink: nothing written through it" "" \
        test -z "$(ls -A "$WORK/elsewhere")"

    reset_state
    rm -rf "$ETC/dispatcher.d" "$WORK/elsewhere"
    mkdir -p "$WORK/elsewhere"
    ln -s "$WORK/elsewhere" "$ETC/dispatcher.d"
    expect_skip "dispatcher.d a symlink" ".*/dispatcher\.d is a symlink"
    check "dispatcher.d a symlink: nothing written through it" "" \
        test -z "$(ls -A "$WORK/elsewhere")"

    reset_state
    printf '[main]\nrc-manager=symlink\n' > "$ETC/NetworkManager.conf"
    expect_skip "rc-manager in NetworkManager.conf" "rc-manager is already set in .*/NetworkManager\.conf"

    reset_state
    printf '[main]\n  rc-manager = file\n' > "$ETC/conf.d/90-mine.conf"
    expect_skip "rc-manager in another conf.d file" "rc-manager is already set in .*/90-mine\.conf"

    reset_state
    printf '[main]\nrc-manager=symlink\n' > "$WORK/lib/conf.d/10-distro.conf"
    expect_skip "rc-manager in the distribution's conf.d" "rc-manager is already set in .*/lib/conf\.d/10-distro\.conf"

    reset_state
    printf '[main]\nrc-manager=unmanaged\n' > "$WORK/run/conf.d/10-tool.conf"
    expect_skip "rc-manager in the runtime conf.d" "rc-manager is already set in .*/run/conf\.d/10-tool\.conf"

    # dns=none: the user manages resolv.conf, so NetworkManager hands nothing on
    reset_state
    printf '[main]\ndns=none\n' > "$ETC/NetworkManager.conf"
    expect_skip "dns=none in NetworkManager.conf" "dns=none is set in .*/NetworkManager\.conf"

    reset_state
    printf '[main]\n  dns = none\n' > "$ETC/conf.d/90-mine.conf"
    expect_skip "dns=none in a conf.d file" "dns=none is set in .*/90-mine\.conf"

    # Could hide an rc-manager; root reads it fine, so only test unprivileged
    if [[ $EUID -ne 0 ]]; then
        reset_state
        printf '[main]\nrc-manager=file\n' > "$ETC/conf.d/90-private.conf"
        chmod 000 "$ETC/conf.d/90-private.conf"
        expect_skip "an unreadable conf.d file" "cannot read .*/90-private\.conf"
        chmod 600 "$ETC/conf.d/90-private.conf"
    else
        echo "  - skipped as root: an unreadable conf.d file"
    fi
}

test_not_skipped() {
    local out
    reset_state
    printf '[main]\n#rc-manager=symlink\n' > "$ETC/NetworkManager.conf"
    out=$(run_installer install_nm_dns)
    check "a commented-out rc-manager is not a skip" "$out" test -f "$DROPIN"

    reset_state
    printf '[main]\ndns=default\n#dns=none\n' > "$ETC/NetworkManager.conf"
    out=$(run_installer install_nm_dns)
    check "dns=default (or a commented-out dns=none) is not a skip" "$out" test -f "$DROPIN"

    reset_state
    printf '[main]\nrc-manager=resolvconf\n' > "$DROPIN"
    out=$(run_installer install_nm_dns)
    check "this tool's own drop-in is not a foreign rc-manager" "$out" \
        bash -c '! grep -q Skipping <<< "$1"' _ "$out"

    reset_state
    rm -rf "$ETC/conf.d"
    out=$(run_installer install_nm_dns)
    check "a missing conf.d is created" "$out" test -f "$DROPIN"

    reset_state
    rm -rf "$ETC/dispatcher.d"
    out=$(run_installer install_nm_dns)
    check "a missing dispatcher.d is created" "$out" test -f "$HOOK"
}

# === Install ===

test_install() {
    local out mode
    reset_state
    out=$(run_installer install_nm_dns)
    check "install: rc 0" "$out" has_rc 0 "$out"
    check "install: the drop-in matches the repo file" "$out" cmp -s "$REPO_DROPIN" "$DROPIN"
    mode=$(stat -c %a "$DROPIN" 2> /dev/null)
    check "install: the drop-in is mode 644" "mode $mode" test "$mode" = 644
    check "install: the drop-in is written as root:root 644 to a temp name, then moved" "$(calls)" \
        bash -c 'grep -qE "^sudo install -T -o root -g root -m 644 .*/protonvpn-manager-dns\.conf .*/conf\.d/\.[^/ ]+$" "$1" &&
            grep -qE "^sudo mv -T .*/conf\.d/\.[^/ ]+ .*/conf\.d/protonvpn-manager-dns\.conf$" "$1"' _ "$STATE/calls"
    check "install: the hook matches the repo file" "$out" cmp -s "$REPO_HOOK" "$HOOK"
    mode=$(stat -c %a "$HOOK" 2> /dev/null)
    check "install: the hook is mode 755" "mode $mode" test "$mode" = 755
    check "install: the hook is written as root:root 755 to a temp name, then moved" "$(calls)" \
        bash -c 'grep -qE "^sudo install -T -o root -g root -m 755 .*/40-vpn-dns-repair .*/dispatcher\.d/\.[^/ ]+$" "$1" &&
            grep -qE "^sudo mv -T .*/dispatcher\.d/\.[^/ ]+ .*/dispatcher\.d/40-vpn-dns-repair$" "$1"' _ "$STATE/calls"
    check "install: no temp file is left behind" "$(find "$ETC" -name '.*')" no_temp_files
    check "install: NetworkManager reloads its config once" "$(calls)" \
        test "$(count_calls "sudo nmcli general reload conf")" -eq 1
    check "install: not connected, no resolvconf -u" "$(calls)" \
        test "$(count_calls "sudo resolvconf -u")" -eq 0
    check "install: says how to undo it" "$out" grep -q -- '--uninstall-nm-dns' <<< "$out"
}

test_install_connected() {
    local out
    reset_state
    printf 'nameserver 10.96.0.1\n' > "$STATE/entry"
    out=$(run_installer install_nm_dns)
    check "connected: NetworkManager reloads its config once" "$(calls)" \
        test "$(count_calls "sudo nmcli general reload conf")" -eq 1
    check "connected: one resolvconf -u" "$(calls)" \
        test "$(count_calls "sudo resolvconf -u")" -eq 1
    check "connected: resolvconf -u comes after the reload" "$(calls)" \
        test "$(call_line "sudo resolvconf -u")" -gt "$(call_line "sudo nmcli general reload conf")"
    check "connected: the VPN's entry is read as root" "$(calls)" \
        test "$(count_calls "sudo resolvconf -l tun0.protonvpn")" -ge 1
}

test_install_idempotent() {
    local out before
    reset_state
    run_installer install_nm_dns > /dev/null
    before=$(stat -c %Y.%i "$DROPIN")
    : > "$STATE/calls"
    out=$(run_installer install_nm_dns)
    check "re-run: rc 0" "$out" has_rc 0 "$out"
    check "re-run: same content, no reload" "$(calls)" \
        test "$(count_calls "sudo nmcli general reload conf")" -eq 0
    check "re-run: the drop-in is not written" "$(calls)" \
        test "$(count_matching '^sudo (install|mv) .*protonvpn-manager-dns')" -eq 0
    check "re-run: the drop-in keeps its inode and mtime" "$before vs $(stat -c %Y.%i "$DROPIN")" \
        test "$before" = "$(stat -c %Y.%i "$DROPIN")"

    # The hook is checked on its own: a changed hook is put back
    echo "# changed" >> "$HOOK"
    out=$(run_installer install_nm_dns)
    check "re-run with a changed hook: the hook is reinstalled" "$out" cmp -s "$REPO_HOOK" "$HOOK"

    # A drop-in with other content is replaced and reloaded
    printf '[main]\nrc-manager=resolvconf\n' > "$DROPIN"
    : > "$STATE/calls"
    run_installer install_nm_dns > /dev/null
    check "changed drop-in: rewritten and reloaded" "$(calls)" \
        bash -c 'cmp -s "$1" "$2" && grep -qx "sudo nmcli general reload conf" "$3"' _ \
        "$REPO_DROPIN" "$DROPIN" "$STATE/calls"
    check "changed drop-in: no backup left behind" "$(find "$ETC" -name '.*')" no_temp_files
}

test_install_reload_fails() {
    local out
    reset_state
    echo 1 > "$STATE/reload_rc"
    printf 'nameserver 10.96.0.1\n' > "$STATE/entry"
    out=$(run_installer install_nm_dns)
    check "reload fails: the drop-in is removed again" "$out" test ! -e "$DROPIN"
    check "reload fails: a warning" "$out" grep -q 'WARNING.*did not reload' <<< "$out"
    check "reload fails: the installer goes on (rc 0)" "$out" has_rc 0 "$out"
    check "reload fails: no resolvconf -u" "$(calls)" \
        test "$(count_calls "sudo resolvconf -u")" -eq 0
    check "reload fails: no temp file is left behind" "$(find "$ETC" -name '.*')" no_temp_files
    check "reload fails: the hook stays (on its own it only repairs while connected)" "$out" \
        cmp -s "$REPO_HOOK" "$HOOK"

    # Replacing an older drop-in of ours: the older one is put back
    reset_state
    printf '[main]\nrc-manager=resolvconf\n' > "$DROPIN"
    echo 1 > "$STATE/reload_rc"
    out=$(run_installer install_nm_dns)
    check "reload fails over an older drop-in: the older one is restored" "$(cat "$DROPIN" 2> /dev/null)" \
        test "$(cat "$DROPIN" 2> /dev/null)" = $'[main]\nrc-manager=resolvconf'
    check "reload fails over an older drop-in: no backup left behind" "$(find "$ETC" -name '.*')" \
        no_temp_files
}

# Failures the installer can't fix must not end it (set -e) or leave temp files
test_install_write_failures() {
    local out
    reset_state
    echo "40-vpn-dns-repair" > "$STATE/install_fails"
    out=$(run_installer 'install_nm_dns; echo after')
    check "hook install fails: a warning, and the installer goes on" "$out" \
        bash -c 'grep -q "WARNING" <<< "$1" && grep -qx after <<< "$1"' _ "$out"
    check "hook install fails: no drop-in without its hook, no reload" "$(calls)" nothing_installed
    check "hook install fails: no temp file is left behind" "$(find "$ETC" -name '.*')" no_temp_files

    reset_state
    echo ".protonvpn-manager-dns.conf" > "$STATE/install_fails"
    out=$(run_installer 'install_nm_dns; echo after')
    check "drop-in temp write fails: a warning, and the installer goes on" "$out" \
        bash -c 'grep -q "WARNING.*Could not write" <<< "$1" && grep -qx after <<< "$1"' _ "$out"
    check "drop-in temp write fails: no drop-in, no reload" "$(calls)" \
        bash -c '[[ ! -e $1 ]] && ! grep -q reload "$2"' _ "$DROPIN" "$STATE/calls"
    check "drop-in temp write fails: no temp file is left behind" "$(find "$ETC" -name '.*')" \
        no_temp_files

    reset_state
    printf '[main]\nrc-manager=resolvconf\n' > "$DROPIN"
    echo ".protonvpn-manager-dns.conf.tmp" > "$STATE/mv_fails"
    out=$(run_installer 'install_nm_dns; echo after')
    check "drop-in rename fails: a warning, and the installer goes on" "$out" \
        bash -c 'grep -q "WARNING.*Could not write" <<< "$1" && grep -qx after <<< "$1"' _ "$out"
    check "drop-in rename fails: the older drop-in is untouched, no reload" "$(calls)" \
        bash -c '[[ $(cat "$1") == $'"'"'[main]\nrc-manager=resolvconf'"'"' ]] && ! grep -q reload "$2"' _ \
        "$DROPIN" "$STATE/calls"
    check "drop-in rename fails: no temp file is left behind" "$(find "$ETC" -name '.*')" \
        no_temp_files

    reset_state
    rm -rf "$ETC/conf.d"
    echo "conf.d" > "$STATE/install_fails"
    out=$(run_installer 'install_nm_dns; echo after')
    check "creating conf.d fails: a warning, and the installer goes on" "$out" \
        bash -c 'grep -q "WARNING" <<< "$1" && grep -qx after <<< "$1"' _ "$out"
}

# === Uninstall ===

test_uninstall() {
    local out
    reset_state
    run_installer install_nm_dns > /dev/null
    printf 'nameserver 10.96.0.1\n' > "$STATE/entry"
    : > "$STATE/calls"
    out=$(run_installer uninstall_nm_dns)
    check "uninstall: rc 0" "$out" has_rc 0 "$out"
    check "uninstall: the drop-in is removed" "$out" test ! -e "$DROPIN"
    check "uninstall: the hook is removed" "$out" test ! -e "$HOOK"
    check "uninstall: remove, reload, NetworkManager's entry, then -u (connected)" "$(calls)" \
        bash -c '[[ $1 -gt 0 && $2 -gt $1 && $3 -gt $2 && $4 -gt $3 ]]' _ \
        "$(call_line "sudo rm -f $DROPIN $HOOK")" \
        "$(call_line "sudo nmcli general reload conf")" \
        "$(call_line "sudo resolvconf -f -d NetworkManager")" \
        "$(call_line "sudo resolvconf -u")"
    check "uninstall connected: no dns-full (the VPN's DNS stays)" "$(calls)" \
        test "$(count_calls "sudo nmcli general reload dns-full")" -eq 0
}

# Disconnected, openresolv has no entry left after NetworkManager's goes:
# -u would write a resolv.conf with no nameserver, so NetworkManager writes
# its own DNS back instead
test_uninstall_disconnected() {
    local out
    reset_state
    run_installer install_nm_dns > /dev/null
    : > "$STATE/calls"
    out=$(run_installer uninstall_nm_dns)
    check "uninstall disconnected: no resolvconf -u" "$(calls)" \
        test "$(count_calls "sudo resolvconf -u")" -eq 0
    check "uninstall disconnected: NetworkManager rewrites DNS after its entry is dropped" "$(calls)" \
        bash -c '[[ $1 -gt 0 && $2 -gt $1 ]]' _ \
        "$(call_line "sudo resolvconf -f -d NetworkManager")" \
        "$(call_line "sudo nmcli general reload dns-full")"

    reset_state
    run_installer install_nm_dns > /dev/null
    echo 1 > "$STATE/dnsfull_rc"
    out=$(run_installer uninstall_nm_dns)
    check "uninstall, dns-full fails: a warning with the fix, rc 0" "$out" \
        bash -c 'grep -q "WARNING.*nmcli general reload dns-full" <<< "$1" && grep -qx rc=0 <<< "$1"' _ "$out"
}

# tun0 up without a readable VPN entry: neither -u (no entry to rebuild
# from) nor dns-full (NetworkManager's DNS would replace the VPN's)
test_uninstall_tunnel_unconfirmed() {
    local out
    reset_state
    run_installer install_nm_dns > /dev/null
    touch "$STATE/tun0"
    : > "$STATE/calls"
    out=$(run_installer uninstall_nm_dns)
    check "tun0 up, no entry: no dns-full, no -u, NetworkManager's entry kept" "$(calls)" \
        bash -c '! grep -qE "dns-full|resolvconf -u|resolvconf -f -d" "$1"' _ "$STATE/calls"
    check "tun0 up, no entry: a warning with the fix, rc 0" "$out" \
        bash -c 'grep -q "WARNING.*resolvconf" <<< "$1" && grep -qx rc=0 <<< "$1"' _ "$out"
}

test_uninstall_edge_cases() {
    local out
    reset_state
    out=$(run_installer uninstall_nm_dns)
    check "uninstall with nothing installed: rc 0" "$out" has_rc 0 "$out"
    check "uninstall with nothing installed: NetworkManager and resolvconf untouched" "$(calls)" \
        bash -c '! grep -qE "nmcli|resolvconf" "$1"' _ "$STATE/calls"

    reset_state
    run_installer install_nm_dns > /dev/null
    echo 1 > "$STATE/reload_rc"
    : > "$STATE/calls"
    out=$(run_installer uninstall_nm_dns)
    check "uninstall, reload fails: files still removed, rc 0" "$out" \
        bash -c '[[ ! -e $1 && ! -e $2 ]] && grep -qx "rc=0" <<< "$3"' _ "$DROPIN" "$HOOK" "$out"
    check "uninstall, reload fails: a warning" "$out" grep -q 'WARNING.*did not reload' <<< "$out"
    check "uninstall, reload fails: resolvconf untouched" "$(calls)" \
        bash -c '! grep -qE "resolvconf -(u|f)|dns-full" "$1"' _ "$STATE/calls"

    reset_state
    run_installer install_nm_dns > /dev/null
    mv "$FAKES/nmcli" "$FAKES/nmcli.off"
    rm -f "$STATE/rc_version"
    mv "$FAKES/resolvconf" "$FAKES/resolvconf.off"
    out=$(run_installer uninstall_nm_dns)
    mv "$FAKES/nmcli.off" "$FAKES/nmcli"
    mv "$FAKES/resolvconf.off" "$FAKES/resolvconf"
    check "uninstall without nmcli or resolvconf: files removed, rc 0" "$out" \
        bash -c '[[ ! -e $1 && ! -e $2 ]] && grep -qx "rc=0" <<< "$3"' _ "$DROPIN" "$HOOK" "$out"
}

# === Options (main) ===

# Stubs for the install steps main runs; each records its name
STUBS='
for f in check_dependencies install_components install_dns_helper install_nm_dns \
    uninstall_nm_dns setup_system_config setup_config; do
    eval "$f() { echo $f >> \"\$STATE/steps\"; }"
done
'

steps() { [[ -f $STATE/steps ]] && tr '\n' ' ' < "$STATE/steps"; }

test_main_options() {
    local out
    reset_state
    out=$(run_installer "$STUBS main")
    check "no option: the NetworkManager DNS setup runs after the DNS helper" "$(steps)" \
        test "$(steps)" = "check_dependencies install_components install_dns_helper install_nm_dns setup_system_config setup_config "

    reset_state
    out=$(run_installer "$STUBS main --no-nm-dns")
    check "--no-nm-dns: everything else installs, and the undo runs" "$(steps)" \
        test "$(steps)" = "check_dependencies install_components install_dns_helper uninstall_nm_dns setup_system_config setup_config "

    reset_state
    out=$(run_installer "$STUBS main --uninstall-nm-dns")
    check "--uninstall-nm-dns: only the undo runs" "$(steps)" \
        test "$(steps)" = "uninstall_nm_dns "
    check "--uninstall-nm-dns: rc 0 and a closing line" "$out" \
        bash -c 'grep -qx rc=0 <<< "$1" && grep -qi "undone" <<< "$1"' _ "$out"

    reset_state
    out=$(run_installer "$STUBS main --help")
    check "--help: usage, rc 0, nothing run" "$out" \
        bash -c 'grep -q "Usage:" <<< "$1" && grep -qx rc=0 <<< "$1" && [[ -z $2 ]]' _ "$out" "$(steps)"

    reset_state
    out=$(run_installer "$STUBS main --bogus")
    check "unknown option: rc 1 with nothing run" "$out; $(steps)" \
        bash -c 'grep -qx rc=1 <<< "$1" && [[ -z $2 ]]' _ "$out" "$(steps)"
    check "unknown option: names the option" "$out" grep -q -- 'Unknown option: --bogus' <<< "$out"
    out=$(run_installer "$STUBS main --bogus 2> /dev/null")
    check "unknown option: the usage goes to stderr" "$out" \
        bash -c '! grep -q "Usage:" <<< "$1"' _ "$out"

    reset_state
    out=$(run_installer "$STUBS main --no-nm-dns --uninstall-nm-dns")
    check "two options: rc 1 with nothing run" "$out; $(steps)" \
        bash -c 'grep -qx rc=1 <<< "$1" && [[ -z $2 ]]' _ "$out" "$(steps)"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}install.sh NetworkManager DNS Tests${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_sandbox
test_repo_dropin
test_installer_static
test_skip_conditions
test_not_skipped
test_install
test_install_connected
test_install_idempotent
test_install_reload_fails
test_install_write_failures
test_uninstall
test_uninstall_disconnected
test_uninstall_tunnel_unconfirmed
test_uninstall_edge_cases
test_main_options

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed tests:"
    printf '  - %s\n' "${FAILED_TESTS[@]}"
    exit 1
fi
exit 0

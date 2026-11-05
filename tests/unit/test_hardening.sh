#!/bin/bash
# ABOUTME: Behavioural regression tests for the security/robustness hardening pass
# ABOUTME: Covers set -e exit-code handling, log spoofing, profile directive checks, cleanup and hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

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

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Isolated environment for every sourced/executed script
export HOME="$WORK_DIR/home"
export XDG_RUNTIME_DIR="$WORK_DIR/run"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export VPN_LOG_DIR="$XDG_STATE_HOME/vpn"
mkdir -p "$HOME/.config/vpn/locations" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Hardening Regression Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

# ---------------------------------------------------------------------------
# 1. `vpn connect` must auto-clean when health reports multiple processes.
#    Previously `set -e` aborted the script on the non-zero health exit code.
# ---------------------------------------------------------------------------
test_connect_runs_cleanup_on_unhealthy() {
	local stub_dir="$WORK_DIR/stub_bin"
	mkdir -p "$stub_dir"
	cp "$SRC_DIR/vpn" "$SRC_DIR/vpn-error-handler" "$SRC_DIR/vpn-colors" "$SRC_DIR/vpn-utils" "$stub_dir/"
	cat > "$stub_dir/vpn-manager" << 'EOF'
#!/bin/bash
echo "manager:$1" >> "$(dirname "$0")/calls.log"
[[ $1 == health ]] && exit 1
exit 0
EOF
	cat > "$stub_dir/vpn-connector" << 'EOF'
#!/bin/bash
echo "connector:$*" >> "$(dirname "$0")/calls.log"
EOF
	chmod +x "$stub_dir"/*
	: > "$stub_dir/calls.log"

	# Only meaningful in dev mode (installed copies would be picked up instead)
	if [[ -f /usr/local/bin/vpn-manager && -f /usr/local/bin/vpn-error-handler ]]; then
		test_pass "connect auto-cleanup (skipped: installed copy present)"
		return
	fi

	bash "$stub_dir/vpn" connect se > /dev/null 2>&1
	if grep -q "manager:cleanup" "$stub_dir/calls.log" && grep -q "connector:connect se" "$stub_dir/calls.log"; then
		test_pass "vpn connect runs cleanup then connects when health reports multiple processes"
	else
		test_fail "vpn connect runs cleanup then connects when health reports multiple processes" \
			"calls: $(tr '\n' ' ' < "$stub_dir/calls.log")"
	fi
}

# Helper: source vpn-connector in a subshell-friendly way
source_connector() {
	# shellcheck disable=SC1091
	source "$SRC_DIR/vpn-connector" > /dev/null 2>&1
	set +e
}

# ---------------------------------------------------------------------------
# 2. A timed-out attempt must lead to a retry, not an abort (set -e bug).
# ---------------------------------------------------------------------------
test_connect_retries_after_timeout() {
	local result
	result=$(
		source_connector
		set -euo pipefail
		validate_connection_prerequisites() { return 0; }
		initialize_connection_attempt() { echo "prof"; }
		start_openvpn_daemon() { return 0; }
		cleanup_failed_connection_processes() { return 0; }
		notify_event() { :; }
		sleep() { :; }
		attempts=0
		monitor_connection_establishment_with_backoff() {
			attempts=$((attempts + 1))
			echo "ATTEMPT" >&2
			return 2
		}
		connect_openvpn_profile "/x.ovpn" 3 2>&1 > /dev/null || true
	)
	local count
	count=$(grep -c "ATTEMPT" <<< "$result")
	if [[ $count -eq 3 ]]; then
		test_pass "connect retries all attempts after a timeout"
	else
		test_fail "connect retries all attempts after a timeout" "attempts made: $count (expected 3)"
	fi
}

# ---------------------------------------------------------------------------
# 3. Connection success must not be spoofable through a shared /tmp file.
# ---------------------------------------------------------------------------
test_tmp_log_cannot_spoof_success() {
	local result
	result=$(
		source_connector
		rm -f "$LOG_DIR/openvpn.log"
		: > "$LOG_DIR/openvpn.log"
		check_connection_progress "initializing" 0
	)
	if grep -rq '/tmp/openvpn.log' "$SRC_DIR/vpn-connector"; then
		test_fail "connector never reads /tmp/openvpn.log" "reference to /tmp/openvpn.log still present"
	elif [[ $result == "in_progress" ]]; then
		test_pass "connector never reads /tmp/openvpn.log"
	else
		test_fail "connector never reads /tmp/openvpn.log" "status was '$result' with an empty private log"
	fi

	result=$(
		source_connector
		echo "Initialization Sequence Completed" > "$LOG_DIR/openvpn.log"
		check_connection_progress "initializing" 0
	)
	if [[ $result == "connected" ]]; then
		test_pass "private OpenVPN log success line is detected"
	else
		test_fail "private OpenVPN log success line is detected" "got '$result'"
	fi
}

# ---------------------------------------------------------------------------
# 4. Stage tracking works without eval (state owned by caller).
# ---------------------------------------------------------------------------
test_progress_stage_transitions() {
	local r1 r2
	r1=$(
		source_connector
		echo "Peer Connection Initiated" > "$LOG_DIR/openvpn.log"
		check_connection_progress "initializing" 0
	)
	r2=$(
		source_connector
		echo "Peer Connection Initiated" > "$LOG_DIR/openvpn.log"
		check_connection_progress "configuring" 2
	)
	if [[ $r1 == "configuring" && $r2 == "verifying" ]]; then
		test_pass "connection stage transitions (configuring -> verifying)"
	else
		test_fail "connection stage transitions (configuring -> verifying)" "got '$r1' then '$r2'"
	fi
	if grep -qE '(^|[^a-z])eval ' "$SRC_DIR/vpn-connector"; then
		test_fail "vpn-connector contains no eval"
	else
		test_pass "vpn-connector contains no eval"
	fi
}

# ---------------------------------------------------------------------------
# 5. Profiles that would run commands / write files as root are rejected.
# ---------------------------------------------------------------------------
test_profile_content_validation() {
	local d="$WORK_DIR/profiles"
	mkdir -p "$d"
	printf 'client\ndev tun\nremote 1.2.3.4 1194\nauth-user-pass\n# up /etc/openvpn/update-resolv-conf\n<ca>\nup AAAA\n</ca>\n' > "$d/ok.ovpn"
	printf 'client\nscript-security 2\nup /bin/evil\n' > "$d/up.ovpn"
	printf 'client\nplugin /tmp/x.so\n' > "$d/plugin.ovpn"
	printf 'client\n--log /etc/passwd\n' > "$d/log.ovpn"
	printf '[Interface]\nPrivateKey = k\nPostUp = id\n[Peer]\n' > "$d/hook.conf"
	printf '[Interface]\nPrivateKey = k\n[Peer]\nEndpoint = 1.2.3.4:51820\n' > "$d/ok.conf"

	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		validate_profile_content "$d/ok.ovpn" 2> /dev/null
	) && test_pass "stock-style .ovpn profile accepted" || test_fail "stock-style .ovpn profile accepted"
	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		validate_profile_content "$d/ok.conf" 2> /dev/null
	) && test_pass "plain WireGuard profile accepted" || test_fail "plain WireGuard profile accepted"

	local f
	for f in up.ovpn plugin.ovpn log.ovpn hook.conf; do
		if (
			# shellcheck disable=SC1091
			source "$SRC_DIR/vpn-validators"
			validate_profile_content "$d/$f" 2> /dev/null
		); then
			test_fail "dangerous profile rejected: $f"
		else
			test_pass "dangerous profile rejected: $f"
		fi
	done

	# Explicit opt-in allows it
	echo "ALLOW_PROFILE_SCRIPTS=true" > "$XDG_CONFIG_HOME/vpn/config"
	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		validate_profile_content "$d/up.ovpn" 2> /dev/null
	) && test_pass "ALLOW_PROFILE_SCRIPTS=true opts in" || test_fail "ALLOW_PROFILE_SCRIPTS=true opts in"
	rm -f "$XDG_CONFIG_HOME/vpn/config"
}

# ---------------------------------------------------------------------------
# 6. OpenVPN is started with --script-security 1 and our private log.
# ---------------------------------------------------------------------------
test_openvpn_invocation() {
	local args
	args=$(
		source_connector
		sudo() { printf '%s\n' "$@"; }
		start_openvpn_daemon "/p.ovpn"
	)
	if grep -qx -- "--script-security" <<< "$args" && grep -A1 -x -- "--script-security" <<< "$args" | grep -qx 1; then
		test_pass "openvpn started with --script-security 1"
	else
		test_fail "openvpn started with --script-security 1" "args: $(tr '\n' ' ' <<< "$args")"
	fi
	if grep -q "^/tmp/openvpn" <<< "$args"; then
		test_fail "openvpn invocation uses no /tmp paths"
	else
		test_pass "openvpn invocation uses no /tmp paths"
	fi
}

# ---------------------------------------------------------------------------
# 7. Cleanup must not delete a lock file that is currently held.
# ---------------------------------------------------------------------------
test_cleanup_keeps_held_lock() {
	local lock_dir="$XDG_RUNTIME_DIR/vpn"
	mkdir -p "$lock_dir" && chmod 700 "$lock_dir"
	local lock="$lock_dir/vpn_connect.lock"
	(
		exec 200> "$lock"
		flock -n 200
		sleep 5
	) &
	local holder=$!
	sleep 0.3
	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-manager" > /dev/null 2>&1
		set +e
		sudo() { :; }
		cleanup_files
	)
	if [[ -f $lock ]]; then
		test_pass "cleanup keeps a lock file that is held"
	else
		test_fail "cleanup keeps a lock file that is held"
	fi
	kill "$holder" 2> /dev/null
	wait "$holder" 2> /dev/null
	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-manager" > /dev/null 2>&1
		set +e
		sudo() { :; }
		cleanup_files
	)
	if [[ -f $lock ]]; then
		test_fail "cleanup removes a stale lock file"
	else
		test_pass "cleanup removes a stale lock file"
	fi
}

# ---------------------------------------------------------------------------
# 8. Process matching: only real openvpn command lines, never lookalikes.
# ---------------------------------------------------------------------------
test_process_matching() {
	bash -c 'exec -a "openvpn --config /x/se-1.ovpn --daemon" sleep 30' &
	local fake=$!
	bash -c 'exec -a "grep openvpn --config" sleep 30' &
	local grep_like=$!
	bash -c 'exec -a "less /var/log/openvpn --config" sleep 30' &
	local less_like=$!
	sleep 0.3

	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		validate_openvpn_process "$fake"
	) && test_pass "openvpn command line is recognised" || test_fail "openvpn command line is recognised"

	local p
	for p in "$grep_like" "$less_like"; do
		if (
			# shellcheck disable=SC1091
			source "$SRC_DIR/vpn-validators"
			validate_openvpn_process "$p"
		); then
			test_fail "lookalike process not matched: $(ps -p "$p" -o args=)"
		else
			test_pass "lookalike process not matched: $(ps -p "$p" -o args=)"
		fi
	done

	if (
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		is_real_openvpn_process "$fake"
	); then
		test_fail "forged argv does not qualify for sudo escalation"
	else
		test_pass "forged argv does not qualify for sudo escalation"
	fi

	local found
	found=$(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-validators"
		find_openvpn_pids
	)
	if [[ $found == "$fake" ]]; then
		test_pass "find_openvpn_pids returns only the daemon"
	else
		test_fail "find_openvpn_pids returns only the daemon" "got: $(tr '\n' ' ' <<< "$found")"
	fi

	kill "$fake" "$grep_like" "$less_like" 2> /dev/null
	wait 2> /dev/null
}

# ---------------------------------------------------------------------------
# 9. A stale PID file pointing at an unrelated process is ignored.
# ---------------------------------------------------------------------------
test_stale_pid_file_ignored() {
	sleep 30 &
	local victim=$!
	echo "$victim" > "$WORK_DIR/openvpn.pid"
	local got
	got=$(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-manager" > /dev/null 2>&1
		set +e
		# shellcheck disable=SC2034  # read by get_vpn_pid
		VPN_PID_FILE="$WORK_DIR/openvpn.pid"
		pgrep() { return 1; }
		get_vpn_pid
	)
	if [[ -z $got ]]; then
		test_pass "stale PID file (reused PID) is not treated as the VPN"
	else
		test_fail "stale PID file (reused PID) is not treated as the VPN" "got pid $got"
	fi
	kill "$victim" 2> /dev/null
	wait "$victim" 2> /dev/null
}

# ---------------------------------------------------------------------------
# 10. Cleanup terminates with TERM promptly (no fixed multi-second sleeps).
# ---------------------------------------------------------------------------
test_cleanup_fast_and_graceful() {
	local marker="$WORK_DIR/term_received"
	rm -f "$marker"
	# Fake daemon: records TERM, then exits
	bash -c "exec -a 'openvpn --config /x/se-2.ovpn' bash -c 'trap \"touch $marker; exit 0\" TERM; while :; do sleep 0.1; done'" &
	local fake=$!
	sleep 0.3

	local start end
	start=$(date +%s%N)
	(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-manager" > /dev/null 2>&1
		set +e
		sudo() { :; }
		hierarchical_process_cleanup false > /dev/null 2>&1
	)
	end=$(date +%s%N)
	local ms=$(((end - start) / 1000000))

	if [[ -f $marker ]] && ! kill -0 "$fake" 2> /dev/null; then
		test_pass "cleanup stops the daemon with TERM"
	else
		test_fail "cleanup stops the daemon with TERM"
		kill -9 "$fake" 2> /dev/null
	fi
	if [[ $ms -lt 2000 ]]; then
		test_pass "cleanup completes quickly (${ms}ms)"
	else
		test_fail "cleanup completes quickly" "took ${ms}ms"
	fi
	wait "$fake" 2> /dev/null
}

# ---------------------------------------------------------------------------
# 11. Shared libs: no guessable /tmp paths, symlinked dirs refused.
# ---------------------------------------------------------------------------
test_shared_lib_paths() {
	local reg
	reg=$(
		unset TEMP_FILE_REGISTRY TEMP_FILE_LOCK
		# shellcheck disable=SC1091
		source "$SRC_DIR/temp-file-manager"
		echo "$TEMP_FILE_REGISTRY"
	)
	if [[ $reg == /tmp/vpn-temp-registry-[0-9]* ]]; then
		test_fail "temp registry is not a guessable /tmp path" "got $reg"
	else
		test_pass "temp registry is not a guessable /tmp path"
	fi

	local elog
	elog=$(
		unset VPN_LOG_DIR
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-colors"
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-error-handler" 2> /dev/null
		echo "$ERROR_LOG"
	)
	if [[ $elog != "$XDG_STATE_HOME/vpn/vpn_errors.log" ]]; then
		test_fail "error log is not in shared /tmp" "got $elog"
	else
		test_pass "error log is not in shared /tmp"
	fi

	local target="$WORK_DIR/elsewhere" link="$WORK_DIR/linked_dir"
	mkdir -p "$target"
	ln -sfn "$target" "$link"
	if (
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-utils"
		secure_user_dir "$link" 2> /dev/null
	); then
		test_fail "secure_user_dir refuses a symlinked directory"
	else
		test_pass "secure_user_dir refuses a symlinked directory"
	fi
}

# ---------------------------------------------------------------------------
# 12. Root must not guess between several logged-in users.
# ---------------------------------------------------------------------------
test_detect_real_user() {
	local r1 r2 r3
	r1=$(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-utils"
		SUDO_USER=nobody VPN_SYSTEM_CONF=/nonexistent detect_real_user
	)
	r2=$(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-utils"
		who() { printf 'alice tty1\nbob pts/0\n'; }
		getent() { return 0; }
		SUDO_USER="" VPN_SYSTEM_CONF=/nonexistent detect_real_user
	)
	r3=$(
		# shellcheck disable=SC1091
		source "$SRC_DIR/vpn-utils"
		who() { printf 'alice tty1\nalice pts/0\nroot pts/1\n'; }
		getent() { return 0; }
		SUDO_USER="" VPN_SYSTEM_CONF=/nonexistent detect_real_user
	)
	[[ $r1 == nobody ]] && test_pass "SUDO_USER is preferred" || test_fail "SUDO_USER is preferred" "got '$r1'"
	[[ -z $r2 ]] && test_pass "ambiguous logins yield no user" || test_fail "ambiguous logins yield no user" "got '$r2'"
	[[ $r3 == alice ]] && test_pass "single logged-in user is detected" || test_fail "single logged-in user is detected" "got '$r3'"
}

# ---------------------------------------------------------------------------
# 13. Kill switch applies atomically in an isolated network namespace.
# ---------------------------------------------------------------------------
test_kill_switch_netns() {
	if ! command -v unshare > /dev/null || ! command -v iptables-restore > /dev/null || ! command -v ip > /dev/null ||
		! unshare -n true 2> /dev/null; then
		test_pass "kill switch netns test (skipped: needs unshare/iptables/ip and privileges)"
		return
	fi
	mkdir -p "$XDG_STATE_HOME/vpn"
	echo "UDP link remote: [AF_INET]203.0.113.7:1194" > "$XDG_STATE_HOME/vpn/openvpn.log"
	local out
	out=$(unshare -n bash -c '
		ip link set lo up
		ip tuntap add dev tun0 mode tun 2>/dev/null && ip link set tun0 up
		bash "$1/vpn-kill-switch" enable > /dev/null 2>&1 || echo "ENABLE_FAILED"
		bash "$1/vpn-kill-switch" refresh > /dev/null 2>&1 || echo "REFRESH_FAILED"
		echo "jumps=$(iptables -S OUTPUT | grep -c VPN_KILL_SWITCH)"
		iptables -S VPN_KILL_SWITCH
		bash "$1/vpn-kill-switch" disable > /dev/null 2>&1
		echo "left=$(iptables -S | grep -c VPN_KILL)$(ip6tables -S | grep -c VPN_KILL)"
	' _ "$SRC_DIR" 2>&1)
	if grep -q "FAILED" <<< "$out"; then
		test_fail "kill switch enable/refresh" "$out"
		return
	fi
	grep -q "jumps=1" <<< "$out" && test_pass "refresh keeps a single OUTPUT jump" || test_fail "refresh keeps a single OUTPUT jump" "$out"
	grep -q -- "-d 203.0.113.7/32 -j ACCEPT" <<< "$out" && test_pass "VPN server IP taken from OpenVPN log" || test_fail "VPN server IP taken from OpenVPN log" "$out"
	grep -q -- "--sport 68 --dport 67" <<< "$out" && test_pass "DHCP rule limited to client->server" || test_fail "DHCP rule limited to client->server" "$out"
	grep -q -- "-A VPN_KILL_SWITCH -j DROP" <<< "$out" && test_pass "chain ends in DROP" || test_fail "chain ends in DROP" "$out"
	grep -q "left=00" <<< "$out" && test_pass "disable removes all rules" || test_fail "disable removes all rules" "$out"
}

# ---------------------------------------------------------------------------
# 14. Dispatcher (root): config values cannot inject code via arithmetic.
# ---------------------------------------------------------------------------
test_dispatcher_config_injection() {
	local hook="$PROJECT_ROOT/etc/NetworkManager/dispatcher.d/50-vpn-reconnect"
	local marker="$WORK_DIR/injected"
	rm -f "$marker"
	local result
	result=$(
		# shellcheck disable=SC2034  # read by the extracted load_config
		DEFAULT_COOLDOWN=30
		# shellcheck disable=SC2034
		DEFAULT_MAX_ATTEMPTS=3
		CONFIG_FILE="$WORK_DIR/evil.conf"
		printf 'AUTO_RECONNECT=true\nAUTO_RECONNECT_COOLDOWN=a[$(touch %s)]\nAUTO_RECONNECT_MAX_ATTEMPTS=x\n' "$marker" > "$CONFIG_FILE"
		user_cat() { cat "$1"; }
		eval "$(sed -n '/^load_config() {/,/^}/p' "$hook")"
		load_config
		elapsed=5
		[[ $elapsed -lt $COOLDOWN ]] || true
		echo "$COOLDOWN/$MAX_ATTEMPTS"
	)
	if [[ ! -e $marker && $result == "30/3" ]]; then
		test_pass "dispatcher rejects non-numeric cooldown/max-attempts"
	else
		test_fail "dispatcher rejects non-numeric cooldown/max-attempts" "result=$result injected=$([[ -e $marker ]] && echo yes || echo no)"
	fi
}

# ---------------------------------------------------------------------------
# 15. Hooks never run `connect <path>` (connect takes a country code).
# ---------------------------------------------------------------------------
test_hooks_use_custom_for_paths() {
	local f bad=""
	for f in "$PROJECT_ROOT/etc/NetworkManager/dispatcher.d/50-vpn-reconnect" "$PROJECT_ROOT/etc/elogind/system-sleep/50-vpn-sleep"; do
		grep -qE 'vpn-connector"? connect "\$(profile|PROFILE)"' "$f" && bad+=" $(basename "$f")"
		grep -qE 'VPN_CONNECTOR"? connect "\$profile"' "$f" && bad+=" $(basename "$f")"
	done
	[[ -z $bad ]] && test_pass "hooks reconnect via 'custom <profile>'" || test_fail "hooks reconnect via 'custom <profile>'" "$bad"
}

test_connect_runs_cleanup_on_unhealthy
test_connect_retries_after_timeout
test_tmp_log_cannot_spoof_success
test_progress_stage_transitions
test_profile_content_validation
test_openvpn_invocation
test_cleanup_keeps_held_lock
test_process_matching
test_stale_pid_file_ignored
test_cleanup_fast_and_graceful
test_shared_lib_paths
test_detect_real_user
test_kill_switch_netns
test_dispatcher_config_injection
test_hooks_use_custom_for_paths

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
	for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
	exit 1
fi
exit 0

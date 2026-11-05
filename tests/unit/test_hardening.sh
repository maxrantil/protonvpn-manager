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
	cp "$SRC_DIR/vpn" "$SRC_DIR/vpn-error-handler" "$SRC_DIR/vpn-colors" "$stub_dir/"
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

test_connect_runs_cleanup_on_unhealthy
test_connect_retries_after_timeout
test_tmp_log_cannot_spoof_success
test_progress_stage_transitions
test_profile_content_validation
test_openvpn_invocation
test_cleanup_keeps_held_lock

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
	for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
	exit 1
fi
exit 0

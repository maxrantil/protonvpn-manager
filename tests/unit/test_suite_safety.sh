#!/bin/bash
# ABOUTME: Tests that the test suite itself is safe on a developer machine
# ABOUTME: No real VPN connections, sudo, credentials or logs unless VPN_LIVE_TESTS=1
# shellcheck disable=SC2319  # `report $?` deliberately reports the [[ ]] check above it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"

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

# report <exit-code> <name> [detail]
report() {
    if [[ $1 -eq 0 ]]; then
        test_pass "$2"
    else
        test_fail "$2" "${3:-}"
    fi
}

WORK_DIR=$(mktemp -d)
FAKE_VPN_PID=""
teardown() {
    if [[ -n $FAKE_VPN_PID ]]; then
        kill "$FAKE_VPN_PID" 2> /dev/null
    fi
    rm -rf "$WORK_DIR"
}
trap teardown EXIT
trap 'exit 130' INT TERM HUP
REAL_HOME="$HOME"
REAL_PATH="$PATH"

# Stubs that record privileged or VPN-related calls instead of running them
STUBS="$WORK_DIR/stubs"
CALLS="$WORK_DIR/calls.log"
mkdir -p "$STUBS"
cat > "$STUBS/sudo" << 'EOF'
#!/bin/bash
echo "sudo $*" >> "$CALLS"
exit 0
EOF
# pgrep reports a running OpenVPN, as on a machine with an active session
cat > "$STUBS/pgrep" << 'EOF'
#!/bin/bash
[[ $* == *openvpn* ]] && { echo 4242; exit 0; }
exit 1
EOF
chmod +x "$STUBS"/*
export CALLS

# ---------------------------------------------------------------------------
# test_exit_codes.sh connects with the real profiles and credentials
# ---------------------------------------------------------------------------
test_exit_codes_skipped_by_default() {
    : > "$CALLS"
    local out rc=0
    out=$(env -u VPN_LIVE_TESTS HOME="$WORK_DIR/home" PATH="$STUBS:$REAL_PATH" \
        timeout 60 bash "$TESTS_DIR/test_exit_codes.sh" 2>&1) || rc=$?
    [[ $rc -eq 0 ]] && grep -q "VPN_LIVE_TESTS=1" <<< "$out"
    report $? "test_exit_codes.sh skips (exit 0) unless VPN_LIVE_TESTS=1, and says how to run it" \
        "exit $rc: $(tail -3 <<< "$out")"
    [[ ! -s $CALLS ]]
    report $? "skipped run makes no sudo calls (no pkill of a running VPN)" "$(cat "$CALLS")"
}

test_exit_codes_refuses_with_running_vpn() {
    : > "$CALLS"
    local out rc=0
    out=$(VPN_LIVE_TESTS=1 HOME="$WORK_DIR/home" PATH="$STUBS:$REAL_PATH" \
        timeout 60 bash "$TESTS_DIR/test_exit_codes.sh" 2>&1) || rc=$?
    [[ $rc -ne 0 ]] && grep -qi "disconnect" <<< "$out"
    report $? "VPN_LIVE_TESTS=1 with a VPN running: refuses (non-zero) and asks to disconnect" \
        "exit $rc: $(tail -3 <<< "$out")"
    [[ ! -s $CALLS ]]
    report $? "refusing touches nothing (no stop, no pkill)" "$(cat "$CALLS")"
}

# process_safety_tests.sh runs the real `vpn cleanup`, which stops any
# running OpenVPN and removes its tunnel (a kill switch would stay on)
test_process_safety_skipped_with_running_vpn() {
    : > "$CALLS"
    local out
    out=$(cd "$TESTS_DIR" && HOME="$WORK_DIR/home" PATH="$STUBS:$REAL_PATH" \
        timeout 120 bash "$TESTS_DIR/process_safety_tests.sh" 2>&1)
    grep -qi "skip.*vpn is running" <<< "$out" && ! grep -q "Starting test:" <<< "$out"
    report $? "process_safety_tests.sh skips (runs no test) while a VPN is running" "$(tail -3 <<< "$out")"
    [[ ! -s $CALLS ]]
    report $? "skipping process safety tests touches nothing" "$(cat "$CALLS")"
}

# A process the scripts take for a running OpenVPN (argv[0] ends in
# "openvpn", "--config" in the command line). It is ours, so a plain kill
# ends it: a suite that runs an unguarded `vpn cleanup` or `vpn kill` kills
# it, where a real root OpenVPN would only survive thanks to the blocked sudo.
start_fake_openvpn() {
    local dir="$WORK_DIR/fake-vpn" i
    mkdir -p "$dir" && : > "$dir/profile.ovpn"
    bash -c 'exec -a "$0 --config $1" sleep 120' "$dir/openvpn" "$dir/profile.ovpn" &
    FAKE_VPN_PID=$!
    # Ready once the scripts' own pattern finds it (before the exec, the
    # command line is bash's and does not match)
    for ((i = 0; i < 50; i++)); do
        pgrep -f '(^|/)openvpn .*--config' | grep -qx "$FAKE_VPN_PID" && return 0
        sleep 0.1
    done
    return 1
}

stop_fake_openvpn() {
    if [[ -n $FAKE_VPN_PID ]]; then
        kill "$FAKE_VPN_PID" 2> /dev/null
    fi
    FAKE_VPN_PID=""
}

# The suites that run the real scripts (#250: they used to run `vpn cleanup`
# and `vpn kill` with the user's HOME and sudo, and on top of a live session
# that killed OpenVPN with the kill switch still up). Each suite runs
# standalone with stand-ins for the user's HOME, runtime directory and TMPDIR,
# and a sudo that only records.
USER_HOME="$WORK_DIR/user-home"
RUN_DIR="$WORK_DIR/user-run"
TMP_DIR="$WORK_DIR/tmp"
SUDO_ONLY="$WORK_DIR/sudo-only"
RUN_RC=0
RUN_OUT=""
run_suite_isolated() { # $1 = suite file
    rm -rf "$USER_HOME" "$RUN_DIR" "$TMP_DIR"
    mkdir -p "$USER_HOME" "$RUN_DIR" "$TMP_DIR" && chmod 700 "$RUN_DIR"
    : > "$CALLS"
    RUN_RC=0
    RUN_OUT=$(cd "$TESTS_DIR" && env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u VPN_LIVE_TESTS \
        HOME="$USER_HOME" XDG_RUNTIME_DIR="$RUN_DIR" TMPDIR="$TMP_DIR" PATH="$SUDO_ONLY:$REAL_PATH" \
        timeout 120 bash "$TESTS_DIR/$1" 2>&1) || RUN_RC=$?
}

check_suite_left_alone() { # $1 = suite file, $2 = situation
    local why="exit $RUN_RC"
    [[ $RUN_RC -eq 124 ]] && why="timeout (exit 124)"
    [[ ! -s $CALLS ]]
    report $? "$1 $2: reaches no real sudo" "$(head -3 "$CALLS")"
    [[ -z $(find "$USER_HOME" "$RUN_DIR" -mindepth 1 -print -quit) ]]
    report $? "$1 $2: writes nothing into the user's HOME or runtime directory" \
        "$(find "$USER_HOME" "$RUN_DIR" -mindepth 1 | head -5)"
    [[ -z $(find "$TMP_DIR" -mindepth 1 -print -quit) ]]
    report $? "$1 $2: leaves nothing behind in TMPDIR" "$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 | head -5)"
    [[ $RUN_RC -eq 0 ]]
    report $? "$1 $2: passes" "$why: $(grep -E 'FAIL|✗' <<< "$RUN_OUT" | head -5)"
}

test_suites_leave_running_vpn_and_home_alone() {
    local suite
    mkdir -p "$SUDO_ONLY" && cp "$STUBS/sudo" "$SUDO_ONLY/"
    for suite in simple_regression_tests.sh integration_tests.sh e2e_tests.sh process_safety_tests.sh; do
        # With a VPN running: the guards must hold
        if start_fake_openvpn; then
            run_suite_isolated "$suite"
            kill -0 "$FAKE_VPN_PID" 2> /dev/null
            report $? "$suite (VPN running): leaves the running VPN alone" \
                "$(grep -iE 'cleanup|terminat' <<< "$RUN_OUT" | head -3)"
            stop_fake_openvpn
            check_suite_left_alone "$suite" "(VPN running)"
        else
            test_fail "$suite: fake OpenVPN did not start"
        fi
        # Without one, the real cleanup and kill run: the isolation alone must hold
        run_suite_isolated "$suite"
        check_suite_left_alone "$suite" "(no VPN)"
    done
}

# ---------------------------------------------------------------------------
# test_framework.sh: mocks must work, the environment must be isolated
# ---------------------------------------------------------------------------
# Runs shell code with the framework sourced, from the tests directory
with_framework() {
    (
        cd "$TESTS_DIR" || exit 1
        # shellcheck disable=SC1091
        source "$TESTS_DIR/test_framework.sh" > /dev/null 2>&1
        set +e
        eval "$1"
    )
}

test_mock_command_takes_effect() {
    local out
    out=$(with_framework '
        mock_command sudo "mocked sudo" 0 > /dev/null 2>&1
        echo "resolves=$(command -v sudo)"
        echo "output=$(sudo anything)"
        case ":$PATH:" in *:/tmp:*) echo "tmp_on_path=yes" ;; *) echo "tmp_on_path=no" ;; esac
    ')
    grep -q "^output=mocked sudo$" <<< "$out" && ! grep -q "^resolves=/usr" <<< "$out"
    report $? "mock_command sudo: \`sudo\` runs the mock" "$out"
    grep -q "tmp_on_path=no" <<< "$out"
    report $? "mocks live in a private directory, not /tmp on PATH" "$out"

    out=$(with_framework '
        mock_command echo-test "it'"'"'s \$HOME \"quoted\"" 3 > /dev/null 2>&1
        echo-test; echo "rc=$?"
    ')
    grep -qxF "it's \$HOME \"quoted\"" <<< "$out" && grep -q "^rc=3$" <<< "$out"
    report $? "mock output and exit code are kept exactly (quotes, \$, no expansion)" "$out"

    out=$(with_framework '
        before=$PATH
        mock_command ip "x" 0 > /dev/null 2>&1
        cleanup_mocks > /dev/null 2>&1
        [[ $PATH == "$before" ]] && echo "restored" || echo "PATH=$PATH"
    ')
    # (the framework's EXIT trap may log after the result line)
    grep -qx "restored" <<< "$out"
    report $? "cleanup_mocks restores PATH" "$out"
}

test_setup_test_env_isolated() {
    local out
    out=$(with_framework '
        setup_test_env > /dev/null 2>&1
        echo "home=$HOME"
        echo "state=${XDG_STATE_HOME:-}"
        echo "config=${XDG_CONFIG_HOME:-}"
        echo "tmp=$TEST_TEMP_DIR"
        echo "runtime_vpn=$(stat -c %a "$XDG_RUNTIME_DIR/vpn" 2> /dev/null)"
        sudo -n true 2> /dev/null && echo "sudo=ran" || echo "sudo=blocked"
        cleanup_test_env > /dev/null 2>&1
    ')
    local tmp
    tmp=$(sed -n 's/^tmp=//p' <<< "$out")
    [[ -n $tmp ]] && grep -q "^home=$tmp/" <<< "$out" && grep -q "^state=$tmp/" <<< "$out" &&
        grep -q "^config=$tmp/" <<< "$out" && ! grep -q "^home=$REAL_HOME$" <<< "$out"
    report $? "setup_test_env points HOME and XDG dirs into the test directory" "$out"
    grep -q "^sudo=blocked$" <<< "$out"
    report $? "setup_test_env blocks sudo unless a test mocks it" "$out"
    # Like a real session: the connector refuses a lock directory that is not 700
    grep -qx "runtime_vpn=700" <<< "$out"
    report $? "setup_test_env provides \$XDG_RUNTIME_DIR/vpn with mode 700" "$out"
}

# run_tests.sh sources every suite into one shell: a suite that leaves its
# isolated HOME, sudo guard or mocks behind changed the next suite's results
test_suites_do_not_leak_environment() {
    local fake_suite="$WORK_DIR/fake_suite.sh"
    cat > "$fake_suite" << 'EOF'
run_fake_suite() {
    setup_test_env
    mock_command ping "mocked" 0
}
EOF
    local out
    out=$(with_framework '
        VERBOSE=0
        eval "$(sed -n "/^run_test_suite() {/,/^}/p" "$TESTS_DIR/run_tests.sh")"
        before_home=$HOME before_path=$PATH
        run_test_suite "Fake" "'"$fake_suite"'" run_fake_suite > /dev/null 2>&1
        [[ $HOME == "$before_home" ]] && echo "home=restored" || echo "home=$HOME"
        [[ $PATH == "$before_path" ]] && echo "path=restored" || echo "path=$PATH"
    ')
    grep -qx "home=restored" <<< "$out" && grep -qx "path=restored" <<< "$out"
    report $? "run_test_suite restores HOME and PATH after each suite" "$out"

    out=$(with_framework '
        setup_test_env > /dev/null 2>&1; first=$TEST_TEMP_DIR
        setup_test_env > /dev/null 2>&1
        [[ -d $first ]] && echo "first=left" || echo "first=removed"
        cleanup_test_env > /dev/null 2>&1
    ')
    grep -qx "first=removed" <<< "$out"
    report $? "setup_test_env removes the test directory of the previous call" "$out"
}

# The unmocked e2e concurrent test ran the real connector against fixtures
test_fixture_connect_never_reaches_real_sudo() {
    local real_log="$REAL_HOME/.local/state/vpn/vpn_connect.log" before=0 after=0
    [[ -f $real_log ]] && before=$(wc -l < "$real_log")
    local out
    # Only run the connector once the framework guards sudo and isolates HOME;
    # otherwise this test would itself start a real OpenVPN
    out=$(REAL_HOME="$REAL_HOME" with_framework '
        setup_test_env > /dev/null 2>&1
        if [[ -z ${MOCK_DIR:-} || $(command -v sudo) != "$MOCK_DIR"/* || $HOME == "$REAL_HOME" ]]; then
            echo "openvpn=not-run (framework does not guard sudo / isolate HOME)"
            cleanup_test_env > /dev/null 2>&1
            exit 0
        fi
        LOCATIONS_DIR="$TEST_LOCATIONS_DIR" timeout 10 "$PROJECT_DIR/src/vpn-connector" connect se > /dev/null 2>&1
        echo "guard_log=$(cat "$MOCK_DIR/blocked.log" 2> /dev/null | tr "\n" ";")"
        pgrep -af "openvpn --config $TEST_TEMP_DIR" > /dev/null && echo "openvpn=started" || echo "openvpn=none"
        cleanup_test_env > /dev/null 2>&1
    ')
    [[ -f $real_log ]] && after=$(wc -l < "$real_log")
    grep -q "^openvpn=none$" <<< "$out" && ! grep -q "guard_log=.*openvpn" <<< "$out"
    report $? "connect against fixtures starts no OpenVPN" "$out"
    [[ $after -eq $before ]]
    report $? "fixture runs do not write to the real ~/.local/state/vpn logs" "real log: $before -> $after lines"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Test Suite Safety Tests${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_exit_codes_skipped_by_default
test_exit_codes_refuses_with_running_vpn
test_process_safety_skipped_with_running_vpn
test_suites_leave_running_vpn_and_home_alone
test_mock_command_takes_effect
test_setup_test_env_isolated
test_fixture_connect_never_reaches_real_sudo
test_suites_do_not_leak_environment

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

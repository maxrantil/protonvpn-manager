#!/bin/bash
# ABOUTME: Test framework for VPN management system
# ABOUTME: Provides utilities for unit, integration, and end-to-end testing

# Unalias grep to ensure consistent behavior across different environments
# Some systems alias grep to ripgrep (rg) which has different flag semantics
unalias grep 2> /dev/null || true

# Test framework variables (with include guard to prevent re-initialization)
if [[ -z "${TEST_FRAMEWORK_LOADED:-}" ]]; then
    TEST_FRAMEWORK_LOADED=1
    # shellcheck disable=SC2034  # TEST_DIR used by tests that source this framework
    TEST_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    # shellcheck disable=SC2034  # PROJECT_DIR used by tests that source this framework
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    TESTS_PASSED=0
    TESTS_FAILED=0
    CURRENT_TEST=""
    FAILED_TESTS=()
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_test() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} [$timestamp] $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} [$timestamp] $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message"
            ;;
        "SKIP")
            echo -e "${YELLOW}[SKIP]${NC} [$timestamp] $message"
            ;;
    esac
}

start_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    log_test "INFO" "Starting test: $test_name"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - Expected: '$expected', Got: '$actual'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$not_expected" != "$actual" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - Expected NOT: '$not_expected', Got: '$actual'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$haystack' does not contain '$needle'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"

    if [[ "$haystack" != *"$needle"* ]]; then
        log_test "PASS" "$CURRENT_TEST: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$haystack' contains '$needle'"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    local message="${2:-File should exist}"

    if [[ -f "$filepath" ]]; then
        log_test "PASS" "$CURRENT_TEST: $message - $filepath"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - $filepath does not exist"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed}"

    # Security: Use bash -c instead of eval to prevent command injection (HIGH-4)
    # Run in restricted subshell with minimal environment
    if (
        set -eu
        readonly HOME PATH
        unset 'SUDO_*' 'SSH_*' || true
        bash -c "$command"
    ) > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: $message - '$command'"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$command' failed"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail}"

    # Security: Use bash -c instead of eval to prevent command injection (HIGH-4)
    # Run in restricted subshell with minimal environment
    if ! (
        set -eu
        readonly HOME PATH
        unset 'SUDO_*' 'SSH_*' || true
        bash -c "$command"
    ) > /dev/null 2>&1; then
        log_test "PASS" "$CURRENT_TEST: $message - '$command'"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_test "FAIL" "$CURRENT_TEST: $message - '$command' succeeded when it should have failed"
        FAILED_TESTS+=("$CURRENT_TEST: $message")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Mocks live in a private directory, each under the real command name, first
# on PATH (putting all of /tmp on PATH would let any user plant commands).
# The PATH from before the first mock is restored by cleanup_mocks.
ensure_mock_dir() {
    if [[ -z ${MOCK_DIR:-} || ! -d $MOCK_DIR ]]; then
        MOCK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vpn-test-mocks.XXXXXX")
    fi
    [[ -n ${ORIGINAL_PATH:-} ]] || ORIGINAL_PATH=$PATH
    case ":$PATH:" in
        *":$MOCK_DIR:"*) ;;
        *) export PATH="$MOCK_DIR:$PATH" ;;
    esac
}

mock_command() {
    local command_name="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"

    ensure_mock_dir
    # %q keeps the output exactly as given (quotes, $, no expansion)
    {
        echo '#!/bin/bash'
        printf 'printf "%%s\\n" %q\n' "$mock_output"
        printf 'exit %d\n' "$mock_exit_code"
    } > "$MOCK_DIR/$command_name"
    chmod +x "$MOCK_DIR/$command_name"

    log_test "INFO" "Mocked command '$command_name' to return: '$mock_output' (exit: $mock_exit_code)"
}

cleanup_mocks() {
    if [[ -n ${MOCK_DIR:-} && -d $MOCK_DIR ]]; then
        rm -rf "$MOCK_DIR"
    fi
    MOCK_DIR=""
    if [[ -n ${ORIGINAL_PATH:-} ]]; then
        export PATH="$ORIGINAL_PATH"
        ORIGINAL_PATH=""
    fi
    log_test "INFO" "Cleaned up mock commands"
}

# A running VPN session, found the way the scripts find one: the pattern is
# read from src/vpn-validators, so the tests cannot drift from it
vpn_session_running() {
    local pattern
    pattern=$(sed -n "s/^OPENVPN_PGREP_PATTERN='\(.*\)'$/\1/p" "$PROJECT_DIR/src/vpn-validators" 2> /dev/null)
    pgrep -f "${pattern:-(^|/)openvpn .*--config}" > /dev/null 2>&1
}

setup_test_env() {
    # Clean up any mocks from previous tests first
    cleanup_mocks

    # One test directory at a time: remove the one of a previous call
    if [[ -n ${TEST_TEMP_DIR:-} && -d $TEST_TEMP_DIR && $TEST_TEMP_DIR == "${TMPDIR:-/tmp}"/vpn_test.* ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi

    # Create temporary test directories
    TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vpn_test.XXXXXX")

    # Never the real configuration, credentials, logs or locks: HOME and the
    # XDG directories point into the test directory (restored by cleanup_test_env)
    if [[ -z ${ORIGINAL_HOME:-} ]]; then
        ORIGINAL_HOME=$HOME
        ORIGINAL_XDG="${XDG_CONFIG_HOME-}|${XDG_STATE_HOME-}|${XDG_CACHE_HOME-}|${XDG_RUNTIME_DIR-}"
    fi
    export HOME="$TEST_TEMP_DIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_RUNTIME_DIR="$TEST_TEMP_DIR/run"
    mkdir -p "$XDG_CONFIG_HOME/vpn" "$XDG_STATE_HOME/vpn" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR/vpn"
    # As on a real system, where the connector created its lock directory 700
    chmod 700 "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR/vpn"

    # Never the system's PID file or session directory (both root-owned on a
    # real system): tests can create a stale PID file or session copies here
    export VPN_PID_FILE="$TEST_TEMP_DIR/openvpn.pid"
    export VPN_SESSION_DIR="$TEST_TEMP_DIR/session"

    # Never real privileged commands: sudo refuses (and logs the attempt in
    # $MOCK_DIR/blocked.log) unless a test mocks it with mock_command
    ensure_mock_dir
    cat > "$MOCK_DIR/sudo" << 'EOF'
#!/bin/bash
echo "$*" >> "$(dirname "$0")/blocked.log"
echo "sudo blocked in tests: $*" >&2
exit 1
EOF
    chmod +x "$MOCK_DIR/sudo"

    # Never the network: curl fails (`vpn status` then reports "Unable to
    # determine" for the external IP) unless a test mocks it with mock_command
    cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "curl blocked in tests: $*" >&2
exit 7
EOF
    chmod +x "$MOCK_DIR/curl"

    # Set up test locations
    TEST_LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
    mkdir -p "$TEST_LOCATIONS_DIR"

    # Create test VPN profiles
    cat > "$TEST_LOCATIONS_DIR/se-test.ovpn" << 'EOF'
remote 192.168.1.100 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    cat > "$TEST_LOCATIONS_DIR/dk-test.ovpn" << 'EOF'
remote 192.168.1.101 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    cat > "$TEST_LOCATIONS_DIR/secure-core-test.ovpn" << 'EOF'
# Secure Core
remote 192.168.1.102 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    cat > "$TEST_LOCATIONS_DIR/nl-test.ovpn" << 'EOF'
remote 192.168.1.103 1194
proto udp
dev tun
nobind
persist-key
persist-tun
auth-user-pass
EOF

    # Create test credentials
    cat > "$TEST_TEMP_DIR/credentials.txt" << 'EOF'
testuser
testpass
EOF

    log_test "INFO" "Test environment set up in $TEST_TEMP_DIR"
}

cleanup_test_env() {
    # Only a directory setup_test_env made (never an inherited TEST_TEMP_DIR)
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" && $TEST_TEMP_DIR == "${TMPDIR:-/tmp}"/vpn_test.* ]]; then
        rm -rf "$TEST_TEMP_DIR"
        log_test "INFO" "Test environment cleaned up"
    fi
    if [[ -n ${ORIGINAL_HOME:-} ]]; then
        export HOME="$ORIGINAL_HOME"
        IFS='|' read -r XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR <<< "$ORIGINAL_XDG"
        export XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR
        ORIGINAL_HOME=""
        unset VPN_PID_FILE VPN_SESSION_DIR
    fi
    if [[ -n "${LATENCY_FIXTURE_HOME:-}" ]] && [[ -d "$LATENCY_FIXTURE_HOME" ]]; then
        rm -rf "$LATENCY_FIXTURE_HOME"
    fi
    cleanup_mocks
}

# Isolated fixture for best-vpn-profile: a private HOME with a few profiles and
# a stub `ping` that answers with fixed latencies, so latency-based selection
# can be tested without network access or the user's real profiles.
setup_latency_fixture() {
    [[ -n "${LATENCY_FIXTURE_HOME:-}" && -d "$LATENCY_FIXTURE_HOME" ]] && return 0
    LATENCY_FIXTURE_HOME=$(mktemp -d)
    local loc="$LATENCY_FIXTURE_HOME/.config/vpn/locations" entry name host
    mkdir -p "$loc" "$LATENCY_FIXTURE_HOME/bin"
    for entry in "se-1:10.0.0.1" "se-2:10.0.0.2" "dk-1:10.0.0.4"; do
        name="${entry%%:*}"
        host="${entry#*:}"
        printf 'client\nproto udp\nremote %s 1194\n' "$host" > "$loc/$name.ovpn"
    done
    cat > "$LATENCY_FIXTURE_HOME/bin/ping" << 'PING'
#!/bin/bash
case "${*: -1}" in
    10.0.0.1) avg=40.5 ;;
    10.0.0.2) avg=12.25 ;;
    10.0.0.4) avg=5.1 ;;
    *) exit 1 ;;
esac
echo "rtt min/avg/max/mdev = 1.0/$avg/2.0/0.1 ms"
PING
    chmod +x "$LATENCY_FIXTURE_HOME/bin/ping"
}

# Run a command inside the latency fixture
run_with_latency_fixture() {
    setup_latency_fixture
    HOME="$LATENCY_FIXTURE_HOME" XDG_STATE_HOME="$LATENCY_FIXTURE_HOME/.local/state" \
        LOCATIONS_DIR="$LATENCY_FIXTURE_HOME/.config/vpn/locations" \
        PATH="$LATENCY_FIXTURE_HOME/bin:$PATH" "$@"
}

show_test_summary() {
    echo
    echo "=================================="
    echo "        TEST SUMMARY"
    echo "=================================="
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo -e "${RED}FAILED TESTS:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}  ✗${NC} $failed_test"
        done
        echo
        return 1
    else
        echo
        echo -e "${GREEN}ALL TESTS PASSED!${NC} ✅"
        echo
        return 0
    fi
}

# Trap to ensure cleanup on exit
trap cleanup_test_env EXIT

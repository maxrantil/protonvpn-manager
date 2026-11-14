#!/bin/bash
# ABOUTME: Behavioural tests: which profiles a country code selects (vpn connect/best/fast <cc>)
# ABOUTME: Country code as a name token, never a substring; Secure Core never chosen by country
# shellcheck disable=SC2319  # `report $?` deliberately reports the [[ ]] check above it

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

# report <exit-code> <name> [detail]
report() {
    if [[ $1 -eq 0 ]]; then
        test_pass "$2"
    else
        test_fail "$2" "${3:-}"
    fi
}

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

export HOME="$WORK_DIR/home"
export XDG_RUNTIME_DIR="$WORK_DIR/run"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export VPN_LOG_DIR="$XDG_STATE_HOME/vpn"
export LOCATIONS_DIR="$HOME/.config/vpn/locations"
mkdir -p "$LOCATIONS_DIR" "$XDG_RUNTIME_DIR" "$VPN_LOG_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Real ProtonVPN names, older/test names, Secure Core, and look-alikes
for name in \
    se-66.protonvpn.udp.ovpn se-1.ovpn wg-SE-374.conf test-se-2.ovpn se-test.ovpn \
    se-au-01.protonvpn.udp.ovpn is-se-01.protonvpn.udp.ovpn ch-se-1.ovpn \
    dk-120.protonvpn.udp.ovpn us-ca-11.protonvpn.udp.ovpn ca-qc-02.protonvpn.udp.ovpn \
    secure-core-test.ovpn base-1.ovpn chase-2.ovpn; do
    printf 'client\nremote 203.0.113.7 1194\n' > "$LOCATIONS_DIR/$name"
done

# Profiles (basenames, sorted, space-separated) selected for a country code
select_for() {
    bash -c "source '$SRC_DIR/vpn-connector' > /dev/null 2>&1; set +e
        find_profiles_by_country '$1'" 2> /dev/null | xargs -r -n1 basename | sort | tr '\n' ' '
}

# Args: $1 = country code, $2 = expected basenames (sorted, space-separated + trailing space)
expect_selection() {
    local got
    got=$(select_for "$1")
    [[ $got == "$2" ]]
    report $? "'$1' selects: ${2:-nothing}" "got: ${got:-nothing}"
}

test_country_selection() {
    # se-au-01 (Secure Core: enters SE, exits AU) is the profile that sent
    # `vpn connect se` traffic out through Australia
    # (WireGuard profiles are never candidates until #223: wg-SE-374.conf is left out)
    expect_selection se "se-1.ovpn se-66.protonvpn.udp.ovpn se-test.ovpn test-se-2.ovpn "
    expect_selection SE "se-1.ovpn se-66.protonvpn.udp.ovpn se-test.ovpn test-se-2.ovpn "
    expect_selection dk "dk-120.protonvpn.udp.ovpn "
    # Regular US/Canada servers carry a state/province code: not Secure Core
    expect_selection us "us-ca-11.protonvpn.udp.ovpn "
    expect_selection ca "ca-qc-02.protonvpn.udp.ovpn "
    # Only a Secure Core profile mentions AU: no regular AU server to pick
    expect_selection au ""

    # Callers run under set -e/pipefail and abort on a non-zero status
    # (profiles=$(find_profiles_by_country "$cc") || return 1)
    local cc rc bad=""
    for cc in se dk au; do
        bash -c "source '$SRC_DIR/vpn-connector' > /dev/null 2>&1
            find_profiles_by_country '$cc' > /dev/null" 2> /dev/null
        rc=$?
        [[ $rc -eq 0 ]] || bad+=" $cc:$rc"
    done
    [[ -z $bad ]]
    report $? "selection succeeds (exit 0) under set -euo pipefail, also when nothing matches" "exit codes:$bad"
}

# A country code ends up in file name matching: anything but a supported
# two-letter code must be refused before it gets there (path traversal,
# command injection). Through the real command, as a user would type it.
test_malicious_country_codes_rejected() {
    local code out accepted="" outside="$WORK_DIR/outside"
    mkdir -p "$outside" && printf 'client\n' > "$outside/se-outside.ovpn"
    # (a real NUL cannot be passed as an argument; "\n" here is the two
    # characters, $'se\nse' a real newline; the last entry ends in a Cyrillic е)
    local -a codes=(
        "../" ".." "/e" "\\" "\n" "./" "s;" "s|" "s&" "\$(" "\`s"
        "../../etc/passwd" "../../../" "se/../../etc" "../outside/se"
        $'se\nse' "se " " se" "s*" "??" "-h" "--" "sе"
    )
    for code in "${codes[@]}"; do
        out=$("$SRC_DIR/vpn-connector" list "$code" 2>&1)
        if ! grep -aq "security validation failed" <<< "$out" || grep -aq "se-outside" <<< "$out"; then
            accepted+=" $(printf '%q' "$code")"
        fi
    done
    [[ -z $accepted ]]
    report $? "${#codes[@]} malicious country codes are refused by 'vpn-connector list'" "not refused:$accepted"

    # Accepted means: exit 0 and the country's fixture profile is listed
    local rejected="" rc entry
    for entry in se:se-1 SE:se-1 dk:dk-120 us:us-ca-11 ca:ca-qc-02; do
        code=${entry%%:*}
        rc=0
        out=$("$SRC_DIR/vpn-connector" list "$code" 2>&1) || rc=$?
        [[ $rc -eq 0 && $out == *"${entry#*:}"* ]] || rejected+=" $code(exit $rc)"
    done
    [[ -z $rejected ]]
    report $? "supported country codes are still accepted and list their profiles" "refused:$rejected"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Country Selection Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_country_selection
test_malicious_country_codes_rejected

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

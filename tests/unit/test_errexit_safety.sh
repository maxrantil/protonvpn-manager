#!/bin/bash
# ABOUTME: Counters, no-match greps and optional output must not end a function under set -e (#263)
# ABOUTME: Runs the connector's functions with errexit active, as its callers do
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
export VPN_SESSION_DIR="$WORK_DIR/session"
export VPN_CONFIG_DIR="$HOME/.config/vpn"
export LOCATIONS_DIR="$VPN_CONFIG_DIR/locations"
mkdir -p "$LOCATIONS_DIR" "$XDG_RUNTIME_DIR" "$VPN_LOG_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

for name in dk-3.ovpn se-1.ovpn se-2.ovpn; do
    printf 'client\nremote 203.0.113.7 1194\n' > "$LOCATIONS_DIR/$name"
done
ALL_PROFILES="dk-3.ovpn se-1.ovpn se-2.ovpn "

# Run connector code in a fresh shell with errexit left on, as in the real script;
# prints its output, returns its status
# Args: $1 = shell code run after sourcing the connector
connector() {
    bash -c "source '$SRC_DIR/vpn-connector' > /dev/null 2>&1; $1" 2>&1
}

cache_file() {
    connector 'echo "$PROFILE_CACHE"'
}

# A cache written before entries were validated at rebuild (no CACHE_VALIDATED
# line): every entry is checked on read. Entries are given in order.
# Args: profile paths
write_legacy_cache() {
    local cache
    cache=$(cache_file)
    rm -f "$cache"
    {
        echo "# VPN Profile Cache"
        echo "# CACHE_MTIME=$(stat -c %Y "$LOCATIONS_DIR")"
        echo "# CACHE_DIR=${LOCATIONS_DIR}"
        echo "# CACHE_COUNT=$#"
        printf '%s\n' "$@"
    } > "$cache"
    chmod 600 "$cache"
}

names() {
    xargs -r -n1 basename | sort | tr '\n' ' '
}

test_bare_rebuild() {
    local out rc cache
    cache=$(cache_file)
    rm -f "$cache"
    out=$(connector 'rebuild_cache; echo "completed"')
    rc=$?
    [[ $rc -eq 0 && $out == *completed* ]]
    report $? "a bare rebuild_cache completes under set -e" "exit $rc; output: $out"

    out=$(grep -v '^#' "$cache" 2> /dev/null | names)
    [[ $out == "$ALL_PROFILES" ]]
    report $? "the rebuilt cache holds every profile" "got: $out"
    grep -qx '# CACHE_COUNT=3' "$cache" 2> /dev/null
    report $? "the rebuilt cache records its count" "header: $(grep '^#' "$cache" 2> /dev/null | tr '\n' ';')"

    out=$(connector 'get_cached_profiles | while IFS= read -r p; do echo "$p"; done' | names)
    [[ $out == "$ALL_PROFILES" ]]
    report $? "the rebuilt (validated) cache reads back through a pipeline" "got: $out"
}

# No profile at all: the rebuild fails by returning 1, not by tripping errexit
test_empty_rebuild() {
    local out empty="$WORK_DIR/empty/locations"
    mkdir -p "$empty"
    out=$(LOCATIONS_DIR="$empty" connector 'rc=0; rebuild_cache || rc=$?; echo "rc=$rc"')
    [[ $out == *"rc=1"* ]]
    report $? "rebuild_cache with no profiles returns 1" "output: $out"
}

test_two_invalid_entries() {
    local out
    write_legacy_cache "$LOCATIONS_DIR/gone.ovpn" "$LOCATIONS_DIR"/*.ovpn "$LOCATIONS_DIR/gone-too.ovpn"
    out=$(connector 'get_cached_profiles > /dev/null; echo "completed"')
    [[ $out == *"Filtered 2 invalid"* && $out == *completed* ]]
    report $? "two invalid entries are both counted" "output: $out"
}

# A profile without a `remote` line: the detailed list shows N/A and goes on
test_detailed_list_without_remote() {
    local out rc
    printf 'client\n' > "$LOCATIONS_DIR/aa-0.ovpn"
    out=$(connector 'list_profiles "" detailed; echo "completed"')
    rc=$?
    rm -f "$LOCATIONS_DIR/aa-0.ovpn"
    [[ $rc -eq 0 && $out == *completed* && $out == *"Total: 4 profiles"* ]]
    report $? "the detailed list completes past a profile without a remote line" "exit $rc; output: $out"
    [[ $out == *aa-0*N/A* && $out == *se-2* ]]
    report $? "the detailed list shows N/A for it and lists the rest" "output: $out"
}

# The left side of a pipeline is a subshell that keeps errexit: a counter that
# returns 1 there ends it and the reader sees a short list
test_invalid_entry_through_pipeline() {
    local position="$1" out rc
    shift
    write_legacy_cache "$@"

    out=$(connector 'get_cached_profiles | while IFS= read -r p; do echo "$p"; done' | grep -v WARNING | names)
    [[ $out == "$ALL_PROFILES" ]]
    report $? "invalid $position entry: the pipeline reader still gets every valid profile" "got: $out"

    write_legacy_cache "$@"
    out=$(connector 'get_cached_profiles > /dev/null; echo "completed"')
    rc=$?
    [[ $rc -eq 0 && $out == *completed* ]]
    report $? "invalid $position entry: a bare get_cached_profiles completes under set -e" "exit $rc; output: $out"
    [[ $out == *"Filtered 1 invalid"* ]]
    report $? "invalid $position entry: the filtered entry is reported" "output: $out"
}

# The cache-format probe finds nothing in a legacy cache: that is not an error
test_legacy_cache_all_valid() {
    local out
    write_legacy_cache "$LOCATIONS_DIR"/*.ovpn
    out=$(connector 'get_cached_profiles | while IFS= read -r p; do echo "$p"; done' | names)
    [[ $out == "$ALL_PROFILES" ]]
    report $? "legacy cache: the pipeline reader gets every profile" "got: $out"
}

# A message without its optional detail must not return 1 to a set -e caller
test_optional_message_parts() {
    local fn out rc
    for fn in vpn_info vpn_warn; do
        out=$(connector "$fn TEST 'a message'; echo completed")
        rc=$?
        [[ $rc -eq 0 && $out == *"a message"* && $out == *completed* ]]
        report $? "$fn without its optional third argument returns 0" "exit $rc; output: $out"
        out=$(connector "$fn TEST 'a message' 'more'; echo completed")
        [[ $out == *more* && $out == *completed* ]]
        report $? "$fn still prints its third argument" "output: $out"
    done
}

test_pipeline_callers() {
    local out
    write_legacy_cache "$LOCATIONS_DIR/gone.ovpn" "$LOCATIONS_DIR"/*.ovpn
    out=$(connector 'find_profiles_by_country se; echo "rc=$?"')
    [[ $out == *"rc=0"* ]]
    report $? "find_profiles_by_country returns 0 past an invalid entry" "output: $out"
    write_legacy_cache "$LOCATIONS_DIR/gone.ovpn" "$LOCATIONS_DIR"/*.ovpn
    out=$(connector 'find_profiles_by_country se' | grep -v WARNING | names)
    [[ $out == "se-1.ovpn se-2.ovpn " ]]
    report $? "find_profiles_by_country lists the country's profiles past an invalid entry" "got: $out"

    write_legacy_cache "$LOCATIONS_DIR/gone.ovpn" "$LOCATIONS_DIR"/*.ovpn
    out=$(connector 'get_available_countries' | grep -v WARNING | sort -u | tr '\n' ' ')
    [[ $out == "dk se " ]]
    report $? "get_available_countries lists every country past an invalid entry" "got: $out"
}

# The pattern must not come back: ((x++)) and ((x--)) return 1 when x was 0
test_no_post_increment_statements() {
    local hits
    hits=$(grep -nE '(^|&&|;|then|do)[[:space:]]*\(\([[:space:]]*[A-Za-z_][A-Za-z0-9_]*(\+\+|--)[[:space:]]*\)\)' "$SRC_DIR"/* 2> /dev/null)
    [[ -z $hits ]]
    report $? "no ((x++)) or ((x--)) statement in src/" "$hits"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Errexit Safety Test Suite (#263)${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

test_bare_rebuild
test_empty_rebuild
test_invalid_entry_through_pipeline first "$LOCATIONS_DIR/gone.ovpn" "$LOCATIONS_DIR"/*.ovpn
test_invalid_entry_through_pipeline last "$LOCATIONS_DIR"/*.ovpn "$LOCATIONS_DIR/gone.ovpn"
test_two_invalid_entries
test_legacy_cache_all_valid
test_pipeline_callers
test_optional_message_parts
test_detailed_list_without_remote
test_no_post_increment_statements

echo ""
echo -e "${T_BLUE}Results: $TESTS_PASSED/$TESTS_RUN passed${T_NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    for t in "${FAILED_TESTS[@]}"; do echo -e "  ${T_RED}✗${T_NC} $t"; done
    exit 1
fi
exit 0

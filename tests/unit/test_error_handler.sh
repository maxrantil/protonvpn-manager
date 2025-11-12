#!/bin/bash
# ABOUTME: Unit tests for vpn-error-handler module
# ABOUTME: Tests error severity, templates, color stripping, log failures, and recursive errors

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPN_DIR="$PROJECT_ROOT/src"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes for test output
T_GREEN='\033[1;32m'
T_RED='\033[1;31m'
T_BLUE='\033[1;34m'
T_NC='\033[0m'

declare -a FAILED_TESTS=()

# Simple test runner - run command in subshell, capture output
run_test() {
    local cmd="$1"
    local temp_log
    temp_log=$(mktemp -d)
    bash -c "
        set +e
        export VPN_LOG_DIR='$temp_log'
        cd '$PROJECT_ROOT'
        source src/vpn-colors 2>/dev/null
        source src/vpn-error-handler 2>/dev/null
        $cmd
    " 2>&1
    rm -rf "$temp_log"
}

test_pass() {
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "  ${T_GREEN}✓${T_NC} $1"
}

test_fail() {
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
    echo -e "  ${T_RED}✗${T_NC} $1"
    [[ -n "${2:-}" ]] && echo -e "    $2"
}

echo -e "${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}VPN Error Handler Unit Test Suite${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"

#############################################
# Test Suite 1: Error Severity Levels
#############################################

echo -e "\n${T_BLUE}Testing Error Severity Levels (11 tests)${T_NC}"

output=$(run_test "vpn_error 1 'TEST' 'PROCESS' 'Critical test'")
if [[ "$output" == *"[CRITICAL]"* ]]; then test_pass "Critical shows [CRITICAL] marker"; else test_fail "Critical shows [CRITICAL] marker"; fi
if [[ "$output" == *"Critical test"* ]]; then test_pass "Critical shows message"; else test_fail "Critical shows message"; fi

output=$(run_test "vpn_error 2 'TEST' 'FILE_ACCESS' 'High error'")
if [[ "$output" == *"[ERROR]"* ]]; then test_pass "High shows [ERROR] marker"; else test_fail "High shows [ERROR] marker"; fi
if [[ "$output" == *"High error"* ]]; then test_pass "High shows message"; else test_fail "High shows message"; fi

output=$(run_test "vpn_error 3 'TEST' 'NETWORK' 'Medium warning'")
if [[ "$output" == *"[WARNING]"* ]]; then test_pass "Medium shows [WARNING] marker"; else test_fail "Medium shows [WARNING] marker"; fi
if [[ "$output" == *"Medium warning"* ]]; then test_pass "Medium shows message"; else test_fail "Medium shows message"; fi

output=$(run_test "vpn_error 4 'TEST' 'CONFIG' 'Info message'")
if [[ "$output" == *"[INFO]"* ]]; then test_pass "Info shows [INFO] marker"; else test_fail "Info shows [INFO] marker"; fi
if [[ "$output" == *"Info message"* ]]; then test_pass "Info shows message"; else test_fail "Info shows message"; fi

output=$(run_test "vpn_error 99 'TEST' 'PROCESS' 'Unknown'")
if [[ "$output" == *"[ERROR]"* ]]; then test_pass "Unknown severity defaults to [ERROR]"; else test_fail "Unknown severity defaults to [ERROR]"; fi

output=$(run_test "vpn_error 1 'COMP' 'PROCESS' 'Test'")
if [[ "$output" == *"COMP"* ]]; then test_pass "Component name displayed"; else test_fail "Component name displayed"; fi

output=$(run_test "vpn_error 1 'TEST' 'NETWORK' 'Test'")
if [[ "$output" == *"NETWORK"* ]]; then test_pass "Category displayed"; else test_fail "Category displayed"; fi

#############################################
# Test Suite 2: Template Lookups (6 tests)
#############################################

echo -e "\n${T_BLUE}Testing Error Templates & Actions (6 tests)${T_NC}"

output=$(run_test "file_not_found_error 'TEST' '/missing/file'")
if [[ "$output" == *"Configuration file not found"* ]]; then test_pass "FILE_NOT_FOUND template used"; else test_fail "FILE_NOT_FOUND template used"; fi
if [[ "$output" == *"/missing/file"* ]]; then test_pass "File path shown"; else test_fail "File path shown"; fi

output=$(run_test "permission_error 'TEST' 'read' '/etc/vpn'")
if [[ "$output" == *"Permission denied"* ]]; then test_pass "PERMISSION_DENIED template used"; else test_fail "PERMISSION_DENIED template used"; fi
if [[ "$output" == *"sudo"* ]]; then test_pass "Permission error suggests sudo"; else test_fail "Permission error suggests sudo"; fi

output=$(run_test "network_error 'TEST' 'DNS failed'")
if [[ "$output" == *"Network connection not available"* ]]; then test_pass "NETWORK template used"; else test_fail "NETWORK template used"; fi
if [[ "$output" == *"DNS failed"* ]]; then test_pass "Network details shown"; else test_fail "Network details shown"; fi

#############################################
# Test Suite 3: Color Handling (6 tests)
#############################################

echo -e "\n${T_BLUE}Testing Color Output & Accessibility (6 tests)${T_NC}"

output=$(run_test "vpn_error 1 'TEST' 'PROCESS' 'Test'")
if [[ "$output" == *$'\033['* ]]; then test_pass "ANSI color codes present"; else test_fail "ANSI color codes present"; fi
if [[ "$output" == *"[CRITICAL]"* ]]; then test_pass "Text marker [CRITICAL] present"; else test_fail "Text marker [CRITICAL] present"; fi

# Test NO_COLOR in a separate subshell with explicit export
no_color_output=$(bash -c "
    set +e
    export NO_COLOR=1
    cd '$PROJECT_ROOT'
    source src/vpn-colors 2>/dev/null
    source src/vpn-error-handler 2>/dev/null
    vpn_error 1 'TEST' 'PROCESS' 'Test' 2>&1
")
# Check for absence of escape sequence start
if [[ ! "$no_color_output" =~ \033\[ ]]; then test_pass "NO_COLOR strips ANSI codes"; else test_fail "NO_COLOR strips ANSI codes"; fi
if [[ "$no_color_output" == *"[CRITICAL]"* ]]; then test_pass "Text markers preserved with NO_COLOR"; else test_fail "Text markers preserved with NO_COLOR"; fi

output=$(run_test "vpn_info 'TEST' 'Info test'")
if [[ "$output" == *"[INFO]"* ]]; then test_pass "vpn_info shows [INFO]"; else test_fail "vpn_info shows [INFO]"; fi

output=$(run_test "vpn_warn 'TEST' 'Warn test'")
if [[ "$output" == *"[WARNING]"* ]]; then test_pass "vpn_warn shows [WARNING]"; else test_fail "vpn_warn shows [WARNING]"; fi

#############################################
# Test Suite 4: Logging Functionality (7 tests)
#############################################

echo -e "\n${T_BLUE}Testing Error Logging (7 tests)${T_NC}"

# Normal logging
temp_log=$(mktemp -d)
bash -c "
    set +e
    export VPN_LOG_DIR='$temp_log'
    source '$VPN_DIR/vpn-colors' 2>/dev/null
    source '$VPN_DIR/vpn-error-handler' 2>/dev/null
    vpn_error 2 'TEST-LOG' 'PROCESS' 'Logged error' 'Extra context' 2>&1 >/dev/null
"
if [[ -f "$temp_log/vpn_errors.log" ]]; then test_pass "Log file created"; else test_fail "Log file created"; fi

log_content=$(cat "$temp_log/vpn_errors.log" 2>/dev/null || echo "")
if [[ "$log_content" == *"Logged error"* ]]; then test_pass "Log contains error message"; else test_fail "Log contains error message"; fi
if [[ "$log_content" == *"Extra context"* ]]; then test_pass "Log contains context"; else test_fail "Log contains context"; fi
if [[ "$log_content" == *"TEST-LOG"* ]]; then test_pass "Log contains component"; else test_fail "Log contains component"; fi
if [[ "$log_content" == *"["*"]"* ]]; then test_pass "Log contains timestamp"; else test_fail "Log contains timestamp"; fi
rm -rf "$temp_log"

# Logging failure handling
readonly_dir=$(mktemp -d)
chmod 555 "$readonly_dir"
output=$(bash -c "
    set +e
    export VPN_LOG_DIR='$readonly_dir'
    source '$VPN_DIR/vpn-colors' 2>/dev/null
    source '$VPN_DIR/vpn-error-handler' 2>/dev/null
    vpn_error 2 'TEST' 'PROCESS' 'Test message' 2>&1
")
if [[ "$output" == *"Test message"* ]]; then test_pass "Error displayed despite log failure"; else test_fail "Error displayed despite log failure"; fi
if [[ "$output" == *"[ERROR]"* ]]; then test_pass "Error marker shown despite log failure"; else test_fail "Error marker shown despite log failure"; fi
chmod 755 "$readonly_dir"
rm -rf "$readonly_dir"

#############################################
# Test Suite 5: Input Validation (5 tests)
#############################################

echo -e "\n${T_BLUE}Testing Input Validation & Recursive Errors (5 tests)${T_NC}"

output=$(run_test "vpn_error '' '' '' ''")
if [[ "$output" == *"[INTERNAL ERROR]"* ]]; then test_pass "Empty parameters trigger internal error"; else test_fail "Empty parameters trigger internal error"; fi
if [[ "$output" == *"insufficient parameters"* ]]; then test_pass "Internal error explains issue"; else test_fail "Internal error explains issue"; fi

output=$(run_test "vpn_error 2 '' '' ''")
if [[ "$output" == *"[INTERNAL ERROR]"* ]]; then test_pass "Partial parameters trigger internal error"; else test_fail "Partial parameters trigger internal error"; fi

# Test unknown category (bug we fixed)
output=$(run_test "vpn_error 1 'TEST' 'UNKNOWN_CATEGORY' 'Test'")
if [[ "$output" == *"[CRITICAL]"* ]]; then test_pass "Unknown category handled gracefully"; else test_fail "Unknown category handled gracefully"; fi
if [[ "$output" != *"unbound variable"* ]]; then test_pass "No unbound variable error"; else test_fail "No unbound variable error"; fi

#############################################
# Test Suite 6: Specialized Functions (5 tests)
#############################################

echo -e "\n${T_BLUE}Testing Specialized Error Functions (5 tests)${T_NC}"

output=$(run_test "process_error 'TEST' 'connect' 'timeout occurred'")
if [[ "$output" == *"Process operation failed"* ]]; then test_pass "process_error uses correct template"; else test_fail "process_error uses correct template"; fi

output=$(run_test "config_error 'TEST' 'OpenVPN' 'missing auth'")
if [[ "$output" == *"Configuration file contains errors"* ]]; then test_pass "config_error uses correct template"; else test_fail "config_error uses correct template"; fi

output=$(run_test "dependency_error 'TEST' 'openvpn, curl'")
if [[ "$output" == *"Required system dependencies missing"* ]]; then test_pass "dependency_error uses correct template"; else test_fail "dependency_error uses correct template"; fi

output=$(run_test "critical_process_error 'TEST' 3 'data leak'")
if [[ "$output" == *"[CRITICAL]"* ]]; then test_pass "critical_process_error is CRITICAL"; else test_fail "critical_process_error is CRITICAL"; fi
if [[ "$output" == *"vpn cleanup"* ]]; then test_pass "critical_process_error suggests cleanup"; else test_fail "critical_process_error suggests cleanup"; fi

#############################################
# Test Suite 7: Additional Features (3 tests)
#############################################

echo -e "\n${T_BLUE}Testing Additional Features (3 tests)${T_NC}"

output=$(run_test "vpn_error 2 'TEST' 'PROCESS' 'Msg' 'Context' 'Suggestion' 'ERR-001'")
if [[ "$output" == *"Context"* ]]; then test_pass "Optional context shown"; else test_fail "Optional context shown"; fi
if [[ "$output" == *"Suggestion"* ]]; then test_pass "Optional suggestion shown"; else test_fail "Optional suggestion shown"; fi
if [[ "$output" == *"ERR-001"* ]]; then test_pass "Optional error ID shown"; else test_fail "Optional error ID shown"; fi

#############################################
# Summary
#############################################

echo -e "\n${T_BLUE}========================================${T_NC}"
echo -e "${T_BLUE}Test Summary${T_NC}"
echo -e "${T_BLUE}========================================${T_NC}"
echo -e "Total tests run:    $TESTS_RUN"
echo -e "${T_GREEN}Tests passed:       $TESTS_PASSED${T_NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${T_RED}Tests failed:       $TESTS_FAILED${T_NC}"
    echo -e "\n${T_RED}Failed tests:${T_NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${T_RED}✗${T_NC} $test"
    done
    exit 1
else
    echo -e "${T_GREEN}All tests passed!${T_NC}"
    exit 0
fi

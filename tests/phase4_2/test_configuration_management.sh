#!/bin/bash
# ABOUTME: Phase 4.2.2 Configuration Management comprehensive TDD test suite
# ABOUTME: Tests TOML configuration support, hot-reload, security validation, and user experience

# Source test framework
source "$(dirname "$0")/../test_framework.sh"

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPN_DIR="$PROJECT_ROOT/src"
TEST_PHASE="Phase 4.2.2 Configuration Management"

# Configuration management test paths
readonly CONFIG_MANAGER="$VPN_DIR/config-manager"

# Test initialization
echo "=================================================================="
echo "$TEST_PHASE Tests"
echo "Testing advanced configuration management with TOML support"
echo "Expected Status: SOME TESTS PASSING (GREEN PHASE - TDD)"
echo "=================================================================="

setup_test_env

start_test "toml_config_manager_exists"
assert_file_exists "$CONFIG_MANAGER" "Advanced configuration manager should exist"

start_test "toml_configuration_parsing"
cat > "$TEST_TEMP_DIR/test.toml" << 'EOF'
[service]
name = "ProtonVPN Service"
update_interval = 300
enabled = true

[notifications]
level = "INFO"
desktop = true
sound = false

[security]
encryption = true
audit_logging = true
EOF

$CONFIG_MANAGER validate "$TEST_TEMP_DIR/test.toml" >/dev/null 2>&1 && result="valid" || result="invalid"
assert_equals "valid" "$result" "Configuration manager should parse valid TOML configuration"

start_test "toml_schema_validation"
cat > "$TEST_TEMP_DIR/invalid.toml" << 'EOF'
[service]
name = "ProtonVPN Service"
update_interval = "not_a_number"
invalid_field = true
EOF

$CONFIG_MANAGER validate "$TEST_TEMP_DIR/invalid.toml" >/dev/null 2>&1 && result="valid" || result="invalid"
assert_equals "invalid" "$result" "Configuration manager should reject invalid TOML configuration"

start_test "toml_configuration_merging"
cat > "$TEST_TEMP_DIR/system.toml" << 'EOF'
[service]
name = "ProtonVPN Service"
update_interval = 300

[security]
encryption = true
EOF

cat > "$TEST_TEMP_DIR/user.toml" << 'EOF'
[service]
update_interval = 600

[notifications]
level = "WARN"
EOF

result=$("$CONFIG_MANAGER" merge "$TEST_TEMP_DIR/system.toml" "$TEST_TEMP_DIR/user.toml" --get service.update_interval 2>/dev/null || echo "failed")
assert_equals "600" "$result" "User configuration should override system configuration"

start_test "toml_configuration_get_value"
result=$("$CONFIG_MANAGER" get "$TEST_TEMP_DIR/test.toml" service.name 2>/dev/null || echo "failed")
assert_equals "ProtonVPN Service" "$result" "Configuration manager should extract specific values"

cleanup_test_env

echo
echo "=================================================================="
echo "$TEST_PHASE Test Results"
echo "GREEN PHASE: Basic TOML functionality implemented"
echo "Next Step: Add hot-reload and advanced features"
echo "=================================================================="

show_test_summary

#!/bin/bash
# ABOUTME: Mock and simulation framework for ProtonVPN system testing
# ABOUTME: Provides non-privileged testing capabilities for system-level operations

set -euo pipefail

# Mock framework configuration
MOCK_DIR="/tmp/protonvpn-mocks-$$"
MOCK_STATE_DIR="$MOCK_DIR/state"
MOCK_BIN_DIR="$MOCK_DIR/bin"
MOCK_LOG_DIR="$MOCK_DIR/logs"

# Initialize mock framework
init_mock_framework() {
	echo "Initializing ProtonVPN Mock Framework..."

	# Create mock directories
	mkdir -p "$MOCK_DIR" "$MOCK_STATE_DIR" "$MOCK_BIN_DIR" "$MOCK_LOG_DIR"

	# Add mock bin directory to PATH
	export PATH="$MOCK_BIN_DIR:$PATH"

	# Set mock environment variables
	export MOCK_MODE="true"
	export MOCK_DIR
	export MOCK_STATE_DIR
	export MOCK_LOG_DIR

	echo "Mock framework initialized at: $MOCK_DIR"
}

# Cleanup mock framework
cleanup_mock_framework() {
	echo "Cleaning up mock framework..."
	rm -rf "$MOCK_DIR"
	echo "Mock framework cleaned up"
}

# Create mock systemctl
create_mock_systemctl() {
	cat >"$MOCK_BIN_DIR/systemctl" <<'EOF'
#!/bin/bash
# Mock systemctl for ProtonVPN testing

MOCK_STATE_FILE="$MOCK_STATE_DIR/systemctl_state"
mkdir -p "$(dirname "$MOCK_STATE_FILE")"

# Initialize state if needed
if [[ ! -f "$MOCK_STATE_FILE" ]]; then
    cat > "$MOCK_STATE_FILE" << 'INIT_STATE'
protonvpn.target=active,enabled
protonvpn-daemon=active,enabled
protonvpn-health-monitor=active,enabled
protonvpn-api-server=active,enabled
protonvpn-notification=active,enabled
INIT_STATE
fi

# Function to get service state
get_service_state() {
    local service="$1"
    local field="$2"  # active/enabled

    local state_line
    state_line=$(grep "^$service=" "$MOCK_STATE_FILE" 2>/dev/null || echo "")

    if [[ -n "$state_line" ]]; then
        local states="${state_line#*=}"
        case "$field" in
            "active")
                echo "${states%%,*}"
                ;;
            "enabled")
                echo "${states##*,}"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Function to set service state
set_service_state() {
    local service="$1"
    local active_state="$2"
    local enabled_state="$3"

    # Remove existing line
    grep -v "^$service=" "$MOCK_STATE_FILE" > "$MOCK_STATE_FILE.tmp" 2>/dev/null || touch "$MOCK_STATE_FILE.tmp"

    # Add new state
    echo "$service=$active_state,$enabled_state" >> "$MOCK_STATE_FILE.tmp"
    mv "$MOCK_STATE_FILE.tmp" "$MOCK_STATE_FILE"
}

# Mock systemctl commands
case "$1" in
    "is-active")
        service="$2"
        state=$(get_service_state "$service" "active")
        echo "$state"
        [[ "$state" == "active" ]] && exit 0 || exit 1
        ;;
    "is-enabled")
        service="$2"
        state=$(get_service_state "$service" "enabled")
        echo "$state"
        [[ "$state" == "enabled" ]] && exit 0 || exit 1
        ;;
    "start")
        service="$2"
        enabled_state=$(get_service_state "$service" "enabled")
        set_service_state "$service" "active" "$enabled_state"
        echo "Mock: Started $service"
        ;;
    "stop")
        service="$2"
        enabled_state=$(get_service_state "$service" "enabled")
        set_service_state "$service" "inactive" "$enabled_state"
        echo "Mock: Stopped $service"
        ;;
    "restart")
        service="$2"
        enabled_state=$(get_service_state "$service" "enabled")
        set_service_state "$service" "active" "$enabled_state"
        echo "Mock: Restarted $service"
        ;;
    "enable")
        service="$2"
        active_state=$(get_service_state "$service" "active")
        set_service_state "$service" "$active_state" "enabled"
        echo "Mock: Enabled $service"
        ;;
    "disable")
        service="$2"
        active_state=$(get_service_state "$service" "active")
        set_service_state "$service" "$active_state" "disabled"
        echo "Mock: Disabled $service"
        ;;
    "status")
        service="$2"
        active_state=$(get_service_state "$service" "active")
        enabled_state=$(get_service_state "$service" "enabled")

        echo "● $service - Mock ProtonVPN Service"
        echo "   Loaded: loaded (/etc/systemd/system/$service.service; $enabled_state)"
        echo "   Active: $active_state (running) since $(date)"
        echo "   Process: 12345 (mock-process)"
        echo "   Main PID: 12345 (mock-process)"

        [[ "$active_state" == "active" ]] && exit 0 || exit 3
        ;;
    "daemon-reload")
        echo "Mock: Daemon reloaded"
        ;;
    "list-units")
        if [[ "$*" =~ "protonvpn" ]]; then
            echo "  protonvpn-daemon.service    loaded active running Mock ProtonVPN Daemon"
            echo "  protonvpn-api-server.service loaded active running Mock ProtonVPN API Server"
        fi
        ;;
    *)
        echo "Mock systemctl: $*"
        ;;
esac
EOF

	chmod +x "$MOCK_BIN_DIR/systemctl"
	echo "Mock systemctl created"
}

# Create mock useradd/usermod
create_mock_user_commands() {
	cat >"$MOCK_BIN_DIR/useradd" <<'EOF'
#!/bin/bash
# Mock useradd for testing

USER_STATE_FILE="$MOCK_STATE_DIR/users"
mkdir -p "$(dirname "$USER_STATE_FILE")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)
            SYSTEM_USER="true"
            ;;
        --shell)
            SHELL_ARG="$2"
            shift
            ;;
        --home-dir)
            HOME_ARG="$2"
            shift
            ;;
        --comment)
            COMMENT_ARG="$2"
            shift
            ;;
        --no-create-home)
            NO_HOME="true"
            ;;
        *)
            USERNAME="$1"
            ;;
    esac
    shift
done

# Check if user exists
if grep -q "^$USERNAME:" "$USER_STATE_FILE" 2>/dev/null; then
    echo "useradd: user '$USERNAME' already exists"
    exit 9
fi

# Add user to mock state
echo "$USERNAME:x:1001:1001:${COMMENT_ARG:-Mock User}:${HOME_ARG:-/home/$USERNAME}:${SHELL_ARG:-/bin/bash}" >> "$USER_STATE_FILE"
echo "Mock: Created user $USERNAME"
EOF

	cat >"$MOCK_BIN_DIR/usermod" <<'EOF'
#!/bin/bash
# Mock usermod for testing

USER_STATE_FILE="$MOCK_STATE_DIR/users"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell)
            NEW_SHELL="$2"
            shift
            ;;
        *)
            USERNAME="$1"
            ;;
    esac
    shift
done

if [[ -n "$NEW_SHELL" && -n "$USERNAME" ]]; then
    # Update shell in mock state
    if grep -q "^$USERNAME:" "$USER_STATE_FILE" 2>/dev/null; then
        sed -i "s|^$USERNAME:\([^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*|$USERNAME:\1$NEW_SHELL|" "$USER_STATE_FILE"
        echo "Mock: Updated shell for $USERNAME to $NEW_SHELL"
    else
        echo "usermod: user '$USERNAME' does not exist"
        exit 6
    fi
fi
EOF

	cat >"$MOCK_BIN_DIR/userdel" <<'EOF'
#!/bin/bash
# Mock userdel for testing

USER_STATE_FILE="$MOCK_STATE_DIR/users"
USERNAME="$1"

if grep -q "^$USERNAME:" "$USER_STATE_FILE" 2>/dev/null; then
    grep -v "^$USERNAME:" "$USER_STATE_FILE" > "$USER_STATE_FILE.tmp" 2>/dev/null || touch "$USER_STATE_FILE.tmp"
    mv "$USER_STATE_FILE.tmp" "$USER_STATE_FILE"
    echo "Mock: Deleted user $USERNAME"
else
    echo "userdel: user '$USERNAME' does not exist"
    exit 6
fi
EOF

	cat >"$MOCK_BIN_DIR/groupadd" <<'EOF'
#!/bin/bash
# Mock groupadd for testing

GROUP_STATE_FILE="$MOCK_STATE_DIR/groups"
mkdir -p "$(dirname "$GROUP_STATE_FILE")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)
            SYSTEM_GROUP="true"
            ;;
        *)
            GROUPNAME="$1"
            ;;
    esac
    shift
done

# Check if group exists
if grep -q "^$GROUPNAME:" "$GROUP_STATE_FILE" 2>/dev/null; then
    echo "groupadd: group '$GROUPNAME' already exists"
    exit 9
fi

# Add group to mock state
echo "$GROUPNAME:x:1001:" >> "$GROUP_STATE_FILE"
echo "Mock: Created group $GROUPNAME"
EOF

	cat >"$MOCK_BIN_DIR/groupdel" <<'EOF'
#!/bin/bash
# Mock groupdel for testing

GROUP_STATE_FILE="$MOCK_STATE_DIR/groups"
GROUPNAME="$1"

if grep -q "^$GROUPNAME:" "$GROUP_STATE_FILE" 2>/dev/null; then
    grep -v "^$GROUPNAME:" "$GROUP_STATE_FILE" > "$GROUP_STATE_FILE.tmp" 2>/dev/null || touch "$GROUP_STATE_FILE.tmp"
    mv "$GROUP_STATE_FILE.tmp" "$GROUP_STATE_FILE"
    echo "Mock: Deleted group $GROUPNAME"
else
    echo "groupdel: group '$GROUPNAME' does not exist"
    exit 6
fi
EOF

	cat >"$MOCK_BIN_DIR/getent" <<'EOF'
#!/bin/bash
# Mock getent for testing

case "$1" in
    "passwd")
        if [[ -f "$MOCK_STATE_DIR/users" ]]; then
            if [[ -n "$2" ]]; then
                grep "^$2:" "$MOCK_STATE_DIR/users" || exit 2
            else
                cat "$MOCK_STATE_DIR/users"
            fi
        else
            exit 2
        fi
        ;;
    "group")
        if [[ -f "$MOCK_STATE_DIR/groups" ]]; then
            if [[ -n "$2" ]]; then
                grep "^$2:" "$MOCK_STATE_DIR/groups" || exit 2
            else
                cat "$MOCK_STATE_DIR/groups"
            fi
        else
            exit 2
        fi
        ;;
    *)
        echo "getent: unknown database: $1"
        exit 2
        ;;
esac
EOF

	cat >"$MOCK_BIN_DIR/id" <<'EOF'
#!/bin/bash
# Mock id command for testing

case "$1" in
    "-u")
        echo "0"  # Mock as root for installation tests
        ;;
    "-un")
        echo "root"
        ;;
    "-gn")
        echo "root"
        ;;
    *)
        echo "uid=0(root) gid=0(root) groups=0(root)"
        ;;
esac
EOF

	chmod +x "$MOCK_BIN_DIR/useradd" "$MOCK_BIN_DIR/usermod" "$MOCK_BIN_DIR/userdel"
	chmod +x "$MOCK_BIN_DIR/groupadd" "$MOCK_BIN_DIR/groupdel" "$MOCK_BIN_DIR/getent" "$MOCK_BIN_DIR/id"
	echo "Mock user management commands created"
}

# Create mock sudo
create_mock_sudo() {
	cat >"$MOCK_BIN_DIR/sudo" <<'EOF'
#!/bin/bash
# Mock sudo for testing - just execute the command

# Log the sudo command for verification
echo "Mock sudo: $*" >> "$MOCK_LOG_DIR/sudo.log"

# Execute the command directly
exec "$@"
EOF

	chmod +x "$MOCK_BIN_DIR/sudo"
	echo "Mock sudo created"
}

# Create mock file system commands
create_mock_fs_commands() {
	# Mock chown that doesn't require root
	cat >"$MOCK_BIN_DIR/chown" <<'EOF'
#!/bin/bash
# Mock chown for testing

echo "Mock chown: $*" >> "$MOCK_LOG_DIR/chown.log"
# Just succeed without actually changing ownership
exit 0
EOF

	# Mock chmod that logs but still works
	cat >"$MOCK_BIN_DIR/chmod" <<'EOF'
#!/bin/bash
# Mock chmod for testing

echo "Mock chmod: $*" >> "$MOCK_LOG_DIR/chmod.log"
# Execute real chmod
exec /bin/chmod "$@"
EOF

	chmod +x "$MOCK_BIN_DIR/chown" "$MOCK_BIN_DIR/chmod"
	echo "Mock filesystem commands created"
}

# Create mock network commands
create_mock_network_commands() {
	cat >"$MOCK_BIN_DIR/openvpn" <<'EOF'
#!/bin/bash
# Mock OpenVPN for testing

CONFIG_FILE=""
DAEMON_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        "--config")
            CONFIG_FILE="$2"
            shift
            ;;
        "--daemon")
            DAEMON_MODE="true"
            ;;
    esac
    shift
done

echo "Mock OpenVPN started with config: $CONFIG_FILE"
echo "$$" > "$MOCK_STATE_DIR/openvpn.pid"

if [[ "$DAEMON_MODE" == "true" ]]; then
    # Simulate daemon mode
    sleep 1 &
    echo "Mock OpenVPN running in daemon mode (PID: $$)"
else
    echo "Mock OpenVPN running in foreground mode"
fi
EOF

	cat >"$MOCK_BIN_DIR/killall" <<'EOF'
#!/bin/bash
# Mock killall for testing

PROCESS_NAME="$1"
echo "Mock killall: Terminating $PROCESS_NAME"

if [[ "$PROCESS_NAME" == "openvpn" ]]; then
    rm -f "$MOCK_STATE_DIR/openvpn.pid"
fi

exit 0
EOF

	chmod +x "$MOCK_BIN_DIR/openvpn" "$MOCK_BIN_DIR/killall"
	echo "Mock network commands created"
}

# Test the mock framework
test_mock_framework() {
	echo "Testing Mock Framework..."

	# Test mock systemctl
	echo "Testing mock systemctl:"
	systemctl status protonvpn.target
	systemctl stop protonvpn-daemon
	systemctl is-active protonvpn-daemon
	systemctl start protonvpn-daemon
	systemctl is-active protonvpn-daemon

	# Test mock user commands
	echo -e "\nTesting mock user commands:"
	useradd --system testuser
	getent passwd testuser
	userdel testuser

	# Test mock sudo
	echo -e "\nTesting mock sudo:"
	sudo echo "This should work"

	echo -e "\nMock framework test complete!"
}

# Main function
main() {
	local command="${1:-help}"

	case "$command" in
	"init")
		init_mock_framework
		create_mock_systemctl
		create_mock_user_commands
		create_mock_sudo
		create_mock_fs_commands
		create_mock_network_commands
		echo "Mock framework fully initialized"
		;;
	"test")
		test_mock_framework
		;;
	"cleanup")
		cleanup_mock_framework
		;;
	"status")
		if [[ -d "$MOCK_DIR" ]]; then
			echo "Mock framework active at: $MOCK_DIR"
			echo "Mock PATH: $MOCK_BIN_DIR"
			echo "Available mocks:"
			ls -la "$MOCK_BIN_DIR"
		else
			echo "Mock framework not initialized"
		fi
		;;
	"help" | *)
		echo "ProtonVPN Mock Framework"
		echo "Usage: $0 {init|test|cleanup|status|help}"
		echo ""
		echo "Commands:"
		echo "  init    - Initialize mock framework"
		echo "  test    - Test mock framework functionality"
		echo "  cleanup - Clean up mock framework"
		echo "  status  - Show mock framework status"
		echo "  help    - Show this help"
		;;
	esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi

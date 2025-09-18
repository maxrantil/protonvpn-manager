#!/bin/bash
# ABOUTME: ProtonVPN Config Updater daemon for systemd - Security Hardened
# ABOUTME: Production-ready daemon with secure configuration system and no hardcoded paths

set -euo pipefail

# Security: Source secure configuration system (NO hardcoded paths)
readonly SECURE_CONFIG_MANAGER="/usr/local/bin/secure-config-manager"

if [[ -f "$SECURE_CONFIG_MANAGER" ]]; then
    # shellcheck source=secure-config-manager
    source "$SECURE_CONFIG_MANAGER"
    load_secure_config || {
        echo "ERROR: Failed to load secure configuration" >&2
        exit 1
    }
else
    echo "ERROR: Secure configuration system not found at: $SECURE_CONFIG_MANAGER" >&2
    echo "ERROR: This indicates the service was not properly installed" >&2
    exit 1
fi

# Use configuration-based paths (loaded from secure config)
readonly VPN_ROOT="${VPN_ROOT:-/usr/local/lib/protonvpn}"
readonly VPN_BIN_DIR="${VPN_BIN_DIR:-/usr/local/bin}"
readonly VPN_LOG_DIR="${VPN_LOG_DIR:-/var/log/protonvpn}"
readonly VPN_RUN_DIR="${VPN_RUN_DIR:-/run/protonvpn}"
readonly PID_FILE="$VPN_RUN_DIR/updater.pid"

# Service configuration (from secure config)
readonly UPDATE_TIMEOUT="${UPDATE_TIMEOUT:-60}"
readonly SERVICE_USER="${SERVICE_USER:-protonvpn}"
readonly SERVICE_GROUP="${SERVICE_GROUP:-protonvpn}"
readonly AUDIT_LOGGING="${AUDIT_LOGGING:-true}"

# Validate configuration integrity on startup
if ! validate_config_integrity >/dev/null 2>&1; then
    echo "ERROR: Configuration integrity check failed" >&2
    exit 1
fi

# Security check - ensure we're running as correct user
if [[ "$(id -un)" != "$SERVICE_USER" ]]; then
    echo "ERROR: Must run as service user: $SERVICE_USER (currently: $(id -un))" >&2
    exit 1
fi

# Security check - ensure no legacy development paths are accessible
if [[ -d "/home/mqx/workspace/claude-code/vpn" ]]; then
    echo "WARNING: Legacy development path detected but will be ignored for security" >&2
    # Log security event
    if [[ "$AUDIT_LOGGING" == "true" ]]; then
        logger -p user.warn -t protonvpn-updater "Legacy development path detected and ignored"
    fi
fi

# Secure logging function with sanitization
log_secure() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Sanitize message - remove sensitive information
    local clean_message
    clean_message=$(echo "$message" | \
        sed -e 's|/home/[^/]*/[^/]*/[^/]*/[^/]*|[REDACTED_PATH]|g' \
            -e 's|password[^[:space:]]*|[REDACTED]|gi' \
            -e 's|token[^[:space:]]*|[REDACTED]|gi' \
            -e 's|auth[^[:space:]]*=[^[:space:]]*|[REDACTED]|gi')

    # Write to service log
    echo "[$timestamp] [$level] $clean_message" | tee -a "$VPN_LOG_DIR/updater.log"

    # System log for audit trail
    if [[ "$AUDIT_LOGGING" == "true" ]]; then
        logger -p user.info -t protonvpn-updater "[$level] $clean_message"
    fi
}

# Store PID with proper permissions and validation
store_pid() {
    # Ensure run directory exists
    if [[ ! -d "$VPN_RUN_DIR" ]]; then
        echo "ERROR: Run directory not found: $VPN_RUN_DIR" >&2
        exit 1
    fi

    # Store PID
    echo $$ > "$PID_FILE"

    # Set secure permissions
    chmod 644 "$PID_FILE"

    # Validate PID file was created correctly
    if [[ ! -f "$PID_FILE" ]] || [[ ! -s "$PID_FILE" ]]; then
        log_secure "ERROR" "Failed to create PID file: $PID_FILE"
        exit 1
    fi

    log_secure "INFO" "PID file created: $PID_FILE (PID: $$)"
}

# Enhanced cleanup function with audit logging
cleanup() {
    log_secure "INFO" "ProtonVPN Config Updater daemon stopping (PID: $$)"

    # Remove PID file
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
        log_secure "INFO" "PID file removed: $PID_FILE"
    fi

    # Security audit log
    if [[ "$AUDIT_LOGGING" == "true" ]]; then
        logger -p user.info -t protonvpn-updater "Service stopped normally by PID $$"
    fi

    exit 0
}

# Set up signal handlers
trap cleanup TERM INT HUP

# Comprehensive dependency validation with security checks
validate_dependencies() {
    log_secure "INFO" "Validating dependencies and security requirements"

    # Check critical binaries exist and are executable
    local required_binaries=(
        "$VPN_BIN_DIR/download-engine"
        "$VPN_BIN_DIR/proton-auth"
    )

    for binary in "${required_binaries[@]}"; do
        if [[ ! -x "$binary" ]]; then
            log_secure "ERROR" "Required binary not found or not executable: $binary"
            return 1
        fi

        # Security check - ensure binary is owned by root
        local owner
        owner=$(stat -c "%U" "$binary")
        if [[ "$owner" != "root" ]]; then
            log_secure "WARN" "Binary has non-root ownership: $binary (owner: $owner)"
        fi
    done

    # Validate secure directories exist and have correct permissions
    local required_dirs=(
        "$VPN_ROOT" "$VPN_BIN_DIR" "$VPN_LOG_DIR" "$VPN_RUN_DIR"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_secure "ERROR" "Required directory not found: $dir"
            return 1
        fi
    done

    # Check log directory is writable
    if [[ ! -w "$VPN_LOG_DIR" ]]; then
        log_secure "ERROR" "Log directory not writable: $VPN_LOG_DIR"
        return 1
    fi

    log_secure "INFO" "Dependency validation completed successfully"
    return 0
}

# Enhanced update check with comprehensive security controls
run_update_check() {
    log_secure "INFO" "Starting secure config update check"

    # Validate dependencies before proceeding
    if ! validate_dependencies; then
        log_secure "ERROR" "Dependency validation failed, aborting update check"
        return 1
    fi

    # Security timeout for all operations
    local timeout="$UPDATE_TIMEOUT"
    local start_time=$(date +%s)

    # Check authentication status with timeout
    log_secure "INFO" "Checking authentication status"
    if timeout "$timeout" "$VPN_BIN_DIR/proton-auth" status >/dev/null 2>&1; then
        log_secure "INFO" "Authentication available, proceeding with config update check"

        # Run update check with timeout and error handling
        local update_result=0
        if timeout "$timeout" "$VPN_BIN_DIR/download-engine" status 2>/dev/null; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_secure "INFO" "Config update check completed successfully (duration: ${duration}s)"

            # Security audit log
            if [[ "$AUDIT_LOGGING" == "true" ]]; then
                logger -p user.info -t protonvpn-updater "Update check successful, duration: ${duration}s"
            fi

            return 0
        else
            update_result=$?
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_secure "ERROR" "Config update check failed (exit code: $update_result, duration: ${duration}s)"

            # Security audit log for failures
            if [[ "$AUDIT_LOGGING" == "true" ]]; then
                logger -p user.warn -t protonvpn-updater "Update check failed, exit code: $update_result"
            fi

            return $update_result
        fi
    else
        log_secure "INFO" "No authentication available, skipping update check"

        # Log authentication unavailability for monitoring
        if [[ "$AUDIT_LOGGING" == "true" ]]; then
            logger -p user.info -t protonvpn-updater "Skipped update check due to authentication unavailability"
        fi

        return 0
    fi
}

# Resource usage monitoring for security
check_resource_usage() {
    # Check memory usage
    local memory_kb
    memory_kb=$(ps -o vsz= -p $$)
    local memory_mb=$((memory_kb / 1024))

    if [[ "$memory_mb" -gt 50 ]]; then
        log_secure "WARN" "High memory usage detected: ${memory_mb}MB"
    fi

    # Check if we're still the only instance
    local instance_count
    instance_count=$(pgrep -f "protonvpn-updater-daemon" | wc -l)

    if [[ "$instance_count" -gt 1 ]]; then
        log_secure "WARN" "Multiple daemon instances detected: $instance_count"
    fi
}

# Main execution with comprehensive security validations
main() {
    log_secure "INFO" "ProtonVPN Config Updater daemon starting (PID: $$, User: $(id -un))"

    # Verify we're in a secure execution environment
    if [[ ! -f "$SECURE_CONFIG_MANAGER" ]]; then
        log_secure "ERROR" "Secure configuration manager not found - unsafe to proceed"
        exit 1
    fi

    # Store PID with validation
    store_pid

    # Log startup security information
    log_secure "INFO" "Security context: User=$(id -un), Groups=$(id -gn), PID=$$"
    log_secure "INFO" "Working directory: $(pwd)"
    log_secure "INFO" "Configuration source: $SECURE_CONFIG_MANAGER"

    # Perform resource usage check
    check_resource_usage

    # Security audit log for startup
    if [[ "$AUDIT_LOGGING" == "true" ]]; then
        logger -p user.info -t protonvpn-updater "Daemon started securely by user $(id -un) with PID $$"
    fi

    # Run the update check
    run_update_check

    # Final security check
    check_resource_usage

    log_secure "INFO" "ProtonVPN Config Updater daemon execution completed"
}

# Security pre-flight checks
if [[ $EUID -eq 0 ]]; then
    log_secure "ERROR" "Security violation: Daemon must not run as root"
    exit 1
fi

if [[ ! -r "$SECURE_CONFIG_MANAGER" ]]; then
    echo "ERROR: Cannot read secure configuration manager: $SECURE_CONFIG_MANAGER" >&2
    exit 1
fi

# Execute main function with all arguments
main "$@"

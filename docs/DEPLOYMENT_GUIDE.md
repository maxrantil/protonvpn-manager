# VPN Configuration Management System - Deployment Guide

**Version:** 4.2.3
**Last Updated:** September 22, 2025
**Deployment Status:** Production Ready - Enterprise Grade

## Table of Contents

1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [Production Deployment](#production-deployment)
3. [Service Configuration](#service-configuration)
4. [Security Hardening](#security-hardening)
5. [Post-Deployment Validation](#post-deployment-validation)
6. [Monitoring Setup](#monitoring-setup)
7. [Backup and Recovery](#backup-and-recovery)
8. [Maintenance Procedures](#maintenance-procedures)
9. [Troubleshooting](#troubleshooting)

## Pre-Deployment Requirements

### System Requirements

**Operating System:**
- Artix Linux (recommended) with runit
- Arch Linux with systemd
- 64-bit architecture required

**Hardware Requirements:**
- **CPU**: 2+ cores (recommended 4+ for high-load environments)
- **Memory**: 512MB minimum, 2GB recommended
- **Storage**: 1GB free space for installation, 10GB for logs and data
- **Network**: Stable internet connection with UDP/TCP access

**System Packages:**
```bash
# Core dependencies (required)
sudo pacman -S openvpn curl bc libnotify iproute2 git sqlite gnupg

# Service management (choose based on init system)
sudo pacman -S systemd          # For Arch Linux
sudo pacman -S runit-artix      # For Artix Linux

# Additional utilities
sudo pacman -S notification-daemon jq
```

### Network Requirements

**Firewall Configuration:**
```bash
# Allow OpenVPN traffic
sudo iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# API Server (if exposing externally)
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# WebSocket connections
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

**DNS Configuration:**
Ensure your system can resolve DNS and doesn't have conflicting DNS managers:
```bash
# Check DNS resolution
nslookup google.com

# Identify potential conflicts
systemctl status systemd-resolved
systemctl status NetworkManager
```

### Security Prerequisites

**User Permissions:**
- Root access required for installation
- ProtonVPN account with valid credentials
- GPG key generation capability for encryption

**Security Validation:**
```bash
# Verify system security baseline
sudo lynis audit system

# Check for security updates
sudo pacman -Syu
```

## Production Deployment

### Step 1: Download and Prepare

```bash
# 1. Clone the repository
cd /opt
sudo git clone https://github.com/maxrantil/protonvpn-manager.git
cd protonvpn-manager

# 2. Verify repository integrity
git log --oneline -5
git status

# 3. Check deployment prerequisites
make check-requirements
```

### Step 2: Pre-Installation Validation

```bash
# Validate all required components are present
make validate-components

# Expected output:
# ✅ All required components present

# Check system compatibility
./scripts/pre-deployment-check.sh
```

### Step 3: Production Installation

**Automated Installation (Recommended):**
```bash
# Single-command production installation
sudo make install

# Installation process includes:
# - User and group creation (protonvpn:protonvpn)
# - Directory structure setup (/etc/protonvpn, /var/log/protonvpn, etc.)
# - Binary installation (/usr/local/bin/)
# - Configuration file creation
# - Service installation (runit/systemd)
# - Security hardening application
```

**Manual Installation Steps (Advanced):**
```bash
# Step-by-step installation for custom environments
sudo make check-root
sudo make install-user
sudo make install-dirs
sudo make validate-components
sudo make install-bins
sudo make install-configs
sudo make install-runit  # or install-systemd for Arch Linux
```

### Step 4: Initial Configuration

**1. Configure ProtonVPN Credentials:**
```bash
# Create secure credentials file
sudo nano /etc/protonvpn/vpn-credentials.txt

# Add your ProtonVPN credentials:
your_protonvpn_username
your_protonvpn_password

# Secure the credentials file
sudo chown protonvpn:protonvpn /etc/protonvpn/vpn-credentials.txt
sudo chmod 600 /etc/protonvpn/vpn-credentials.txt
```

**2. Configure Production Settings:**
```bash
# Edit production configuration
sudo nano /etc/protonvpn/production.conf

# Key settings for production:
[dashboard]
refresh_interval = 5
output_format = "json"
history_retention = "30d"

[health_monitor]
check_interval = 30
recovery_enabled = true
auto_restart = true
max_recovery_attempts = 5

[real_time_integration]
port = 8080
bind_address = "127.0.0.1"  # Change to "0.0.0.0" for external access
auth_required = true
rate_limit_requests_per_minute = 120

[security]
audit_logging = true
encryption_enabled = true
secure_mode = true
```

## Service Configuration

### Runit Service Setup (Artix Linux)

**Service Installation:**
```bash
# Install runit services
sudo make install-runit

# Services installed:
# - /etc/sv/protonvpn-api-server
# - /etc/sv/protonvpn-health-monitor
# - /etc/sv/protonvpn-status-dashboard
# - /etc/sv/protonvpn-updater
```

**Service Management:**
```bash
# Enable services at boot
sudo make enable-services

# Start all services
sudo make start-services

# Check service status
sudo sv status /etc/service/protonvpn-*

# Individual service control
sudo sv up /etc/service/protonvpn-api-server
sudo sv down /etc/service/protonvpn-api-server
sudo sv restart /etc/service/protonvpn-api-server
```

### Systemd Service Setup (Arch Linux)

**Service Installation:**
```bash
# Install systemd services
sudo make install-systemd

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable protonvpn.target
sudo systemctl start protonvpn.target

# Check service status
sudo systemctl status protonvpn.target
sudo systemctl status protonvpn-api-server.service
```

### Service Configuration Files

**API Server Configuration:** `/etc/protonvpn/api-server.conf`
```toml
[server]
port = 8080
bind_address = "127.0.0.1"
max_connections = 100
timeout = 30

[authentication]
enabled = true
token_expiry = 3600
rate_limiting = true

[logging]
level = "info"
file = "/var/log/protonvpn/api-server.log"
rotation = "daily"
```

**Health Monitor Configuration:** `/etc/protonvpn/health-monitor.conf`
```toml
[monitoring]
check_interval = 30
health_check_timeout = 10
auto_recovery = true
max_recovery_attempts = 5

[alerts]
email_notifications = false
webhook_url = ""
critical_threshold = 3

[performance]
cache_metrics = true
metrics_retention = "7d"
```

## Security Hardening

### Enterprise Security Features

The system implements **17 comprehensive security measures** that must pass validation:

**1. Service User Isolation:**
```bash
# Verify dedicated service user
id protonvpn
# Expected: uid=998(protonvpn) gid=998(protonvpn) groups=998(protonvpn)

getent passwd protonvpn
# Expected: protonvpn:x:998:998:ProtonVPN System User:/usr/lib/protonvpn:/usr/sbin/nologin
```

**2. Database Security:**
```bash
# Verify database encryption and permissions
ls -la /var/lib/protonvpn/databases/
# Expected: -rw------- 1 protonvpn protonvpn service-history.db

# Test database encryption
sudo -u protonvpn /usr/local/bin/secure-database-manager test-encryption
```

**3. Systemd Security Hardening:**
```bash
# Verify systemd security features
systemctl show protonvpn-api-server.service | grep -E "(NoNewPrivileges|ProtectSystem|PrivateTmp)"
# Expected: NoNewPrivileges=yes, ProtectSystem=strict, PrivateTmp=yes
```

### Security Validation

**Run Comprehensive Security Tests:**
```bash
# Full security test suite (17 tests)
./tests/security/test_security_hardening.sh

# Expected output:
# ✅ Test 1: Service user isolation - PASSED
# ✅ Test 2: Database encryption - PASSED
# ✅ Test 3: File permissions - PASSED
# ...
# ✅ Test 17: Audit logging - PASSED
#
# 🎉 ALL SECURITY TESTS PASSED (17/17)
# Security Level: ENTERPRISE GRADE ✅
```

**Individual Security Components:**
```bash
# Test specific security areas
./tests/security/test_service_user_security.sh
./tests/security/test_database_encryption.sh
./tests/security/test_systemd_hardening.sh
./tests/security/test_input_validation.sh
./tests/security/test_audit_logging.sh
```

### Security Configuration

**Audit Logging Configuration:** `/etc/protonvpn/audit.conf`
```toml
[audit]
enabled = true
log_file = "/var/log/protonvpn/audit.log"
log_level = "info"
retention_days = 90

[events]
log_connections = true
log_configuration_changes = true
log_security_events = true
log_api_access = true

[encryption]
log_encryption = true
encryption_key_rotation = "monthly"
```

## Post-Deployment Validation

### Functional Testing

**1. Service Health Check:**
```bash
# Comprehensive service validation
sudo /usr/local/bin/protonvpn-service-manager health-check

# Expected output:
# ✅ API Server: Running (PID: 1234)
# ✅ Health Monitor: Running (PID: 1235)
# ✅ Status Dashboard: Running (PID: 1236)
# ✅ Updater Daemon: Running (PID: 1237)
# ✅ Database: Accessible and encrypted
# ✅ Configuration: Valid and secure
```

**2. API Connectivity Test:**
```bash
# Test API endpoints
curl -X GET http://localhost:8080/api/v1/health
# Expected: {"status": "healthy", "timestamp": "2025-09-22T10:30:00Z"}

curl -X GET http://localhost:8080/api/v1/status
# Expected: {"vpn_status": "disconnected", "services": "operational"}
```

**3. VPN Connection Test:**
```bash
# Test VPN functionality
sudo -u protonvpn vpn best

# Verify connection
sudo -u protonvpn vpn status
# Expected: Connected to se-XX.protonvpn.udp

# Test disconnect
sudo -u protonvpn vpn disconnect
```

### Performance Validation

**Run Performance Test Suite:**
```bash
# Comprehensive performance validation
./tests/phase8_2_performance_validation_tests.sh

# Expected results:
# ✅ Connection Speed Test: 1.8s (Target: <30s)
# ✅ Fast Switching Test: 1.9s (Target: <20s)
# ✅ Memory Usage Test: 18MB (Target: <25MB)
# ✅ API Response Test: 42ms (Target: <100ms)
# ✅ Health Check Test: 114ms (Target: <500ms)
```

**Performance Benchmarks:**
```bash
# Test API performance
ab -n 100 -c 10 http://localhost:8080/api/v1/status

# Monitor resource usage
top -p $(pgrep -f protonvpn)
```

### Security Validation

**Security Compliance Check:**
```bash
# Run full security audit
./tests/security/security_audit_comprehensive.sh

# Check compliance status
sudo lynis audit system --profile /etc/protonvpn/lynis-profile.conf
```

## Monitoring Setup

### Log Management

**Configure Log Rotation:**
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/protonvpn

# Add configuration:
/var/log/protonvpn/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 protonvpn protonvpn
    postrotate
        /usr/bin/killall -USR1 protonvpn-logger 2>/dev/null || true
    endscript
}
```

**Log Monitoring:**
```bash
# Real-time log monitoring
tail -f /var/log/protonvpn/service.log

# Error tracking
grep "ERROR\|CRITICAL" /var/log/protonvpn/*.log

# Security event monitoring
grep "SECURITY" /var/log/protonvpn/audit.log
```

### Health Monitoring Setup

**Configure Health Checks:**
```bash
# Setup automated health monitoring
sudo crontab -e

# Add health check every 5 minutes:
*/5 * * * * /usr/local/bin/health-monitor --check --log-results

# Add daily security validation:
0 2 * * * /opt/protonvpn-manager/tests/security/test_security_hardening.sh >> /var/log/protonvpn/security-daily.log 2>&1
```

**Alerting Configuration:**
```bash
# Configure email alerts (optional)
sudo nano /etc/protonvpn/alerts.conf

[email]
enabled = false
smtp_server = "smtp.example.com"
from_address = "vpn-alerts@example.com"
to_addresses = ["admin@example.com"]

[webhooks]
enabled = false
webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### External Monitoring Integration

**Prometheus Metrics:**
```bash
# Enable Prometheus metrics export
curl http://localhost:8080/metrics

# Sample metrics:
# vpn_connection_status 1
# vpn_response_time_ms 42
# api_requests_total{endpoint="/status"} 1547
```

**JSON Status Export:**
```bash
# Setup JSON status export for external monitoring
*/1 * * * * /usr/local/bin/status-dashboard --format=json > /tmp/vpn-status.json

# External monitoring can read from /tmp/vpn-status.json
```

## Backup and Recovery

### Configuration Backup

**Automated Backup Setup:**
```bash
# Create backup script
sudo nano /usr/local/bin/protonvpn-backup.sh

#!/bin/bash
BACKUP_DIR="/var/backups/protonvpn"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup configuration files
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" /etc/protonvpn/

# Backup database
sudo -u protonvpn cp /var/lib/protonvpn/databases/service-history.db "$BACKUP_DIR/database_$DATE.db"

# Encrypt backups
gpg --cipher-algo AES256 --compress-algo 1 --symmetric "$BACKUP_DIR/config_$DATE.tar.gz"
gpg --cipher-algo AES256 --compress-algo 1 --symmetric "$BACKUP_DIR/database_$DATE.db"

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.gpg" -mtime +30 -delete

chmod +x /usr/local/bin/protonvpn-backup.sh

# Schedule daily backups
echo "0 3 * * * /usr/local/bin/protonvpn-backup.sh" | sudo crontab -
```

### Recovery Procedures

**Configuration Recovery:**
```bash
# Stop services
sudo make stop-services

# Restore configuration
sudo tar -xzf /var/backups/protonvpn/config_YYYYMMDD_HHMMSS.tar.gz -C /

# Restore database
sudo -u protonvpn cp /var/backups/protonvpn/database_YYYYMMDD_HHMMSS.db /var/lib/protonvpn/databases/service-history.db

# Fix permissions
sudo chown -R protonvpn:protonvpn /etc/protonvpn/
sudo chown -R protonvpn:protonvpn /var/lib/protonvpn/

# Restart services
sudo make start-services

# Validate recovery
sudo /usr/local/bin/protonvpn-service-manager health-check
```

**Complete System Recovery:**
```bash
# Fresh installation with backup restoration
sudo make uninstall
sudo make install

# Restore from backup (follow configuration recovery above)

# Run post-deployment validation
./tests/phase8_complete_validation_tests.sh
```

## Maintenance Procedures

### Regular Maintenance Tasks

**Daily Tasks:**
```bash
# 1. Check service health
sudo /usr/local/bin/protonvpn-service-manager health-check

# 2. Review logs for errors
grep "ERROR\|CRITICAL" /var/log/protonvpn/*.log | tail -20

# 3. Verify security status
./tests/security/test_security_hardening.sh --quick
```

**Weekly Tasks:**
```bash
# 1. Performance validation
./tests/phase8_2_performance_validation_tests.sh

# 2. Update VPN configurations
sudo -u protonvpn vpn download-configs status

# 3. Database optimization
sudo -u protonvpn /usr/local/bin/secure-database-manager optimize

# 4. Log cleanup and rotation
sudo logrotate -f /etc/logrotate.d/protonvpn
```

**Monthly Tasks:**
```bash
# 1. Full security audit
./tests/security/security_audit_comprehensive.sh

# 2. System updates
sudo pacman -Syu

# 3. Configuration backup verification
/usr/local/bin/protonvpn-backup.sh
gpg --decrypt /var/backups/protonvpn/config_latest.tar.gz.gpg > /dev/null

# 4. Performance optimization review
config-manager validate /etc/protonvpn/performance.conf
```

### Update Procedures

**System Updates:**
```bash
# 1. Stop services
sudo make stop-services

# 2. Update system
sudo pacman -Syu

# 3. Restart services
sudo make start-services

# 4. Validate functionality
./tests/run_tests.sh --quick
```

**Configuration Updates:**
```bash
# 1. Backup current configuration
/usr/local/bin/protonvpn-backup.sh

# 2. Apply configuration changes
sudo nano /etc/protonvpn/production.conf

# 3. Validate configuration
config-manager validate /etc/protonvpn/production.conf

# 4. Restart affected services
sudo sv restart /etc/service/protonvpn-*

# 5. Verify functionality
sudo /usr/local/bin/protonvpn-service-manager health-check
```

## Troubleshooting

### Common Deployment Issues

#### 1. Installation Failures

**Missing Dependencies:**
```bash
# Diagnosis
make check-requirements

# Solution
sudo pacman -S openvpn curl bc libnotify iproute2 git sqlite gnupg
```

**Permission Issues:**
```bash
# Diagnosis
ls -la /etc/protonvpn/
ls -la /var/log/protonvpn/

# Solution
sudo chown -R protonvpn:protonvpn /etc/protonvpn/
sudo chown -R protonvpn:protonvpn /var/log/protonvpn/
sudo chmod 750 /etc/protonvpn/
sudo chmod 750 /var/log/protonvpn/
```

#### 2. Service Startup Issues

**Service Won't Start:**
```bash
# Diagnosis
sudo sv status /etc/service/protonvpn-*
sudo sv log /etc/service/protonvpn-api-server

# Solutions
# Check configuration validity
config-manager validate /etc/protonvpn/production.conf

# Verify binary permissions
ls -la /usr/local/bin/api-server
sudo chmod +x /usr/local/bin/api-server

# Check service user
id protonvpn
```

#### 3. Network Connectivity Issues

**API Server Not Responding:**
```bash
# Diagnosis
netstat -tlnp | grep 8080
curl -v http://localhost:8080/api/v1/health

# Solutions
# Check firewall
sudo iptables -L | grep 8080

# Verify binding address
grep bind_address /etc/protonvpn/api-server.conf

# Check service logs
sudo sv log /etc/service/protonvpn-api-server
```

#### 4. Performance Issues

**Slow Response Times:**
```bash
# Diagnosis
./tests/phase8_2_performance_validation_tests.sh

# Solutions
# Optimize configuration
config-manager set /etc/protonvpn/performance.conf "connection_optimization.retry_attempts" "3"

# Clear performance cache
rm -f /tmp/vpn_performance.cache

# Restart services
sudo make restart-services
```

### Emergency Recovery

**Complete Service Recovery:**
```bash
# 1. Stop all services
sudo make stop-services

# 2. Kill any remaining processes
sudo pkill -f protonvpn

# 3. Clean up runtime files
sudo rm -f /var/run/protonvpn/*

# 4. Start services fresh
sudo make start-services

# 5. Validate recovery
sudo /usr/local/bin/protonvpn-service-manager health-check
```

**Database Recovery:**
```bash
# 1. Stop services using database
sudo sv down /etc/service/protonvpn-api-server
sudo sv down /etc/service/protonvpn-health-monitor

# 2. Restore database from backup
sudo -u protonvpn cp /var/backups/protonvpn/database_latest.db /var/lib/protonvpn/databases/service-history.db

# 3. Verify database integrity
sudo -u protonvpn /usr/local/bin/secure-database-manager verify

# 4. Restart services
sudo sv up /etc/service/protonvpn-api-server
sudo sv up /etc/service/protonvpn-health-monitor
```

### Support and Diagnostics

**Comprehensive Diagnostic Report:**
```bash
#!/bin/bash
# Create diagnostic report
REPORT_FILE="/tmp/protonvpn-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

echo "ProtonVPN System Diagnostic Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "======================================" >> "$REPORT_FILE"

# System information
echo -e "\n## System Information" >> "$REPORT_FILE"
uname -a >> "$REPORT_FILE"
lsb_release -a >> "$REPORT_FILE" 2>/dev/null

# Service status
echo -e "\n## Service Status" >> "$REPORT_FILE"
sudo sv status /etc/service/protonvpn-* >> "$REPORT_FILE"

# Configuration validation
echo -e "\n## Configuration Validation" >> "$REPORT_FILE"
config-manager validate /etc/protonvpn/production.conf >> "$REPORT_FILE" 2>&1

# Security status
echo -e "\n## Security Validation" >> "$REPORT_FILE"
./tests/security/test_security_hardening.sh --summary >> "$REPORT_FILE" 2>&1

# Performance metrics
echo -e "\n## Performance Metrics" >> "$REPORT_FILE"
./tests/phase8_2_performance_validation_tests.sh --summary >> "$REPORT_FILE" 2>&1

# Recent logs
echo -e "\n## Recent Error Logs" >> "$REPORT_FILE"
grep "ERROR\|CRITICAL" /var/log/protonvpn/*.log | tail -20 >> "$REPORT_FILE"

echo "Diagnostic report saved to: $REPORT_FILE"
```

---

**Version:** 4.2.3 Production Ready
**Deployment Guide Updated:** September 22, 2025
**Security Status:** Enterprise Grade (17/17 tests passing)
**Support:** See `DEVELOPER_GUIDE.md` for development procedures

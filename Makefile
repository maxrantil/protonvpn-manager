# ProtonVPN Management System - Production Installation
# ABOUTME: Complete installation and deployment management for ProtonVPN system
# ABOUTME: Handles user creation, permissions, service installation, and configuration

PREFIX ?= /usr/local
SYSCONFDIR ?= /etc
LOCALSTATEDIR ?= /var
RUNSTATEDIR ?= /run

# Installation paths
BIN_DIR = $(PREFIX)/bin
LIB_DIR = $(PREFIX)/lib/protonvpn
CONFIG_DIR = $(SYSCONFDIR)/protonvpn
LOG_DIR = $(LOCALSTATEDIR)/log/protonvpn
RUN_DIR = $(RUNSTATEDIR)/protonvpn
SERVICE_DIR = $(SYSCONFDIR)/sv
RUNIT_SERVICE_DIR = /etc/service

# User and group
VPN_USER = protonvpn
VPN_GROUP = protonvpn

# Executables to install
EXECUTABLES = status-dashboard health-monitor api-server config-manager \
              notification-manager secure-config-manager

# Scripts to install
SCRIPTS = scripts/protonvpn-service-manager

# Configuration files
CONFIG_FILES = config/production.conf config/health-monitor.conf \
               config/api-server.conf config/notification.conf

.PHONY: all install uninstall install-user install-dirs install-bins \
        install-configs install-runit enable-services start-services \
        stop-services disable-services check-requirements

all:
	@echo "ProtonVPN Management System Installation"
	@echo "Usage:"
	@echo "  make install        - Full installation (requires root)"
	@echo "  make uninstall      - Remove installation"
	@echo "  make start-services - Start all services"
	@echo "  make stop-services  - Stop all services"

# Check if running as root
check-root:
	@if [ $$(id -u) -ne 0 ]; then \
		echo "ERROR: Installation requires root privileges"; \
		echo "Please run: sudo make install"; \
		exit 1; \
	fi

# Check system requirements
check-requirements:
	@echo "Checking system requirements..."
	@which systemctl >/dev/null || { echo "ERROR: systemd required"; exit 1; }
	@[ -d /etc/systemd/system ] || { echo "ERROR: systemd not properly installed"; exit 1; }
	@echo "✅ System requirements met"

# Create system user and group
install-user: check-root
	@echo "Creating user and group..."
	@if ! getent group $(VPN_GROUP) >/dev/null 2>&1; then \
		groupadd --system $(VPN_GROUP); \
		echo "✅ Created group: $(VPN_GROUP)"; \
	else \
		echo "✅ Group already exists: $(VPN_GROUP)"; \
	fi
	@if ! getent passwd $(VPN_USER) >/dev/null 2>&1; then \
		useradd --system --gid $(VPN_GROUP) --home-dir $(LIB_DIR) \
		        --shell /usr/sbin/nologin --comment "ProtonVPN System User" \
		        $(VPN_USER); \
		echo "✅ Created user: $(VPN_USER)"; \
	else \
		echo "✅ User already exists: $(VPN_USER)"; \
	fi

# Create directory structure
install-dirs: check-root install-user
	@echo "Creating directory structure..."
	@install -d -m 0755 $(BIN_DIR)
	@install -d -m 0755 $(LIB_DIR)
	@install -d -m 0750 -o $(VPN_USER) -g $(VPN_GROUP) $(CONFIG_DIR)
	@install -d -m 0750 -o $(VPN_USER) -g $(VPN_GROUP) $(LOG_DIR)
	@install -d -m 0755 -o $(VPN_USER) -g $(VPN_GROUP) $(RUN_DIR)
	@echo "✅ Directory structure created"

# Validate components before installation
validate-components:
	@echo "Validating required components..."
	@missing_components=0; \
	for exe in $(EXECUTABLES); do \
		if [ ! -f "src/$$exe" ]; then \
			echo "❌ ERROR: Required component missing: $$exe"; \
			missing_components=$$((missing_components + 1)); \
		fi; \
	done; \
	if [ $$missing_components -gt 0 ]; then \
		echo "❌ Installation cannot proceed - $$missing_components components missing"; \
		exit 1; \
	fi; \
	echo "✅ All required components present"

# Install executables
install-bins: check-root install-dirs validate-components
	@echo "Installing executables..."
	@for exe in $(EXECUTABLES); do \
		echo "Installing $$exe..."; \
		if ! install -m 0755 "src/$$exe" "$(BIN_DIR)/$$exe"; then \
			echo "❌ ERROR: Failed to install $$exe"; \
			exit 1; \
		fi; \
		echo "✅ Installed: $$exe"; \
	done
	@if [ -f "src/protonvpn-updater-daemon-secure.sh" ]; then \
		install -m 0755 "src/protonvpn-updater-daemon-secure.sh" \
		               "$(BIN_DIR)/protonvpn-updater-daemon-secure.sh"; \
		echo "✅ Installed: protonvpn-updater-daemon-secure.sh"; \
	fi
	@for script in $(SCRIPTS); do \
		if [ -f "$$script" ]; then \
			install -m 0755 "$$script" "$(BIN_DIR)/$$(basename $$script)"; \
			echo "✅ Installed: $$(basename $$script)"; \
		else \
			echo "⚠️  Warning: $$script not found"; \
		fi; \
	done

# Create and install configuration files
install-configs: check-root install-dirs
	@echo "Creating production configuration files..."
	@mkdir -p config
	@echo "# ProtonVPN Production Configuration" > config/production.conf
	@echo "VPN_ROOT=$(LIB_DIR)" >> config/production.conf
	@echo "VPN_BIN_DIR=$(BIN_DIR)" >> config/production.conf
	@echo "VPN_LOG_DIR=$(LOG_DIR)" >> config/production.conf
	@echo "VPN_RUN_DIR=$(RUN_DIR)" >> config/production.conf
	@echo "VPN_CONFIG_DIR=$(CONFIG_DIR)" >> config/production.conf
	@install -m 0640 -o $(VPN_USER) -g $(VPN_GROUP) config/production.conf $(CONFIG_DIR)/
	@echo "✅ Production configuration created"

# Install runit service files
install-runit: check-root
	@echo "Installing runit service files..."
	@install -d -m 0755 $(SERVICE_DIR)
	@for service_dir in sv/*; do \
		if [ -d "$$service_dir" ]; then \
			service_name=$$(basename "$$service_dir"); \
			echo "Installing runit service: $$service_name"; \
			cp -r "$$service_dir" "$(SERVICE_DIR)/"; \
			chmod +x "$(SERVICE_DIR)/$$service_name/run"; \
			if [ -f "$(SERVICE_DIR)/$$service_name/log/run" ]; then \
				chmod +x "$(SERVICE_DIR)/$$service_name/log/run"; \
			fi; \
			echo "✅ Installed: $$service_name"; \
		fi; \
	done
	@echo "✅ Runit services installed to $(SERVICE_DIR)"

# Full installation
install: check-root check-requirements install-user install-dirs install-bins install-configs install-runit
	@echo ""
	@echo "🎉 ProtonVPN Management System installed successfully!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Start services: sudo make start-services"
	@echo "  2. Enable at boot: sudo make enable-services"
	@echo "  3. Check status: sudo sv status /etc/service/protonvpn-*"
	@echo ""
	@echo "Service management:"
	@echo "  - Start all: sudo make start-services"
	@echo "  - Stop all:  sudo make stop-services"
	@echo "  - Status:    sudo sv status /etc/service/protonvpn-*"
	@echo "  - Advanced:  sudo /usr/local/bin/protonvpn-service-manager help"

# Service management
enable-services: check-root
	@echo "Enabling runit services at boot..."
	@install -d -m 0755 $(RUNIT_SERVICE_DIR)
	@for service in $(SERVICE_DIR)/protonvpn-*; do \
		if [ -d "$$service" ]; then \
			service_name=$$(basename "$$service"); \
			if [ ! -L "$(RUNIT_SERVICE_DIR)/$$service_name" ]; then \
				ln -sf "$$service" "$(RUNIT_SERVICE_DIR)/$$service_name"; \
				echo "✅ Enabled: $$service_name"; \
			else \
				echo "✅ Already enabled: $$service_name"; \
			fi; \
		fi; \
	done
	@echo "✅ Services enabled at boot"

start-services:
	@echo "Starting ProtonVPN runit services..."
	@for service in $(RUNIT_SERVICE_DIR)/protonvpn-*; do \
		if [ -L "$$service" ]; then \
			service_name=$$(basename "$$service"); \
			sv up "$$service" && echo "✅ Started: $$service_name" || echo "⚠️ Failed to start: $$service_name"; \
		fi; \
	done
	@echo "✅ Services start command completed"

stop-services:
	@echo "Stopping ProtonVPN runit services..."
	@for service in $(RUNIT_SERVICE_DIR)/protonvpn-*; do \
		if [ -L "$$service" ]; then \
			service_name=$$(basename "$$service"); \
			sv down "$$service" && echo "✅ Stopped: $$service_name" || echo "⚠️ Failed to stop: $$service_name"; \
		fi; \
	done
	@echo "✅ Services stop command completed"

disable-services:
	@echo "Disabling runit services..."
	@for service in $(RUNIT_SERVICE_DIR)/protonvpn-*; do \
		if [ -L "$$service" ]; then \
			service_name=$$(basename "$$service"); \
			sv down "$$service" 2>/dev/null || true; \
			rm -f "$$service"; \
			echo "✅ Disabled: $$service_name"; \
		fi; \
	done
	@echo "✅ Services disabled"

# Uninstallation
uninstall: check-root stop-services disable-services
	@echo "Uninstalling ProtonVPN Management System..."
	@systemctl stop protonvpn.target 2>/dev/null || true
	@systemctl disable protonvpn.target 2>/dev/null || true
	@rm -f $(SYSTEMD_DIR)/protonvpn*.service $(SYSTEMD_DIR)/protonvpn*.target
	@systemctl daemon-reload
	@rm -rf $(CONFIG_DIR) $(LOG_DIR) $(RUN_DIR)
	@for exe in $(EXECUTABLES) protonvpn-updater-daemon-secure.sh; do \
		rm -f "$(BIN_DIR)/$$exe"; \
	done
	@userdel $(VPN_USER) 2>/dev/null || true
	@groupdel $(VPN_GROUP) 2>/dev/null || true
	@echo "✅ ProtonVPN Management System uninstalled"

# Status check
status:
	@echo "ProtonVPN Management System Status:"
	@systemctl is-active protonvpn.target || echo "Services not running"
	@systemctl list-units --type=service --state=running | grep protonvpn || echo "No ProtonVPN services running"

# Development helpers
dev-install: install-dirs install-bins install-configs
	@echo "✅ Development installation complete (no systemd services)"

dev-test:
	@echo "Testing development installation..."
	@$(BIN_DIR)/status-dashboard --version || echo "status-dashboard test failed"
	@$(BIN_DIR)/health-monitor --help >/dev/null || echo "health-monitor test failed"
	@echo "✅ Development test complete"

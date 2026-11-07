# ProtonVPN Manager - Simplified Installation
# ABOUTME: Installation management for simplified ProtonVPN manager
# ABOUTME: Handles basic installation without enterprise service infrastructure

.PHONY: all help

all: help

help:
	@echo "ProtonVPN Manager - Simplified Edition"
	@echo ""
	@echo "This is a simple VPN management tool."
	@echo "Installation is handled by install.sh script."
	@echo ""
	@echo "To install:"
	@echo "  ./install.sh   (as your normal user; it uses sudo itself)"
	@echo ""
	@echo "To uninstall:"
	@echo "  sudo ./uninstall.sh"

#!/bin/bash
# ABOUTME: Docker smoke test orchestrator - test installation across multiple distributions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test distributions
DISTRIBUTIONS=("arch" "artix" "ubuntu")

# Project root (two levels up from this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

log_header() {
	echo -e "${BLUE}========================================${NC}"
	echo -e "${BLUE}  $1${NC}"
	echo -e "${BLUE}========================================${NC}"
}

log_info() {
	echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Test tracking
TOTAL_DISTROS=0
PASSED_DISTROS=0
FAILED_DISTROS=0

test_distribution() {
	local distro="$1"
	local dockerfile="Dockerfile.$distro"
	local image_name="vpn-manager-test-$distro"

	((TOTAL_DISTROS++))

	log_header "Testing on $distro"

	# Build image
	log_info "Building Docker image: $image_name"
	if docker build -f "$PROJECT_ROOT/tests/smoke/docker/$dockerfile" -t "$image_name" "$PROJECT_ROOT" >/dev/null 2>&1; then
		log_success "Image built: $image_name"
	else
		log_error "Failed to build image: $image_name"
		((FAILED_DISTROS++))
		return 1
	fi

	# Run tests
	log_info "Running smoke tests on $distro"
	if docker run --rm "$image_name"; then
		log_success "Smoke tests passed on $distro"
		((PASSED_DISTROS++))
		return 0
	else
		log_error "Smoke tests failed on $distro"
		((FAILED_DISTROS++))
		return 1
	fi
}

main() {
	log_header "Docker Smoke Test Suite"
	echo ""

	# Check Docker is available
	if ! command -v docker &>/dev/null; then
		log_error "Docker is not installed or not in PATH"
		exit 1
	fi

	# Test each distribution
	for distro in "${DISTRIBUTIONS[@]}"; do
		test_distribution "$distro"
		echo ""
	done

	# Summary
	log_header "Docker Test Summary"
	echo -e "Total Distributions: ${TOTAL_DISTROS}"
	echo -e "${GREEN}Passed: ${PASSED_DISTROS}${NC}"
	echo -e "${RED}Failed: ${FAILED_DISTROS}${NC}"
	echo ""

	if [[ $FAILED_DISTROS -eq 0 ]]; then
		log_success "All Docker tests passed! 🎉"
		echo ""
		echo "✅ Installation verified on all distributions"
		exit 0
	else
		log_error "Some Docker tests failed!"
		echo ""
		echo "❌ Installation failed on $FAILED_DISTROS distribution(s)"
		exit 1
	fi
}

main "$@"

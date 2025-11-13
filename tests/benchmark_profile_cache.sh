#!/bin/bash
# ABOUTME: Performance benchmark for profile caching (Issue #63)
# ABOUTME: Verifies 90% improvement target (500ms → <100ms)

set -euo pipefail

PROJECT_DIR="$(realpath "$(dirname "$0")/..")"
VPN_DIR="$PROJECT_DIR/src"

# Setup test environment
TEST_DIR=$(mktemp -d)
export LOCATIONS_DIR="$TEST_DIR/locations"
export LOG_DIR="$TEST_DIR/log"
mkdir -p "$LOCATIONS_DIR" "$LOG_DIR"

# Create realistic number of test profiles (100 profiles)
echo "Creating 100 test profiles..."
for i in {1..40}; do
    cat > "$LOCATIONS_DIR/se-$i.ovpn" << EOF
remote 192.168.1.$i 1194
proto udp
dev tun
EOF
done

for i in {1..30}; do
    cat > "$LOCATIONS_DIR/dk-$i.ovpn" << EOF
remote 192.168.2.$i 1194
proto udp
dev tun
EOF
done

for i in {1..20}; do
    cat > "$LOCATIONS_DIR/nl-$i.ovpn" << EOF
remote 192.168.3.$i 1194
proto udp
dev tun
EOF
done

for i in {1..10}; do
    cat > "$LOCATIONS_DIR/us-ny-$i.ovpn" << EOF
remote 192.168.4.$i 1194
proto udp
dev tun
EOF
done

# Source vpn-connector
source "$VPN_DIR/vpn-connector" 2>/dev/null

echo ""
echo "========================================="
echo "Profile Cache Performance Benchmark"
echo "========================================="
echo ""
echo "Test environment:"
echo "  Profiles: 100 (.ovpn files)"
echo "  Countries: 4 (SE, DK, NL, US)"
echo "  Target: <100ms with cache (90% improvement from ~500ms)"
echo ""

# Benchmark 1: Direct find operations (baseline - no cache)
echo "Benchmark 1: Direct find (baseline - no cache)"
echo "---------------------------------------------"

# Clear any existing cache
rm -f "$LOG_DIR/vpn_profiles.cache"

# Measure direct find time (5 iterations for stability)
total_baseline=0
for iter in {1..5}; do
    start=$(date +%s%N)
    find "$LOCATIONS_DIR" -maxdepth 3 -xtype f -name "*.ovpn" 2>/dev/null | sort > /dev/null
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    total_baseline=$((total_baseline + duration))
done
baseline_avg=$((total_baseline / 5))

echo "  Average time (5 runs): ${baseline_avg}ms"
echo ""

# Benchmark 2: Cached operations (cold cache - first call)
echo "Benchmark 2: Cached operation (cold cache - first call)"
echo "-------------------------------------------------------"

# Clear cache
rm -f "$LOG_DIR/vpn_profiles.cache"

# Measure cold cache time (includes cache build)
start=$(date +%s%N)
get_cached_profiles > /dev/null
end=$(date +%s%N)
cold_cache_ms=$(( (end - start) / 1000000 ))

echo "  First call (builds cache): ${cold_cache_ms}ms"
echo ""

# Benchmark 3: Cached operations (warm cache - subsequent calls)
echo "Benchmark 3: Cached operation (warm cache - subsequent calls)"
echo "------------------------------------------------------------"

# Measure warm cache time (5 iterations)
total_warm=0
for iter in {1..5}; do
    start=$(date +%s%N)
    get_cached_profiles > /dev/null
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    total_warm=$((total_warm + duration))
done
warm_cache_avg=$((total_warm / 5))

echo "  Average time (5 runs): ${warm_cache_avg}ms"
echo ""

# Benchmark 4: Full operation comparison (list_profiles)
echo "Benchmark 4: Full operation comparison (list_profiles)"
echo "------------------------------------------------------"

# Clear cache for baseline
rm -f "$LOG_DIR/vpn_profiles.cache"

# Measure list_profiles without cache (modify temporarily)
start=$(date +%s%N)
list_profiles > /dev/null 2>&1
end=$(date +%s%N)
list_with_cache=$(( (end - start) / 1000000 ))

echo "  list_profiles with cache: ${list_with_cache}ms"
echo ""

# Calculate improvement
echo "========================================="
echo "Performance Results"
echo "========================================="
echo ""
echo "Baseline (direct find):       ${baseline_avg}ms"
echo "Cold cache (first call):      ${cold_cache_ms}ms"
echo "Warm cache (subsequent):      ${warm_cache_avg}ms"
echo "Full operation (with cache):  ${list_with_cache}ms"
echo ""

# Calculate improvement percentage
if [[ $baseline_avg -gt 0 ]]; then
    improvement=$(( 100 - (warm_cache_avg * 100 / baseline_avg) ))
    echo "Performance improvement: ${improvement}%"
    echo ""

    # Verify target achievement
    if [[ $improvement -ge 90 ]]; then
        echo "✓ TARGET ACHIEVED: ≥90% improvement"
        echo "✓ Warm cache operations: ${warm_cache_avg}ms < 100ms"
        result=0
    else
        echo "✗ TARGET MISSED: ${improvement}% < 90%"
        result=1
    fi

    # Additional check for <100ms target
    if [[ $warm_cache_avg -lt 100 ]]; then
        echo "✓ Performance target met: ${warm_cache_avg}ms < 100ms"
    else
        echo "✗ Performance target missed: ${warm_cache_avg}ms ≥ 100ms"
        result=1
    fi
else
    echo "✗ Baseline measurement failed"
    result=1
fi

echo ""
echo "========================================="

# Cleanup
rm -rf "$TEST_DIR"

if [[ $result -eq 0 ]]; then
    echo "✓ All performance benchmarks passed!"
    exit 0
else
    echo "✗ Some performance targets not met"
    exit 1
fi

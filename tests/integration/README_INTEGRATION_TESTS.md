# Profile Cache Integration Tests (Issue #142)

## Overview

This directory contains **integration tests** for the profile cache system. Unlike unit tests which validate isolated functions, these tests verify **end-to-end behavior** across multiple VPN operations and real-world workflows.

## Test Philosophy: Integration vs Unit

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|------------------|
| **Location** | `tests/unit/test_profile_cache.sh` | `tests/integration/test_profile_cache_integration.sh` |
| **What** | Single function behavior | Multi-function workflows |
| **Example** | `rebuild_cache()` creates file | `vpn list` → cache → `vpn list` (reuses cache) |
| **Speed** | Fast (<1s per test) | Slower (realistic data volumes) |
| **Focus** | Correctness in isolation | Correctness in real usage |

## Five Core Integration Tests

### Test 1: Cache Persistence Across Operations
**Purpose**: Verify cache survives and accelerates multiple sequential commands

**Workflow**:
1. Cold start: `list_profiles` → builds cache
2. Warm run: `list_profiles` again → **must NOT rebuild**
3. Country filter: `find_profiles_by_country "se"` → uses cache
4. Country enum: `get_available_countries` → uses cache
5. Verify cache mtime unchanged throughout (proof of reuse)

**Validates**:
- Cache created on first operation
- Cache reused (not rebuilt) on subsequent operations
- All operations return consistent results
- Cache metadata stable across operations

---

### Test 2: Cache Invalidation on Profile Changes
**Purpose**: Verify cache automatically rebuilds when profiles change

**Workflow**:
1. Start: 10 profiles → build cache
2. Add 5 profiles → next operation rebuilds (15 total)
3. Remove 3 profiles → next operation rebuilds (12 total)
4. Verify cache mtime changes after each modification
5. Verify counts accurate after each rebuild

**Validates**:
- Directory mtime changes trigger invalidation
- Rebuilt cache reflects current filesystem state
- No stale data returned to users

---

### Test 3: Performance Validation
**Purpose**: Prove cache delivers measurable performance improvement

**Workflow**:
1. Create 100 realistic profiles (se, dk, nl, us)
2. Benchmark uncached operations (3x runs):
   - Direct `find` + `sort`
   - Measure average time: `T_uncached`
3. Benchmark cached operations (3x runs):
   - First: build cache (excluded from timing)
   - Subsequent: `get_cached_profiles`
   - Measure average time: `T_cached`
4. Calculate improvement: `(T_uncached - T_cached) / T_uncached * 100`

**Success Criteria**:
- Cached operations **≥50% faster** than uncached
- Cached operations **<100ms** (Issue #63 target)
- Improvement percentage calculated and verified

**Expected Performance** (100 profiles on typical SSD):
- Uncached: ~300-500ms (find + sort filesystem scan)
- Cached: ~20-50ms (grep + read from cache file)
- Improvement: ~80-90%

---

### Test 4: Output Consistency
**Purpose**: Verify cache returns **identical** results to uncached operations

**Workflow**:
1. Create diverse profiles:
   - 15 se profiles
   - 10 dk profiles
   - 8 nl profiles
   - 2 secure core profiles (is-se-01, ch-us-01)
2. Test each command **uncached** (clear cache first):
   - `list_profiles`
   - `find_profiles_by_country "se"`
   - `get_available_countries`
   - `detect_secure_core_profiles`
3. Test each command **cached** (build cache once):
   - Same commands, using cache
4. Compare outputs byte-for-byte (diff)

**Validates**:
- Zero differences between cached and uncached outputs
- Same profile count, same order, same paths
- Edge cases handled identically (empty results, filters)

---

### Test 5: Recovery from Cache Corruption
**Purpose**: Verify system gracefully handles cache failures mid-workflow

**Attack Scenarios**:
1. **Truncated cache**: Overwrite with garbage data
2. **Missing cache**: Delete file mid-operation
3. **Symlink attack**: Replace cache with symlink to `/etc/passwd`
4. **Permission denial**: Set cache to `000` (unreadable)

**Validation**:
- All attacks trigger cache rebuild or fallback to direct find
- No operation failures despite corruption
- Final results always accurate (match actual filesystem)
- Security validations prevent exploits
- Rebuilt cache has correct permissions (600)

---

## Running the Tests

### Run All Integration Tests
```bash
./tests/integration/test_profile_cache_integration.sh
```

### Run Single Test (for debugging)
Edit the file and comment out unwanted tests at the bottom:
```bash
# test_cache_persists_across_operations || true
# test_cache_invalidation_on_profile_changes || true
test_cache_performance_improvement || true  # Only run this one
# test_cache_output_consistency || true
# test_cache_corruption_recovery || true
```

### Expected Output
```
=========================================
Profile Cache Integration Tests
=========================================

These tests validate end-to-end cache behavior
across multiple VPN operations and real-world scenarios.

Testing: Cache persists across multiple sequential operations ... ✓ PASS
Testing: Cache invalidates when profiles added or removed ... ✓ PASS
Testing: Cache provides measurable performance improvement ... ✓ PASS
Testing: Cache returns identical output to uncached operations ... ✓ PASS
Testing: System recovers gracefully from cache corruption ... ✓ PASS

=========================================
Integration Test Summary
=========================================
Tests run:    5
Tests passed: 5
Tests failed: 0
=========================================
✓ All integration tests passed!
```

---

## Test Isolation Strategy

### How Tests Avoid Production Contamination

1. **Temporary Directories**: Each test creates isolated `$TEST_TEMP_DIR`
   ```bash
   TEST_TEMP_DIR=$(mktemp -d)
   export LOCATIONS_DIR="$TEST_TEMP_DIR/locations"
   export LOG_DIR="$TEST_TEMP_DIR/log"
   ```

2. **Environment Overrides**: Tests export custom paths
   ```bash
   export PROFILE_CACHE="$LOG_DIR/vpn_profiles.cache"
   ```

3. **Cleanup Guarantees**: `cleanup_integration_test_env()` removes all temp files
   ```bash
   [[ -n "${TEST_TEMP_DIR:-}" ]] && rm -rf "$TEST_TEMP_DIR"
   ```

4. **No Production Data**: Tests never touch `~/.config/vpn/` or system paths

---

## Performance Expectations

### Test Execution Time
- **Test 1**: ~2-3 seconds (multiple operations)
- **Test 2**: ~5-6 seconds (includes sleep for mtime resolution)
- **Test 3**: ~4-5 seconds (100 profiles, 6 benchmarks)
- **Test 4**: ~3-4 seconds (diverse profile set, 8 comparisons)
- **Test 5**: ~3-4 seconds (multiple corruption scenarios)
- **Total**: ~18-22 seconds for all 5 tests

### Profile Scaling
Tests are designed to handle realistic data volumes:
- Test 1: 23 profiles (se, dk, nl)
- Test 2: 10-15 profiles (dynamic changes)
- Test 3: 100 profiles (performance benchmark)
- Test 4: 35 profiles (diverse set)
- Test 5: 20 profiles (corruption recovery)

---

## Debugging Failed Tests

### Test 1 Failure: "Cache was rebuilt when it should have been reused"
**Cause**: Cache invalidation logic too aggressive
**Fix**: Check `is_cache_valid()` - verify mtime comparison works correctly

### Test 2 Failure: "Cache mtime unchanged after adding profiles"
**Cause**: Filesystem mtime resolution issue or cache not detecting changes
**Fix**:
- Increase sleep time (some filesystems have 2s resolution)
- Verify `LOCATIONS_DIR` mtime updates when files added

### Test 3 Failure: "Cached not faster than uncached"
**Cause**: Cache overhead or slow file I/O
**Fix**:
- Check disk I/O (SSD vs HDD)
- Verify cache file permissions (must be 600)
- Profile `get_cached_profiles` with `time` command

### Test 4 Failure: "Output differs between cached and uncached"
**Cause**: Sort order mismatch or filtering inconsistency
**Fix**:
- Verify both paths use same `sort` command
- Check security filtering in `get_cached_profiles`

### Test 5 Failure: "Failed to recover from corruption"
**Cause**: Missing fallback logic or insufficient error handling
**Fix**:
- Verify `get_cached_profiles` has try-catch for corrupt cache
- Check `rebuild_cache` returns success after recovery

---

## Integration with CI/CD

### GitHub Actions Workflow
```yaml
- name: Run Integration Tests
  run: |
    chmod +x tests/integration/test_profile_cache_integration.sh
    ./tests/integration/test_profile_cache_integration.sh
```

### Pre-commit Hook
Not recommended for integration tests (too slow). Use unit tests in pre-commit instead.

### Make Target
```makefile
test-integration:
	./tests/integration/test_profile_cache_integration.sh

test-all: test-unit test-integration
```

---

## Relationship to Unit Tests

### What Unit Tests Already Cover
- ✅ `rebuild_cache()` creates file
- ✅ `is_cache_valid()` returns correct boolean
- ✅ Cache file has 600 permissions
- ✅ Cache contains metadata header
- ✅ Security filtering (path traversal, symlinks)
- ✅ Edge cases (corruption, missing files)

### What Integration Tests Add
- ✅ Cache behavior across **multiple sequential operations**
- ✅ Real-world command workflows (`list`, `find_by_country`)
- ✅ Performance improvement in **realistic scenarios**
- ✅ Output consistency between cached and uncached paths
- ✅ System resilience when cache and VPN operations interact

**Bottom Line**: Unit tests ensure **individual functions work**. Integration tests ensure **the system works as a whole**.

---

## Future Enhancements

### Potential Additional Tests
1. **Concurrent Operations**: Multiple processes accessing cache simultaneously
2. **Large Profile Sets**: Test with 1000+ profiles (stress test)
3. **Network Filesystem**: Test cache on NFS/CIFS (high latency)
4. **Memory Pressure**: Test cache behavior under low memory
5. **Disk Full**: Test cache rebuild when disk space exhausted

### Integration with Other Systems
- **Performance Testing**: Combine with `benchmark_profile_cache.sh`
- **End-to-End Tests**: Integrate with `e2e_tests.sh` for full workflow validation
- **Security Tests**: Cross-reference with `tests/security/` for attack scenarios

---

## Maintenance Notes

### When to Update Integration Tests
- ✅ Cache format changes (metadata fields added/removed)
- ✅ New VPN commands added that use cache
- ✅ Performance targets change (e.g., <50ms instead of <100ms)
- ✅ Security validations enhanced
- ✅ New profile types added (e.g., WireGuard `.conf` files)

### Test Data Versioning
If test failures occur after code changes:
1. Run unit tests first (faster feedback)
2. If unit tests pass but integration fails → workflow issue
3. If both fail → function-level bug

### Code Coverage
Integration tests focus on **workflow correctness**, not code coverage. Use unit tests for coverage metrics.

---

## Contact & Support

**Issue**: #142 - Profile Cache Integration Tests
**Related Issues**:
- #63 - Profile Cache Performance (90% improvement)
- #143 - Cache Security (path validation)
- #144 - Edge Case Handling
- #155 - Metadata Validation

**Documentation**:
- Unit tests: `tests/unit/test_profile_cache.sh`
- Benchmark: `tests/benchmark_profile_cache.sh`
- Implementation: `src/vpn-connector` (lines 133-330)

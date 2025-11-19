# Integration Tests Quick Reference

## Run Tests

```bash
# Run all 5 integration tests
./tests/integration/test_profile_cache_integration.sh

# Expected output
Testing: Cache persists across multiple sequential operations ... ✓ PASS
Testing: Cache invalidates when profiles added or removed ... ✓ PASS
Testing: Cache provides measurable performance improvement ... ✓ PASS
Testing: Cache returns identical output to uncached operations ... ✓ PASS
Testing: System recovers gracefully from cache corruption ... ✓ PASS
```

---

## Test Summary

| Test | What It Does | Time | Pass Criteria |
|------|-------------|------|---------------|
| **1. Persistence** | Cache survives multiple operations | 2-3s | Cache mtime unchanged |
| **2. Invalidation** | Cache rebuilds on profile changes | 5-6s | Cache reflects additions/removals |
| **3. Performance** | Cache is faster than uncached | 4-5s | ≥50% improvement, <100ms |
| **4. Consistency** | Cached = uncached output | 3-4s | Zero differences (diff) |
| **5. Recovery** | Graceful corruption handling | 3-4s | All attacks recovered |

**Total Time**: 18-22 seconds

---

## Quick Debugging

### Test 1 Failed
**Error**: "Cache was rebuilt when it should have been reused"

**Check**:
```bash
# Verify cache mtime stable
stat -c %Y $LOG_DIR/vpn_profiles.cache
# Should be same before/after operations
```

**Fix**: Check `is_cache_valid()` logic

---

### Test 2 Failed
**Error**: "Cache mtime unchanged after adding profiles"

**Check**:
```bash
# Verify directory mtime updates
stat -c %Y $LOCATIONS_DIR
touch $LOCATIONS_DIR/test.ovpn
stat -c %Y $LOCATIONS_DIR  # Should be newer
```

**Fix**: Increase sleep time (filesystem mtime resolution)

---

### Test 3 Failed
**Error**: "Cached not faster than uncached"

**Check**:
```bash
# Profile cache read speed
time get_cached_profiles >/dev/null

# Compare with direct find
time find $LOCATIONS_DIR -name "*.ovpn" | sort >/dev/null
```

**Fix**: Check disk I/O, cache file permissions (must be 600)

---

### Test 4 Failed
**Error**: "Output differs between cached and uncached"

**Check**:
```bash
# Compare outputs
diff -u <(uncached_output) <(cached_output)
```

**Fix**: Verify sort order, security filtering consistent

---

### Test 5 Failed
**Error**: "Failed to recover from corruption"

**Check**:
```bash
# Verify corruption detection
echo "garbage" > $PROFILE_CACHE
get_cached_profiles  # Should rebuild
```

**Fix**: Check fallback logic in `get_cached_profiles`

---

## File Locations

| File | Purpose |
|------|---------|
| `test_profile_cache_integration.sh` | Main test suite (5 tests) |
| `README_INTEGRATION_TESTS.md` | Comprehensive documentation |
| `TEST_STRATEGY.md` | Design rationale and principles |
| `QUICK_REFERENCE.md` | This file (cheat sheet) |

---

## Key Concepts

### Integration vs Unit Tests

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|------------------|
| **What** | Single function | Multi-function workflow |
| **Example** | `rebuild_cache()` creates file | `vpn list` → cache → `vpn list` |
| **Speed** | Fast (<1s) | Slower (~20s total) |
| **When** | Every commit | CI/CD pipeline |

### Test Data

| Test | Profiles | Countries | Why |
|------|---------|-----------|-----|
| Test 1 | 23 | se, dk, nl | Multiple operations |
| Test 2 | 10-15 | dynamic | Profile changes |
| Test 3 | 100 | se, dk, nl, us | Performance at scale |
| Test 4 | 35 | se, dk, nl + secure core | Diverse set |
| Test 5 | 20 | recovery | Corruption scenarios |

---

## Performance Targets

### Test 3 Expectations (100 profiles)

| Metric | Target | Typical Result |
|--------|--------|----------------|
| Uncached time | Baseline | ~300-500ms |
| Cached time | <100ms | ~20-50ms |
| Improvement | ≥50% | ~80-90% |

**If targets missed**:
- Check disk type (SSD vs HDD)
- Verify cache file permissions (600)
- Profile with `time` command

---

## Common Commands

### Run Single Test
```bash
# Edit test file, comment out others
vim tests/integration/test_profile_cache_integration.sh

# Comment out unwanted tests
# test_cache_persists_across_operations || true
test_cache_performance_improvement || true  # Only this one
# test_cache_output_consistency || true
```

### Add Debug Output
```bash
# In test function
echo "DEBUG: cache_mtime = $cache_mtime"
echo "DEBUG: profile_count = $profile_count"
```

### Check Test Environment
```bash
# Verify temporary directories
echo "LOCATIONS_DIR = $LOCATIONS_DIR"
echo "LOG_DIR = $LOG_DIR"
echo "PROFILE_CACHE = $PROFILE_CACHE"

# Should all be in /tmp/tmp.XXXXXXXXXX
```

---

## CI/CD Integration

### GitHub Actions
```yaml
- name: Run Integration Tests
  run: |
    chmod +x tests/integration/test_profile_cache_integration.sh
    ./tests/integration/test_profile_cache_integration.sh
```

### Makefile
```makefile
test-integration:
	./tests/integration/test_profile_cache_integration.sh

test-all: test-unit test-integration
	@echo "All tests passed!"
```

---

## Related Issues

- **#142**: Profile Cache Integration Tests (this implementation)
- **#63**: Profile Cache Performance (90% improvement target)
- **#143**: Cache Security (path validation)
- **#144**: Edge Case Handling
- **#155**: Metadata Validation

---

## Getting Help

**Documentation**:
1. Read `README_INTEGRATION_TESTS.md` first
2. Consult `TEST_STRATEGY.md` for design rationale
3. Check this file for quick answers

**Debugging**:
1. Run unit tests first (`tests/unit/test_profile_cache.sh`)
2. If unit tests pass but integration fails → workflow issue
3. If both fail → function-level bug

**Contact**: See Issue #142 for questions

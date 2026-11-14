# Session Handoff: Issue #273 - overridable PID file, remaining test gaps, unregistered test files

**Date**: 2026-11-14
**Issue**: #273 - test: remaining unsafe or unverifiable paths in the cleanup tests, and test files run by nothing
**PR**: draft, see `gh pr list --head test/issue-273-pid-file-and-unregistered-tests`
**Branch**: `test/issue-273-pid-file-and-unregistered-tests` (from master `b9e4821`)

## ✅ Completed Work

- **Merged** (Doctor Hubert's go-ahead in the session): PR #270 (#269 closed) and
  PR #274 (#271 closed), both squashed.
- **`src/` change**: `VPN_PID_FILE` can be set in the environment (default
  `/var/run/openvpn.pid`) in `src/vpn-manager`, `src/vpn-connector` and `uninstall.sh`.
  `full_cleanup` no longer removes `/tmp/vpn_*.cache` and `/tmp/vpn_*.lock`.
- **Test environment** (`setup_test_env`): `VPN_PID_FILE` and `VPN_SESSION_DIR` point
  into the test directory (the caller's values are restored afterwards); `curl` is
  blocked, so `vpn status` makes no network lookup in tests.
- **`tests/cleanup_tests.sh`**: real stale-PID tests (warning until cleanup; a stale
  PID naming another process does not get it killed; sudo is asked for a PID file the
  user cannot remove; nothing is removed from the shared `/tmp`). Written first and
  seen failing before the `src/` change.
- **`tests/health_command_functionality_tests.sh`**: waits for its fake processes
  (`start_fake_openvpn` in the framework) instead of fixed sleeps, skips a count only
  while a foreign OpenVPN-like process runs, fails when a fake does not start, times
  `vpn health` without `bc`.
- **Overlap removed**: four tests from `simple_regression_tests.sh`, one from
  `process_safety_tests.sh` (covered by the health and emergency-reset suites, or
  testing a file that does not exist). The lock test of `process_safety_tests.sh`
  used `/tmp` and relied on the removed legacy cleanup: it uses the lock directory now.
- **Keep-or-remove decision per unregistered file** (each was run in a user, mount,
  network and PID namespace first, so nothing could reach the machine):

  | File | Decision | Why |
  | --- | --- | --- |
  | `networkmanager_preservation_tests.sh` | removed | duplicate of the emergency-reset suite; unguarded real `cleanup`, `kill`, `emergency-reset` |
  | `process_detection_accuracy_tests.sh` | removed | tested a pattern written in the test, not the one in `src/`; `unit/test_process_detection.sh` covers the real one |
  | `phase8_2_performance_validation_tests.sh` | removed | real `vpn best`/`connect` with the user's HOME, unguarded |
  | `phase8_3_edge_case_tests.sh` | removed | real `vpn connect`; most tests pass in every branch; fills 10 % of the free `/tmp` |
  | `test_comprehensive_runner.sh`, `test_mocking_framework.sh` | removed | runner and mocks for the removed service/systemd system |
  | `test_installation.sh` | removed | real `sudo useradd`; tests a layout that no longer exists |
  | `test_installation_e2e.sh`, `test_installation_integration.sh` | removed | run the real `install.sh` on the machine; CI installs and runs the smoke tests |
  | `test_standardized_status_output.sh` | removed | source greps for removed functions; 3 failing; reports "pass" after "fail" |
  | `test_github_workflows_extended.sh` | removed | tests regular expressions defined in the test itself; 1 failing |
  | `integration/test_profile_cache_integration.sh` (+ its three docs) | removed | same ground as the 27 tests of `unit/test_profile_cache.sh`; wrote into the real state directory |
  | `test_security_validation.sh` | removed | 7 of 8 tests target files that do not exist; the live one (malicious country codes) moved to `unit/test_country_selection.sh` |
  | `test_vpn_utils.sh` | kept, registered | sound unit tests of `src/vpn-utils`; now uses a private temp directory |
  | `security/test_pid_validation.sh` | kept, registered | 88 checks of `validate_pid`/`validate_openvpn_process`; fixed: hung forever at the first process test, leaked fake processes, assumed `pid_max` 4194304 (32768 here) |
  | `benchmark_profile_cache.sh` | kept, run by hand | benchmark for #272; fixed: replaced the user's real profile cache with test profiles |
  | `test_github_workflows.sh` | kept, run by hand | not on the issue's list but also run by nothing; runs the unit suite itself, so it cannot be part of it |
  | `smoke/*.sh` | kept | run by CI; `smoke/docker/run_docker_tests.sh` by hand |

- **Contract** (`tests/unit/test_suite_safety.sh`): the two registered files are in the
  isolated-run and registration checks; new `test_no_test_script_is_run_by_nothing`
  fails when a script under `tests/` is neither run by a runner or CI nor on the
  run-by-hand list (checked with a probe file).
- **Docs**: `tests/README_TESTING.md` rewritten (it described the removed system);
  `docs/MACHINE-VALIDATION.md` test section updated.

## 🎯 Current Project State

**Tests**: ✅ `run_tests.sh` 111 passed / 0 failed; contract 127/127
**Branch**: pushed
**Machine**: installed components are master `1870caf` (`src/` unchanged by #270/#274);
VPN disconnected, kill switch off. After this PR merges, `src/vpn-manager`,
`src/vpn-connector` and `uninstall.sh` differ from the installed copy: reinstall.

### Agent Validation Status

- security-validator: 4/5, no must-fix. The override is equal in trust to
  `VPN_SESSION_DIR` (the user controls their own environment; sudo matches the literal
  command line; the root hooks do not take a user's environment). Done: `uninstall.sh`
  honours the override; numeric guard in the PID test cleanup.
- code-quality-analyzer: 4.2/5, no must-fix. Done: caller's `VPN_PID_FILE` /
  `VPN_SESSION_DIR` restored instead of unset, runner text read once in the orphan
  check, outdated comment and dead alternative in `simple_regression_tests.sh`,
  failure message in `start_fake_openvpn`.
- test-automation-qa: 3.5/5 before fixes. Must-fix done: the health tests fail (not
  skip) when a fake process does not start, and skip only for foreign processes.
  Done: orphan check ignores comment lines; country-code test asserts exit 0 and a
  listed profile, fake NUL entries dropped, `-h`/`--` added. Not done: unique name
  prefix for the PID tests' fake processes (only matters if suites ever run in
  parallel).
- Scores are from before the fixes; the agents were not re-run afterwards.
- Reviewer's "possible gaps" from the removals, checked: the removed permission and
  PID-file tests of `test_security_validation.sh` compared values the test set itself;
  the installation tests exercised a Makefile layout that is gone.

## 🚀 Next Session Priorities

1. Doctor Hubert: review and merge this PR, then reinstall (`./install.sh`)
2. #272 (cache rebuild about 25 ms per profile; `tests/benchmark_profile_cache.sh`)
3. Other maintenance in `SESSION_HANDOVER.md`, then #223 WireGuard PRD

## 📝 Startup Prompt for Next Session

See `SESSION_HANDOVER.md`.

## 📚 Key Reference Documents

- `SESSION_HANDOVER.md`
- `tests/README_TESTING.md` (how the suite is organised, how to add a test file)
- `tests/unit/test_suite_safety.sh` (the suite's safety contract)

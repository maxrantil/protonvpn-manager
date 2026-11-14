# Testing

How the test suite is organised, how to run it, and what keeps it safe on a
machine that is in use. The safety rules themselves are tested:
`tests/unit/test_suite_safety.sh`.

## Running

```bash
cd tests
./run_tests.sh              # everything (about 5 minutes)
./run_tests.sh --unit-only  # unit suite only
bash unit/test_kill_switch.sh   # one file
```

The suite is safe to run while you work, also next to a running VPN. See
"Running the test suite on this machine" in `docs/MACHINE-VALIDATION.md` for
the two parts that can use the real VPN (`VPN_LIVE_TESTS=1`).

## What runs what

| Runner | Runs |
| --- | --- |
| `run_tests.sh` | `unit_tests.sh`, `integration_tests.sh`, `e2e_tests.sh`, `realistic_connection_tests.sh`, `process_safety_tests.sh`, `test_flock_lock_implementation.sh`, `test_exit_codes.sh` (live, skipped by default) |
| `unit_tests.sh` | its own tests, then every file in its `focused_suites` list (`unit/`, `security/`, `integration/` and the single-topic files in `tests/`) |
| `integration_tests.sh` | its own tests and `simple_regression_tests.sh` |
| CI (`.github/workflows/run-tests.yml`) | `run_tests.sh`, then `install.sh` and `smoke/run_smoke_tests.sh` |

Run by hand, on purpose:

- `benchmark_profile_cache.sh`: timings of the profile cache (uses a temporary HOME)
- `test_github_workflows.sh`: local check of the workflow rules; runs the unit
  suite and pre-commit itself
- `smoke/docker/run_docker_tests.sh`: installation in Docker images
  (`smoke/README.md`)

## Adding a test file

1. Start the file with the two `# ABOUTME:` lines.
2. Use `test_framework.sh` (`setup_test_env`) or a private `mktemp -d`
   directory. Nothing may be written to the real HOME, the runtime directory
   or a fixed name in `/tmp`.
3. Add the file to `focused_suites` in `unit_tests.sh` (or to the list of
   files run by hand in `unit/test_suite_safety.sh`, with the reason). A
   script under `tests/` that nothing runs fails the safety tests.
4. If the file runs the real scripts (`vpn cleanup`, `kill`, `connect`, …),
   skip while `vpn_session_running` is true and add it to the isolated-run
   list in `unit/test_suite_safety.sh`.

## The test environment (`setup_test_env`)

| Real system | In tests |
| --- | --- |
| `HOME`, `XDG_*` directories | inside a temporary directory |
| `sudo` | refuses; every attempt is logged in `$MOCK_DIR/blocked.log` |
| `curl` | fails (no network lookups); mock it with `mock_command curl …` |
| `/var/run/openvpn.pid` | `VPN_PID_FILE` inside the temporary directory |
| `/run/protonvpn-manager-session` | `VPN_SESSION_DIR` inside the temporary directory |

Helpers for tests that need an OpenVPN-like process: `start_fake_openvpn`
(returns once the scripts' own pattern finds the process) and
`foreign_openvpn_running`.

## Known limit

The scripts find OpenVPN by process name. A user-owned OpenVPN that starts in
the middle of a test run, after the `vpn_session_running` check, can still be
ended by a test that runs `vpn kill` or `vpn cleanup`. A root-owned one (what
this tool starts) is safe: ending it needs sudo, which the tests block.

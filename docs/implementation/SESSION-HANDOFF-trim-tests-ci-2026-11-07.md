# Session Handoff: Trim unrun tests and broken CI workflows

**Date**: 2026-11-07
**Branch**: `chore/trim-tests-ci`

## ✅ Completed Work

- Deleted 31 test files/dirs that no runner, workflow or other test used:
  - 17 targeting components that do not exist (api-server, health-monitor,
    status-dashboard, vpn-notify, vpn-statusbar, vpn-logger, TOTP/credential
    manager, fix-ovpn-*, vpn-network-test, vpn-integration, ...)
  - 13 broken ones: harness bugs (readonly/unbound SCRIPT_DIR/PROJECT_ROOT
    collisions with test_framework.sh, cannot source the connector, wrong
    ./src/vpn path), TDD "RED phase" placeholders for features never built,
    and assertions on behaviour that was deliberately changed
  - `tests/archived/`
- Wired the 17 unrun files that pass into `tests/unit_tests.sh` (focused suites).
- CI: removed `pr-validation.yml` (failed on every PR; reusable calls never
  start, so it showed no check) and `pr-title-check-refactored.yml` (an
  "Example" duplicate of `pr-title-check.yml`) plus its composite action;
  pinned `ludeeus/action-shellcheck@master` to `2.0.0`.

## 🎯 Current Project State

- Kept (environment-specific failures here, may pass in CI): `test_vpn_utils.sh`,
  `security/test_pid_validation.sh`; kept `test_standardized_status_output.sh`
  (edited by the dead-code PR).
- Duplicate push/issue workflows (`push-protection.yml` vs `protect-master.yml`,
  `issue-validation.yml` vs `issue-*.yml`) left in place: both variants work.

## 🚀 Next Session Priorities

1. Decide whether to keep the centralized (maxrantil/.github) or local copies of
   the push/issue workflows, and drop the other.

## 📝 Startup Prompt for Next Session

Consolidate remaining duplicate workflows.

## 📚 Key Reference Documents

- `tests/unit_tests.sh` (focused suites), `.github/workflows/README.md`

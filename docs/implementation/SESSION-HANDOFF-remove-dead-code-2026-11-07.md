# Session Handoff: Remove dead code, fake status views and leftovers

**Date**: 2026-11-07
**Branch**: `chore/remove-dead-code`

## ✅ Completed Work

- Removed `vpn download-configs` / `vpn service` (called non-existent
  `download-engine` / `proton-service`).
- Removed `vpn-manager` status views that printed hard-coded data
  (`status-wcag`, `status-enhanced`, `status-format` json/csv). Kept
  `status --accessible` (real data, WCAG #147).
- `vpn secure`: fails when no Secure Core profiles exist (no silent fallback)
  and picks the fastest Secure Core server.
- Removed unused functions (`cleanup_routes`, `get_default_interface`,
  `vpn_success`, `load_performance_cache`, `resolve_profile_path`) and their
  tests; enterprise leftovers in `config/`, `scripts/protonvpn-service-manager`,
  `core_components.txt`.
- `uninstall.sh` no longer edits shell rc files.
- README/Makefile: correct install command (not `sudo`), log paths, component list.

## 🎯 Current Project State

- No regressions vs master across all test files.

## 🚀 Next Session Priorities

1. PR C (faster connect), PR D (trim unrun tests / CI).

## 📝 Startup Prompt for Next Session

Continue with connect speed-ups and test/CI trimming.

## 📚 Key Reference Documents

- CHANGELOG "Removed"/"Changed"

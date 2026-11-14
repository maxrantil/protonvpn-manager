# Session Handoff: #278 docs name the real runtime file locations

**Date**: 2026-11-14
**Issue**: #278 - docs: user and developer guides name /tmp paths that moved to XDG directories
**PR**: #279 - docs: name the XDG locations of logs, caches and locks instead of /tmp
**Branch**: `docs/issue-278-xdg-paths`

## ✅ Completed Work

- USER_GUIDE, DEPLOYMENT_GUIDE, DEVELOPER_GUIDE: cache reset and log commands use
  `~/.local/state/vpn/` (was `/tmp/vpn_performance.cache`,
  `/tmp/vpn_manager_$(id -u).log`, `/tmp/vpn_connect.log`)
- ARCHITECTURE_OVERVIEW: runtime file tree rebuilt from `src/` (state dir, cache dir,
  runtime lock dir, session dir with `openvpn.log`, PID file and its overrides)
- README: cache reset no longer expands to `/vpn/*.cache` when `XDG_CACHE_HOME` is
  unset; it clears both cache directories
- TROUBLESHOOTING-KILL-SWITCH: OpenVPN log is in `/run/protonvpn-manager-session/`
  (group-readable by the connecting user's group, mode 640)
- Two lint-only commits (blank lines, `text` fences): the lint hook checks whole
  files, and these five had 203 old issues; no wording changed in them

Left alone: `/tmp` scratch files in example commands (CREDENTIAL-PROTECTION,
GIT_HISTORY_CLEANUP_GUIDE, MACHINE-VALIDATION); README line on tests creating files
in `/tmp/` (test behaviour, not a runtime path).

## 🎯 Current Project State

**Tests**: docs only; pre-commit passes. CI running at handoff.
**Branch**: clean, pushed.

### Agent Validation Status

- documentation-knowledge-manager: 4.6/5, pass. Every stated path checked against
  `src/`; lint commit confirmed wording-free. Its two findings (README cache reset,
  kill-switch log path) and the missing session `openvpn.log` are fixed in `bc35c72`.
  Not acted on: `vpn_errors.log` (state dir) and the `.lock` next to the performance
  cache are not in the architecture tree (incomplete, not wrong).
- Out of scope, noted by the agent: `locations/` and `credentials.txt` mentions in
  the guides describe the pre-install layout; not audited.

## 🚀 Next Session Priorities

See `SESSION_HANDOVER.md`.

## 📚 Key Reference Documents

- `SESSION_HANDOVER.md`
- `src/vpn-manager:33-65`, `src/vpn-connector:44-95` (where the paths come from)

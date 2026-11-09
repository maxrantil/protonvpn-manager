# Session Handoff: Replace markdownlint-cli hook with rumdl

**Date**: 2026-11-09
**Issue**: #239 - markdownlint pre-commit hook fails to install Node and blocks all commits
**PR**: #240
**Branch**: `chore/replace-markdownlint-with-rumdl`

## ✅ Completed Work

- Replaced the `markdownlint-cli` pre-commit hook (needs Node; nodeenv crashes
  on Node `27.0.0-alpha`) with `rumdl` v0.2.79: same MD001-MD058 rules, a
  Python wheel, MD013 and MD041 still disabled
- Rebased onto master after #231-#237

## 🎯 Current Project State

- **Tests**: ✅ hooks install and run; commits pass the full hook set again
- **CI/CD**: ✅ all checks green
- `rumdl-check --all-files` reports 1062 existing issues in 37 of 45 Markdown
  files (1051 auto-fixable with `rumdl fmt`). CI only lints changed files, but
  any commit touching README.md or CHANGELOG.md will fail until they are cleaned

### Agent Validation Status

- Not run: no specialist agents were used in this session

## 🚀 Next Session Priorities

1. Merge this PR first: #241, #243 and #245 are based on it
2. Separate cleanup PR: `rumdl fmt` on README.md and CHANGELOG.md, then fix the
   remaining issues by hand

## 📝 Startup Prompt for Next Session

Read CLAUDE.md to understand our workflow, then clean up the Markdown lint debt
(`rumdl fmt` README.md and CHANGELOG.md on a new branch) so documentation PRs
can pass the rumdl hook.

## 📚 Key Reference Documents

- `config/.pre-commit-config.yaml` (Markdown linting section)

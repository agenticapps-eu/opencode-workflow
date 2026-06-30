# Changelog

All notable changes to agenticapps-shared documented here.
This repo follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No unreleased changes.

## [1.0.0] - 2026-06-02

### Added

- Shared migration infrastructure carved from claude-workflow:
  `migrations/lib/{helpers,fixture-runner,preflight,drift-test}.sh` — pass/fail
  helpers + cleanup trap handler (`_runtests_do_cleanup`, `run_check`,
  `assert_check`, `reset_counters`), the generic `extract_to` git-ref primitive,
  parameterized preflight verify-path auditor (`run_preflight_verify_paths`), and
  the policy-agnostic drift-test runner mechanism (`run_drift_test`).
- Standalone `tests/run-tests.sh`: proves `extract_to` real git-ref extraction,
  `run_preflight_verify_paths` in strict + non-strict modes, `run_drift_test`
  GREEN + RED coverage, `assert_check` counter, and `set -u` safety (A2 + A5).
- `migrations/test-fixtures/_example/` skeleton: copy-me fixture triad
  (`setup.sh`, `verify.sh`, `expected-exit`) for consumer repos adopting the
  `test-fixtures/NNNN/MM-name/` convention.
- Consumed by `claude-workflow` via git submodule at `vendor/agenticapps-shared/`.

### Migration provenance (D-28b)

These lib files were **refactored out of** claude-workflow's single
`migrations/run-tests.sh` (one ~2579-line file with SHARED and WORKFLOW functions
intermingled). Source: claude-workflow commit `5aff1b1` (v1.21.0).

Source line ranges (approximate — from the annotated run-tests.sh):

| File | Origin lines in run-tests.sh |
|------|------------------------------|
| `helpers.sh` | 29–42 (colors/counters), 76–85 (`_runtests_do_cleanup`), 139–143 (`run_check`), 151–170 (`assert_check`) |
| `fixture-runner.sh` | 96–104 (`extract_to` — the ONLY export) |
| `preflight.sh` | 1767–1851 (`test_preflight_verify_paths` → parameterized as `run_preflight_verify_paths`) |
| `drift-test.sh` | 2237–2269 (drift runner mechanism + POLICY NOTE) |

**History preservation:** `git filter-repo` operates at whole-file granularity and
cannot carve intermingled functions out of a single file. Therefore `git log --follow`
lineage is **NOT preserved** for these carved lib files. Provenance is recorded
instead by note (this CHANGELOG section + commit messages citing `5aff1b1`).

**A1 boundary (ADR-0035):** only `extract_to` — the truly generic git-ref primitive
— is shared. The `setup_fixture` wrapper (which layers claude-workflow's template
paths and a 1.3.0 ADR special-case on top of `extract_to`) stays in claude-workflow
as a WORKFLOW function and is NOT in this repo.

**Parameterization changes from source:** `run_drift_test` and
`run_preflight_verify_paths` were generalized — paths are passed as arguments (no
`REPO_ROOT` hardcoding); `run_preflight_verify_paths` reads `${STRICT_PREFLIGHT:-0}`
internally so set -u callers do not crash on an unbound variable (A5). `run_drift_test`
returns a code only — it does not increment `PASS`/`FAIL` (D-28d policy separation).

### Release commit (canonical pin artifact — A4)

The canonical pin artifact for claude-workflow's submodule gitlink is the **commit
SHA** tagged as `v1.0.0` — NOT the tag name itself. The tag is provenance only
(human-readable pointer); the superproject's gitlink MUST equal the tagged commit SHA.

Run `git rev-parse v1.0.0^{}` in this repo to resolve the exact commit SHA.
The authoritative SHA is recorded in `28-02-SUMMARY.md` in claude-workflow's
`.planning/phases/28-split-01-agenticapps-shared/` directory.

Verify in the consumer:
`git -C vendor/agenticapps-shared rev-parse HEAD` == `git rev-parse v1.0.0^{}`

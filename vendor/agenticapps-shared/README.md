# agenticapps-shared

Shared infrastructure for the AgenticApps tooling ecosystem.
Consumed by [claude-workflow](https://github.com/agenticapps-eu/claude-workflow)
and [agenticapps-observability](https://github.com/agenticapps-eu/agenticapps-observability).

## What's here

- `migrations/lib/helpers.sh` — pass/fail counters, `run_check`, `assert_check`, `reset_counters`, cleanup trap handler
- `migrations/lib/fixture-runner.sh` — `extract_to`: generic git-ref extraction primitive
- `migrations/lib/preflight.sh` — `run_preflight_verify_paths`: parameterized preflight verify-path auditor (set -u safe)
- `migrations/lib/drift-test.sh` — `run_drift_test`: policy-agnostic SKILL.md vs migration version drift checker
- `migrations/test-fixtures/_example/` — copy-me fixture skeleton (`setup.sh`, `verify.sh`, `expected-exit`)

The SHARED/WORKFLOW boundary that governs what lives here vs. what stays in
claude-workflow is defined in claude-workflow's
[ADR-0035](https://github.com/agenticapps-eu/claude-workflow/blob/main/docs/decisions/0035-shared-extraction-boundaries.md)
and annotated inline in `run-tests.sh` with `# SHARED` / `# WORKFLOW` markers.

## Running the shared test suite

```bash
bash tests/run-tests.sh
```

The suite exercises all four lib files in isolation (no claude-workflow context):
`extract_to` real git-ref extraction, `run_preflight_verify_paths` in strict and
non-strict modes, `run_drift_test` GREEN + RED, `assert_check` counter, and a
`set -u` safety probe. Exit 0 = all green.

## How to consume

Add as a git submodule (the locked sharing mechanism — zero runtime dependency,
version-pin by commit SHA):

```bash
git submodule add https://github.com/agenticapps-eu/agenticapps-shared vendor/agenticapps-shared
git submodule update --init --recursive
```

Pin to a specific commit SHA in your consumer's submodule reference (the gitlink
is the canonical pin artifact — see CHANGELOG [1.0.0] Release commit section).
CI must fetch with `--recurse-submodules`.

## Versioning

Semantic versioning. Breaking changes in the shared CLI surface or removed
helpers bump major. Consumers each carry their own drift test pinned to their
own SKILL.md — this repo ships infrastructure, not an end-user skill.

#!/usr/bin/env bash
# agenticapps-shared :: migrations/lib/drift-test.sh
# Provenance (D-28b): carved from claude-workflow migrations/run-tests.sh @ 5aff1b1 (v1.21.0)
#   lines 2237-2269 (drift runner mechanism + POLICY NOTE comment block 2237-2244)
#
# MECHANISM vs POLICY (ADR-0035):
#   This file ships the MECHANISM only — the generic grep+awk pattern for comparing
#   a SKILL.md version field against the latest migration to_version. The specific
#   POLICY ("SKILL.md version MUST equal latest migration to_version") is a
#   consumer-owned invariant; the consumer calls run_drift_test and decides whether
#   a return code of 1 is a hard failure or just informational.
#
# EXPORTS:
#   run_drift_test(skill_md_path, migrations_dir) -> 0 if version match, 1 if mismatch/missing
#     Does NOT increment PASS or FAIL. Does NOT emit GREEN PASS / RED FAIL policy lines.
#     Policy stays in the consumer (claude-workflow's wrapper, built in plan 28-03).

# Idempotency guard — safe to source multiple times
[ -n "${_AGENTICAPPS_DRIFT_TEST_LOADED:-}" ] && return 0
_AGENTICAPPS_DRIFT_TEST_LOADED=1

# Compare the version field in a SKILL.md against the to_version of the latest migration.
# Usage: run_drift_test <skill_md_path> <migrations_dir>
# Returns: 0 if skill_version == migration_to_version; 1 if mismatch, missing file, or empty.
#
# NOTE (D-04): intentionally minimal grep + awk parser. Fragile against YAML variations
# (quoted values, indented keys, trailing comments). SKILL.md frontmatter is fixed-shape
# (`version: X.Y.Z` on its own line); if that ever changes, this function must be updated.
#
# POLICY NOTE (ADR-0035): the specific coupling rule enforced by consumers — e.g.
# "SKILL.md version == latest migration to_version" — is a consumer-owned policy,
# not a repo-agnostic invariant. This runner emits only a return code; the consumer
# decides what PASS or FAIL means in its context.
run_drift_test() {
  local skill_md="$1" migrations_dir="$2"

  # Validate skill_md exists (Risk 3 — path validation)
  if [ ! -f "$skill_md" ]; then
    echo "run_drift_test: skill_md not found: $skill_md" >&2
    return 1
  fi

  local skill_version
  skill_version=$(grep ^version: "$skill_md" | awk '{print $2}')

  local latest_migration_file
  latest_migration_file=$(ls "${migrations_dir}"/[0-9][0-9][0-9][0-9]-*.md 2>/dev/null | sort | tail -1)

  if [ -z "$latest_migration_file" ]; then
    echo "run_drift_test: no migration files found in ${migrations_dir}" >&2
    return 1
  fi

  local migration_to_version
  migration_to_version=$(grep ^to_version: "$latest_migration_file" | awk '{print $2}')

  if [ "$skill_version" = "$migration_to_version" ]; then
    return 0
  else
    echo "run_drift_test: drift mismatch — skill_version=${skill_version} migration_to_version=${migration_to_version} ($(basename "$latest_migration_file"))" >&2
    return 1
  fi
}

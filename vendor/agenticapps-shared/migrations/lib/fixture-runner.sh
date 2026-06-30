#!/usr/bin/env bash
# agenticapps-shared :: migrations/lib/fixture-runner.sh
# Provenance (D-28b): carved from claude-workflow migrations/run-tests.sh @ 5aff1b1 (v1.21.0)
#   lines 96-104 (extract_to — the ONLY export in this file)
#
# A1 (codex HIGH, user-locked): only extract_to — the truly-generic git-ref primitive — is
# shared. The claude-workflow WORKFLOW wrapper (plan 28-03) calls extract_to and layers its
# own template paths and workflow-specific special-cases on top. See ADR-0035 (amended).
#
# EXPORTS:
#   extract_to(ref, path, out) -> 0 on git-show success, 1 otherwise
#     The generic git-ref extraction utility: repo-agnostic fixture setup primitive.

# Idempotency guard — safe to source multiple times
[ -n "${_AGENTICAPPS_FIXTURE_RUNNER_LOADED:-}" ] && return 0
_AGENTICAPPS_FIXTURE_RUNNER_LOADED=1

# Extract a file from a git ref into a temp path.
# Usage: extract_to <ref> <path-in-repo> <output-path>
extract_to() {
  local ref="$1" path="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  if git show "$ref:$path" >"$out" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

#!/usr/bin/env bash
# check-snapshot-parity.sh — drift guard for the snapshot install path.
#
# Asserts that the shipped snapshot (used by setup for fresh installs)
# equals the end-state produced by replaying every migration from
# 0000-baseline forward. If they diverge, a migration was added/edited
# without regenerating the snapshot — fail so CI catches it.
#
# See docs/decisions/0007-snapshot-install.md.
#
# Usage:
#   bash migrations/check-snapshot-parity.sh            # check, exit 1 on drift
#   bash migrations/check-snapshot-parity.sh --rebuild  # regenerate snapshot/ from replay
#
# NOTE: full migration replay is interactive (placeholder prompts, gate
# detection). This guard runs the NON-INTERACTIVE projection: it compares
# the version-independent, placeholder-form artifacts. The AGENTS.md
# block, planning-config.json, and spec-mirror are compared verbatim;
# workflow-config.md is compared in placeholder form (pre-substitution).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP="$ROOT/skills/setup-opencode-agenticapps-workflow/snapshot"
MODE="check"
[ "${1:-}" = "--rebuild" ] && MODE="rebuild"

fail=0
note() { printf '  %s\n' "$*"; }

# The artifacts whose end-state the snapshot must capture: the dogfooded repo
# IS the end-state. Handled explicitly below (no associative arrays — this guard
# must run under macOS's stock bash 3.2, which lacks `declare -A`).
# NOTE: snapshot/docs-decisions-README.md is a FRESH-PROJECT template (a generic,
# empty ADR index), NOT a mirror of this scaffolder's own docs/decisions/README.md
# (which lists opencode-workflow's real ADRs). So it is deliberately NOT compared
# here — a template diverging from the scaffolder's own ADR list is correct.

# AGENTS.md block: extract between the marker pair from the repo's own
# (fully-migrated) AGENTS.md and compare to snapshot/agents-block.md.
extract_block() {
  awk '/<!-- BEGIN: agentic-apps-workflow sections/{f=1;next} \
       /<!-- END: agentic-apps-workflow sections/{f=0} f' "$ROOT/AGENTS.md"
}

compare() { # $1 expected-content-file  $2 snapshot-file  $3 label
  if [ "$MODE" = "rebuild" ]; then
    cp -f "$1" "$2"; note "rebuilt: $3"; return
  fi
  if ! diff -q "$1" "$2" >/dev/null 2>&1; then
    note "DRIFT: $3 differs between repo end-state and snapshot/"
    fail=1
  else
    note "ok: $3"
  fi
}

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

echo "Snapshot parity check (mode: $MODE)"
echo "  snapshot: $SNAP"

# 1) AGENTS.md workflow block
extract_block > "$tmp"
compare "$tmp" "$SNAP/agents-block.md" "AGENTS.md workflow block"

# 2) .planning/config.json end-state — compared MODULO the repo-specific,
# host-neutral `knowledge_capture` block. That block's `note` path carries the
# resolved repo name (spec §15.2 / ADR-0017), so it is deliberately NOT baked
# into the generic snapshot: setup seeds it (resolving <repo-name>) and migration
# 0005 merges it. Everything else ($schema, implements_spec, host, hooks) MUST
# match. Compared jq-normalized (jq -S) so a merge's reformatting/key-order does
# not read as drift.
CFG_SRC="$ROOT/.planning/config.json"
CFG_SNAP="$SNAP/planning-config.json"
if [ "$MODE" = "rebuild" ]; then
  jq 'del(.knowledge_capture)' "$CFG_SRC" > "$CFG_SNAP.tmp" && mv "$CFG_SNAP.tmp" "$CFG_SNAP"
  note "rebuilt: .planning/config.json (sans knowledge_capture)"
else
  csrc="$(mktemp)"; csnap="$(mktemp)"
  jq -S 'del(.knowledge_capture)' "$CFG_SRC"  > "$csrc"  2>/dev/null
  jq -S 'del(.knowledge_capture)' "$CFG_SNAP" > "$csnap" 2>/dev/null
  if diff -q "$csrc" "$csnap" >/dev/null 2>&1; then
    note "ok: .planning/config.json (modulo knowledge_capture)"
  else
    note "DRIFT: .planning/config.json differs (excluding knowledge_capture)"
    fail=1
  fi
  rm -f "$csrc" "$csnap"
fi

# 3) §11 spec mirror (must match the vendored discipline mirror)
MIRROR="$ROOT/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
[ -f "$MIRROR" ] && compare "$MIRROR" "$SNAP/spec-mirrors/11-coding-discipline-0.4.0.md" "spec-mirror §11"

# 4) sanity: snapshot proves it is the LATEST shape, not the v0.1.0 baseline
if ! grep -q "Coding Discipline" "$SNAP/agents-block.md"; then
  note "DRIFT: snapshot agents-block.md is missing §11 — looks like the baseline, not latest"
  fail=1
fi

echo
if [ "$MODE" = "rebuild" ]; then
  echo "snapshot rebuilt from repo end-state."
  exit 0
fi
if [ "$fail" -ne 0 ]; then
  echo "FAIL — snapshot has drifted. Run: bash migrations/check-snapshot-parity.sh --rebuild"
  exit 1
fi
echo "PASS — snapshot equals the migration end-state."

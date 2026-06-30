#!/usr/bin/env bash
# agenticapps-shared :: migrations/lib/preflight.sh
# Provenance (D-28b): carved from claude-workflow migrations/run-tests.sh @ 5aff1b1 (v1.21.0)
#   lines 1767-1851 (test_preflight_verify_paths — parameterized as run_preflight_verify_paths)
#
# USAGE: source helpers.sh first (provides RED/GREEN/YELLOW/RESET, FAIL, RAN_AUDIT).
#   Then source this file and call run_preflight_verify_paths(migrations_dir).
#
# EXPORTS:
#   run_preflight_verify_paths(migrations_dir)
#     Walks every migration in migrations_dir and executes each requires[*].verify
#     shell command against the host environment. Informational only — failures DO NOT
#     add to the suite global PASS/FAIL counters (unless STRICT_PREFLIGHT=1).
#     Sets RAN_AUDIT=1. Reads ${STRICT_PREFLIGHT:-0} internally (A5: set -u safe).

# Idempotency guard — safe to source multiple times
[ -n "${_AGENTICAPPS_PREFLIGHT_LOADED:-}" ] && return 0
_AGENTICAPPS_PREFLIGHT_LOADED=1

# Walks every migration in migrations_dir and executes each `requires[*].verify`
# shell command against the host environment.
# Usage: run_preflight_verify_paths <migrations_dir>
#
# Catches the issue-#18 bug class: a verify path that points at a location which
# doesn't exist on any system. Run pre-PR to surface verify rot before it ships.
#
# In default (non-strict) mode failures are purely informational: they print to a
# labeled section but do NOT change the exit code.
# In strict mode (STRICT_PREFLIGHT=1) audit failures DO add to the global FAIL counter.
run_preflight_verify_paths() {
  local migrations_dir="$1"
  # A5 (set -u safety): read STRICT_PREFLIGHT with a default so a set -u caller
  # that never exported the flag does not crash on an unbound-variable read.
  local strict="${STRICT_PREFLIGHT:-0}"

  local audit_pass=0 audit_fail=0 audit_skip=0
  RAN_AUDIT=1

  local mode_label="informational"
  [ "$strict" = "1" ] && mode_label="strict — failures gate exit"

  echo ""
  echo "${YELLOW}━━━ Preflight-correctness audit ($mode_label) ━━━${RESET}"
  echo "  Exercises each migration's requires.verify against THIS machine."
  echo "  Failures may mean either a broken verify path (real bug) OR a"
  echo "  missing local dependency (expected on fresh machines)."
  echo ""

  # Sanity-check that python3 + pyyaml are available; skip the whole audit
  # cleanly if not (degrades gracefully on minimal CI images). In strict
  # mode this is a real failure — CI should install PyYAML or accept
  # missing audit coverage as a regression.
  if ! python3 -c 'import yaml' 2>/dev/null; then
    if [ "$strict" = "1" ]; then
      echo "  ${RED}✗${RESET} python3 with PyYAML not available — audit cannot run (strict)"
      FAIL=$((FAIL+1))
    else
      echo "  ${YELLOW}~${RESET} python3 with PyYAML not available — preflight audit skipped"
    fi
    return 0
  fi

  for migration in "${migrations_dir}"/[0-9]*.md; do
    local id
    id="$(basename "$migration" | sed 's/-.*//')"
    local verifies
    verifies=$(python3 - "$migration" <<'PY'
import sys, re, yaml
text = open(sys.argv[1]).read()
m = re.search(r'^---\n(.*?)\n---', text, re.DOTALL | re.MULTILINE)
if not m:
    sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1))
except Exception:
    sys.exit(0)
requires = fm.get('requires') if isinstance(fm, dict) else None
if not isinstance(requires, list):
    sys.exit(0)
for entry in requires:
    if isinstance(entry, dict) and 'verify' in entry:
        v = entry['verify']
        if isinstance(v, str) and v.strip():
            print(v)
PY
    )

    if [ -z "$verifies" ]; then
      audit_skip=$((audit_skip+1))
      continue
    fi

    while IFS= read -r v; do
      [ -z "$v" ] && continue
      if eval "$v" >/dev/null 2>&1; then
        printf "  ${GREEN}✓${RESET} %s: %s\n" "$id" "$v"
        audit_pass=$((audit_pass+1))
      else
        local rc=$?
        printf "  ${RED}✗${RESET} %s: %s (exit %d)\n" "$id" "$v" "$rc"
        audit_fail=$((audit_fail+1))
      fi
    done <<< "$verifies"
  done

  echo ""
  printf "  Audit summary: ${GREEN}PASS=%d${RESET} ${RED}FAIL=%d${RESET} ${YELLOW}SKIP=%d${RESET}\n" \
    "$audit_pass" "$audit_fail" "$audit_skip"
  if [ "$strict" = "1" ]; then
    if [ "$audit_fail" -gt 0 ]; then
      FAIL=$((FAIL + audit_fail))
      echo "  (counted in suite totals — strict mode: $audit_fail FAIL rolled into global FAIL.)"
    else
      echo "  (counted in suite totals — strict mode: 0 audit FAIL to roll in.)"
    fi
  else
    echo "  (NOT counted in suite totals — pass --strict-preflight to gate.)"
  fi
}

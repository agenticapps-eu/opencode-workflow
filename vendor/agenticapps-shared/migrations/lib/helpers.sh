#!/usr/bin/env bash
# agenticapps-shared :: migrations/lib/helpers.sh
# Provenance (D-28b): carved from claude-workflow migrations/run-tests.sh @ 5aff1b1 (v1.21.0)
#   lines 29-42 (colors/counters), 76-85 (_runtests_do_cleanup), 139-143 (run_check), 151-170 (assert_check)
#
# USAGE: source this file BEFORE sourcing any other lib file. It initializes
#   color vars, counters, and the cleanup trap handler body.
#   Trap installation (INT/TERM/EXIT) is the CONSUMER's responsibility (done
#   AFTER all sourcing is complete, to avoid partial-source trap races — Risk 2).
#
# EXPORTS:
#   RED GREEN YELLOW RESET          (tty-conditional color strings)
#   PASS FAIL SKIP RAN_AUDIT        (counters, initialized to 0 at source time)
#   _runtests_cleanup_fired         (idempotency flag, init 0)
#   _runtests_do_cleanup()          (trap handler body; idempotent; does NOT set traps)
#   run_check(fixture, check)       -> exit code of check
#   assert_check(label, check, fixture, expected:applied|not-applied) -> increments PASS/FAIL
#   reset_counters()                -> sets PASS=FAIL=SKIP=RAN_AUDIT=0 for isolated reruns

# Idempotency guard — safe to source multiple times (Risk 7)
[ -n "${_AGENTICAPPS_HELPERS_LOADED:-}" ] && return 0
_AGENTICAPPS_HELPERS_LOADED=1

# Colors for output (skip if not a tty — Pitfall 1: keep the [ -t 1 ] check)
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

# Counter initialization (runs once at source time — Risk 4)
PASS=0; FAIL=0; SKIP=0; RAN_AUDIT=0

# ─── SPLIT TRAP handler body ───────────────────────────────────────────────────
# Mirrors the split-trap shape in run-tests.sh. EXIT is silent (no cleanup output
# on normal harness exit). INT → exit 130; TERM → exit 143.
# CONSUMER installs the traps AFTER sourcing all lib files to avoid partial-source
# trap races. This function is ONLY the handler body.
_runtests_cleanup_fired=0
_runtests_do_cleanup() {
  [ "$_runtests_cleanup_fired" -eq 1 ] && return 0
  _runtests_cleanup_fired=1
  # harness-level cleanup (intentionally empty — no shared state to tear down)
  :
}

# Run an idempotency check shell snippet inside a fixture dir.
# Returns the exit code of the check.
run_check() {
  local fixture="$1" check="$2"
  ( cd "$fixture" && eval "$check" >/dev/null 2>&1 )
  return $?
}

# Assert helper.
# Usage: assert_check "<label>" "<check>" "<fixture>" "<expected: applied|not-applied>"
# Semantic: "applied" means the idempotency check returned 0 (skip — already done).
#          "not-applied" means it returned ANY non-zero (please apply).
# Numeric exit codes beyond 0 vs non-0 don't matter to the migration runtime.
assert_check() {
  local label="$1" check="$2" fixture="$3" expected="$4"
  run_check "$fixture" "$check"
  local actual=$?
  local pass=0
  case "$expected" in
    applied)     [ "$actual" = "0" ] && pass=1 ;;
    not-applied) [ "$actual" != "0" ] && pass=1 ;;
    *) echo "  ${RED}!${RESET} bad expected value: $expected"; FAIL=$((FAIL+1)); return ;;
  esac
  if [ "$pass" = "1" ]; then
    echo "  ${GREEN}✓${RESET} $label (expected $expected, exit=$actual)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} $label (expected $expected, got exit=$actual)"
    echo "      check: $check"
    echo "      fixture: $fixture"
    FAIL=$((FAIL+1))
  fi
}

# Reset all counters to 0 — for isolated reruns in standalone test suites.
reset_counters() { PASS=0; FAIL=0; SKIP=0; RAN_AUDIT=0; }

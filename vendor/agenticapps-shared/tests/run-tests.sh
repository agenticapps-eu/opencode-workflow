#!/usr/bin/env bash
# agenticapps-shared :: tests/run-tests.sh
# Provenance (D-28b): standalone test suite for the shared migration lib.
#   Exercises the carved lib (helpers.sh, fixture-runner.sh, preflight.sh, drift-test.sh)
#   in isolation — no claude-workflow context, no per-migration harness calls (A1/Pitfall 4).
#
# Coverage (A2 + A5):
#   1. assert_check via _example fixture (counter increment proof)
#   2. assert_check PASS counter increment verification
#   3. run_drift_test GREEN case (matching versions)
#   4. run_drift_test RED case (mismatched versions)
#   5. extract_to REAL git-ref extraction in a throwaway temp repo (A2)
#   6. run_preflight_verify_paths NON-STRICT mode (informational, does not gate FAIL)
#   7. run_preflight_verify_paths STRICT mode (audit failures roll into global FAIL)
#   8. set -u safety probe: STRICT_PREFLIGHT never set → no unbound-variable crash (A5)
#
# A1 boundary: only extract_to is shared; the workflow fixture wrapper stays in claude-workflow.
# This suite tests the lib functions themselves — NOT migration content (Pitfall 4).

set -uo pipefail

# ─── Source the shared lib via BASH_SOURCE dirname pattern (28-RESEARCH CRQ 4) ──
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SHARED_LIB="$_SCRIPT_DIR/../migrations/lib"

# shellcheck source=../migrations/lib/helpers.sh
source "${_SHARED_LIB}/helpers.sh"
# shellcheck source=../migrations/lib/fixture-runner.sh
source "${_SHARED_LIB}/fixture-runner.sh"
# shellcheck source=../migrations/lib/preflight.sh
source "${_SHARED_LIB}/preflight.sh"
# shellcheck source=../migrations/lib/drift-test.sh
source "${_SHARED_LIB}/drift-test.sh"

# ─── Temp dir tracking for cleanup ───────────────────────────────────────────
_RUNTESTS_TMPDIRS=()

_runtests_make_tmp() {
  local d
  d="$(mktemp -d)"
  _RUNTESTS_TMPDIRS+=("$d")
  echo "$d"
}

_runtests_cleanup_all() {
  _runtests_do_cleanup
  for d in "${_RUNTESTS_TMPDIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}

# ─── Install traps AFTER sourcing (consumer responsibility — Risk 2) ─────────
trap '_runtests_cleanup_all' EXIT
trap '_runtests_cleanup_all; exit 130' INT
trap '_runtests_cleanup_all; exit 143' TERM

echo ""
echo "${YELLOW}━━━ agenticapps-shared standalone test suite ━━━${RESET}"
echo "  Exercises shared lib in isolation (no claude-workflow context)."
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: assert_check via _example fixture
# ═══════════════════════════════════════════════════════════════════════════════
echo "── Test 1: assert_check via _example fixture ──"

_EXAMPLE_DIR="${_SCRIPT_DIR}/../migrations/test-fixtures/_example"
_T1_FIXTURE="$(_runtests_make_tmp)"

# Run the _example setup.sh into the temp fixture dir
bash "${_EXAMPLE_DIR}/setup.sh" "${_T1_FIXTURE}"

# Assert the marker exists (check = "applied" state)
assert_check "_example fixture: marker file exists after setup" \
  "[ -f marker ]" \
  "${_T1_FIXTURE}" \
  "applied"

# Also assert expected-exit content is 0 (file-level contract)
_EXPECTED_EXIT="$(cat "${_EXAMPLE_DIR}/expected-exit" | tr -d '[:space:]')"
if [ "${_EXPECTED_EXIT}" = "0" ]; then
  echo "  ${GREEN}✓${RESET} _example/expected-exit contains 0"
  PASS=$((PASS+1))
else
  echo "  ${RED}✗${RESET} _example/expected-exit should contain 0, got: ${_EXPECTED_EXIT}"
  FAIL=$((FAIL+1))
fi

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: assert_check PASS counter increment
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 2: assert_check PASS counter increment ──"

_T2_FIXTURE="$(_runtests_make_tmp)"
mkdir -p "${_T2_FIXTURE}"
echo "probe" > "${_T2_FIXTURE}/probe.txt"

_PASS_BEFORE=${PASS}
assert_check "counter-increment probe" \
  "[ -f probe.txt ]" \
  "${_T2_FIXTURE}" \
  "applied"
_PASS_AFTER=${PASS}

if [ "$((_PASS_AFTER - _PASS_BEFORE))" -eq 1 ]; then
  echo "  ${GREEN}✓${RESET} PASS counter incremented by 1 (was ${_PASS_BEFORE}, now ${_PASS_AFTER})"
  PASS=$((PASS+1))
else
  echo "  ${RED}✗${RESET} PASS counter did not increment correctly (was ${_PASS_BEFORE}, now ${_PASS_AFTER})"
  FAIL=$((FAIL+1))
fi

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: run_drift_test GREEN case
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 3: run_drift_test GREEN case (matching versions) ──"

_T3_SKILL="$(_runtests_make_tmp)/SKILL.md"
_T3_MIGS="$(_runtests_make_tmp)"

cat > "${_T3_SKILL}" <<'EOF'
---
version: 9.9.9
---
# Test skill
EOF

cat > "${_T3_MIGS}/0001-x.md" <<'EOF'
---
to_version: 9.9.9
---
# Synthetic migration for drift GREEN test
EOF

if run_drift_test "${_T3_SKILL}" "${_T3_MIGS}"; then
  echo "  ${GREEN}✓${RESET} run_drift_test GREEN: matching versions returned 0"
  PASS=$((PASS+1))
else
  echo "  ${RED}✗${RESET} run_drift_test GREEN: expected 0, got non-zero"
  FAIL=$((FAIL+1))
fi

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: run_drift_test RED case
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 4: run_drift_test RED case (mismatched versions) ──"

_T4_SKILL="$(_runtests_make_tmp)/SKILL.md"
_T4_MIGS="$(_runtests_make_tmp)"

cat > "${_T4_SKILL}" <<'EOF'
---
version: 9.9.8
---
# Test skill with old version
EOF

cat > "${_T4_MIGS}/0001-x.md" <<'EOF'
---
to_version: 9.9.9
---
# Synthetic migration for drift RED test
EOF

if ! run_drift_test "${_T4_SKILL}" "${_T4_MIGS}" 2>/dev/null; then
  echo "  ${GREEN}✓${RESET} run_drift_test RED: mismatched versions returned non-zero"
  PASS=$((PASS+1))
else
  echo "  ${RED}✗${RESET} run_drift_test RED: expected non-zero, got 0"
  FAIL=$((FAIL+1))
fi

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5 (A2): extract_to REAL git-ref extraction in a throwaway temp repo
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 5 (A2): extract_to real git-ref extraction (throwaway repo) ──"

_T5_REPO="$(_runtests_make_tmp)"
_T5_OUT="$(_runtests_make_tmp)"

# Initialize a throwaway git repo with local user config (no global config pollution)
git -C "${_T5_REPO}" init -q
git -C "${_T5_REPO}" config user.name "agenticapps-shared-test"
git -C "${_T5_REPO}" config user.email "test@agenticapps-shared.local"

# Write a file with known content and commit it
_T5_CONTENT="hello from extract_to test"
echo "${_T5_CONTENT}" > "${_T5_REPO}/hello.txt"
git -C "${_T5_REPO}" add hello.txt
git -C "${_T5_REPO}" commit -q -m "test: synthetic commit for extract_to test"

# Capture the commit ref (HEAD SHA)
_T5_REF="$(git -C "${_T5_REPO}" rev-parse HEAD)"

# Run extract_to from inside the repo (git show needs to run in the repo context)
_T5_EXTRACTED="${_T5_OUT}/hello-extracted.txt"
_ORIG_CWD="$(pwd)"
cd "${_T5_REPO}"
if extract_to "${_T5_REF}" hello.txt "${_T5_EXTRACTED}"; then
  _EXTRACTED_CONTENT="$(cat "${_T5_EXTRACTED}")"
  if [ "${_EXTRACTED_CONTENT}" = "${_T5_CONTENT}" ]; then
    echo "  ${GREEN}✓${RESET} extract_to: real git-ref extraction succeeded, content matches"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} extract_to: content mismatch (expected '${_T5_CONTENT}', got '${_EXTRACTED_CONTENT}')"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ${RED}✗${RESET} extract_to: returned non-zero for existing ref"
  FAIL=$((FAIL+1))
fi

# Also assert extract_to returns non-zero for a nonexistent path
_T5_OUT2="${_T5_OUT}/nonexistent-extracted.txt"
if ! extract_to "${_T5_REF}" does-not-exist.txt "${_T5_OUT2}" 2>/dev/null; then
  echo "  ${GREEN}✓${RESET} extract_to: nonexistent path correctly returned non-zero"
  PASS=$((PASS+1))
else
  echo "  ${RED}✗${RESET} extract_to: should return non-zero for nonexistent path, got 0"
  FAIL=$((FAIL+1))
fi

cd "${_ORIG_CWD}"

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6 (A2): run_preflight_verify_paths NON-STRICT mode
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 6 (A2): run_preflight_verify_paths NON-STRICT mode ──"

_T6_MIGS="$(_runtests_make_tmp)"

# Write a synthetic migration with a verify that FAILS (guaranteed nonexistent path)
cat > "${_T6_MIGS}/0001-synthetic.md" <<'EOF'
---
to_version: 1.0.0
requires:
  - verify: test -f /nonexistent/path/agenticapps-shared-preflight-probe-xyz
---
# Synthetic migration for preflight NON-STRICT test
EOF

# Save counters before the probe
_T6_FAIL_BEFORE=${FAIL}

# Check python3+pyyaml availability for branching
if python3 -c 'import yaml' 2>/dev/null; then
  _T6_HAS_YAML=1
else
  _T6_HAS_YAML=0
fi

# Unset STRICT_PREFLIGHT for non-strict mode
unset STRICT_PREFLIGHT 2>/dev/null || true
# Save and restore RAN_AUDIT for clean check
_T6_RAN_AUDIT_BEFORE=${RAN_AUDIT}
RAN_AUDIT=0

run_preflight_verify_paths "${_T6_MIGS}"

_T6_FAIL_AFTER=${FAIL}
_T6_RAN_AUDIT_AFTER=${RAN_AUDIT}

if [ "${_T6_HAS_YAML}" -eq 1 ]; then
  # Non-strict: FAIL should NOT grow even though verify fails
  if [ "${_T6_FAIL_AFTER}" -eq "${_T6_FAIL_BEFORE}" ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths non-strict: FAIL counter did not grow (informational only)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths non-strict: FAIL grew by $((${_T6_FAIL_AFTER} - ${_T6_FAIL_BEFORE})) — expected 0 growth"
    FAIL=$((FAIL+1))
  fi
  # RAN_AUDIT should be 1 after the call
  if [ "${_T6_RAN_AUDIT_AFTER}" -eq 1 ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths non-strict: RAN_AUDIT=1 after call"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths non-strict: expected RAN_AUDIT=1, got ${_T6_RAN_AUDIT_AFTER}"
    FAIL=$((FAIL+1))
  fi
else
  # pyyaml absent: non-strict skip path — function returns 0, RAN_AUDIT=1, FAIL unchanged
  echo "  ${YELLOW}~${RESET} python3+PyYAML absent — testing non-strict skip path"
  SKIP=$((SKIP+1))
  if [ "${_T6_FAIL_AFTER}" -eq "${_T6_FAIL_BEFORE}" ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths non-strict skip: FAIL did not grow"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths non-strict skip: FAIL grew unexpectedly"
    FAIL=$((FAIL+1))
  fi
  if [ "${_T6_RAN_AUDIT_AFTER}" -eq 1 ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths non-strict skip: RAN_AUDIT=1"
    PASS=$((PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths non-strict skip: RAN_AUDIT not 1"
    FAIL=$((FAIL+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7 (A2): run_preflight_verify_paths STRICT mode
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 7 (A2): run_preflight_verify_paths STRICT mode ──"

_T7_MIGS="$(_runtests_make_tmp)"

# Same synthetic migration with a failing verify
cat > "${_T7_MIGS}/0001-synthetic.md" <<'EOF'
---
to_version: 1.0.0
requires:
  - verify: test -f /nonexistent/path/agenticapps-shared-preflight-strict-probe-xyz
---
# Synthetic migration for preflight STRICT test
EOF

# Save counters, set strict mode, run the probe, then restore.
# Strategy: save FAIL before the preflight probe runs. After the call,
# check if FAIL grew (that proves strict mode worked). Then restore FAIL
# to _T7_FAIL_PRE + any assertion failures from THIS test (not the audit FAIL).
_T7_SAVED_PASS=${PASS}
_T7_SAVED_SKIP=${SKIP}
_T7_SAVED_FAIL=${FAIL}

# Set strict mode
STRICT_PREFLIGHT=1
export STRICT_PREFLIGHT

_T7_FAIL_PRE=${FAIL}

run_preflight_verify_paths "${_T7_MIGS}"

_T7_FAIL_POST=${FAIL}
# Note how much FAIL grew due to the strict audit
_T7_AUDIT_FAIL_DELTA=$((_T7_FAIL_POST - _T7_FAIL_PRE))

_T7_ASSERTION_FAIL=0
_T7_ASSERTION_PASS=0

if python3 -c 'import yaml' 2>/dev/null; then
  # Strict: FAIL SHOULD grow (the failing verify should roll into global FAIL)
  if [ "${_T7_AUDIT_FAIL_DELTA}" -gt 0 ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths strict: FAIL grew by ${_T7_AUDIT_FAIL_DELTA} (audit failures rolled into FAIL)"
    _T7_ASSERTION_PASS=$((_T7_ASSERTION_PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths strict: expected FAIL to grow, but delta=${_T7_AUDIT_FAIL_DELTA}"
    _T7_ASSERTION_FAIL=$((_T7_ASSERTION_FAIL+1))
  fi
else
  # pyyaml absent in strict: function emits a FAIL for missing PyYAML and returns 0
  echo "  ${YELLOW}~${RESET} python3+PyYAML absent — testing strict PyYAML-missing path"
  SKIP=$((SKIP+1))
  if [ "${_T7_AUDIT_FAIL_DELTA}" -gt 0 ]; then
    echo "  ${GREEN}✓${RESET} run_preflight_verify_paths strict+no-yaml: FAIL incremented for missing PyYAML (expected)"
    _T7_ASSERTION_PASS=$((_T7_ASSERTION_PASS+1))
  else
    echo "  ${RED}✗${RESET} run_preflight_verify_paths strict+no-yaml: FAIL should have incremented for missing PyYAML"
    _T7_ASSERTION_FAIL=$((_T7_ASSERTION_FAIL+1))
  fi
fi

# Restore counters: the audit FAIL delta was a deliberate probe (not a real suite failure).
# Only real assertion failures (_T7_ASSERTION_FAIL) flow into the suite total.
PASS=$((_T7_SAVED_PASS + _T7_ASSERTION_PASS))
FAIL=$((_T7_SAVED_FAIL + _T7_ASSERTION_FAIL))
SKIP=$((_T7_SAVED_SKIP))

# Unset strict mode after test 7
unset STRICT_PREFLIGHT

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8 (A5): set -u safety probe — STRICT_PREFLIGHT never set → no crash
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "── Test 8 (A5): set -u safety probe (STRICT_PREFLIGHT never set) ──"

_T8_MIGS="$(_runtests_make_tmp)"
# Use an empty migrations dir (no .md files) so the audit loops quickly
# Write a migration that has no requires (so pyyaml path is irrelevant)
cat > "${_T8_MIGS}/0001-no-requires.md" <<'EOF'
---
to_version: 1.0.0
---
# Migration with no requires (preflight should skip, not crash)
EOF

# Run in a subshell with set -u and STRICT_PREFLIGHT explicitly unset
_T8_STDERR_FILE="$(_runtests_make_tmp)/stderr.txt"
_T8_LIB="${_SHARED_LIB}"
_T8_MIGS_PATH="${_T8_MIGS}"
_T8_EXIT=0

(
  set -u
  unset STRICT_PREFLIGHT
  # shellcheck source=../migrations/lib/helpers.sh
  source "${_T8_LIB}/helpers.sh"
  # shellcheck source=../migrations/lib/preflight.sh
  source "${_T8_LIB}/preflight.sh"
  run_preflight_verify_paths "${_T8_MIGS_PATH}" >/dev/null 2>&1
) 2>"${_T8_STDERR_FILE}" || _T8_EXIT=$?

_T8_STDERR="$(cat "${_T8_STDERR_FILE}")"

# We consider the probe passed if stderr does NOT contain "unbound variable" for STRICT_PREFLIGHT
if echo "${_T8_STDERR}" | grep -q "STRICT_PREFLIGHT: unbound variable"; then
  echo "  ${RED}✗${RESET} set -u safety probe FAILED: unbound variable error for STRICT_PREFLIGHT detected"
  echo "      stderr: ${_T8_STDERR}"
  FAIL=$((FAIL+1))
elif echo "${_T8_STDERR}" | grep -q "unbound variable"; then
  echo "  ${RED}✗${RESET} set -u safety probe FAILED: some unbound variable error detected"
  echo "      stderr: ${_T8_STDERR}"
  FAIL=$((FAIL+1))
else
  echo "  ${GREEN}✓${RESET} set -u safety probe PASSED: no unbound variable crash (STRICT_PREFLIGHT safely defaulted)"
  PASS=$((PASS+1))
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "${YELLOW}━━━ agenticapps-shared test suite complete ━━━${RESET}"
printf "  ${GREEN}PASS: %d${RESET}  ${RED}FAIL: %d${RESET}  ${YELLOW}SKIP: %d${RESET}\n" "${PASS}" "${FAIL}" "${SKIP}"
echo ""

if [ "${FAIL}" -gt 0 ]; then
  echo "${RED}SUITE FAILED${RESET} — ${FAIL} failure(s)"
  exit 1
else
  echo "${GREEN}SUITE GREEN${RESET} — all tests passed"
  exit 0
fi

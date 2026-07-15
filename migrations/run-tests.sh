#!/usr/bin/env bash
# Migration test harness — verifies idempotency checks behave correctly
# against known before / after reference states extracted from git.
#
# Usage:
#   migrations/run-tests.sh                # run all testable migrations
#   migrations/run-tests.sh 0001           # run only migration 0001
#   migrations/run-tests.sh -- 0000        # run only migration 0000 (which
#                                          # currently produces a SKIP)
#
# At v0.1.0 the only migration is 0000-baseline, which requires
# interactive input (user-question responses for placeholder
# substitution) and therefore cannot be tested non-interactively.
# The harness reports SKIP for 0000 and exits 0 if no other migrations
# are testable. Once incremental migrations land (v0.2.0+), each ships
# with fixtures and the dispatcher gains a `test_migration_NNNN`
# function.
#
# See migrations/test-fixtures/README.md for the fixture contract.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  echo "error: run-tests.sh must be invoked from inside a git repo" >&2
  exit 1
fi
cd "$REPO_ROOT"

# Shared harness primitives — agenticapps-shared submodule (SPLIT-01, per
# claude-workflow ADR-0035). Provides colors (RED/GREEN/YELLOW/RESET), counters
# (PASS/FAIL/SKIP), run_check, assert_check, extract_to, run_drift_test. The
# drift POLICY (version coupling is a hard fail) stays in this consumer.
SHARED_LIB="$REPO_ROOT/vendor/agenticapps-shared/migrations/lib"
if [ ! -f "$SHARED_LIB/helpers.sh" ]; then
  echo "error: agenticapps-shared submodule not initialized." >&2
  echo "       Run: git submodule update --init --recursive   (or: bash install.sh)" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$SHARED_LIB/helpers.sh"
. "$SHARED_LIB/fixture-runner.sh"
. "$SHARED_LIB/drift-test.sh"

# Filter (optional first non-`--` arg)
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --) continue ;;
    *) FILTER="$arg"; break ;;
  esac
done

# Helpers (extract_to, run_check, assert_check) are now provided by the shared
# lib sourced above (agenticapps-shared migrations/lib/helpers.sh +
# fixture-runner.sh) — no local duplication.

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0000 — Baseline
# Interactive only — placeholder substitution requires user input.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0000() {
  echo ""
  echo "${YELLOW}=== Migration 0000 — Baseline ===${RESET}"
  echo "  ${YELLOW}SKIP${RESET}: 0000-baseline.md is interactive-only"
  echo "  Validation path: run \$setup-opencode-agenticapps-workflow against a"
  echo "  real fresh project and confirm the post-checks listed in"
  echo "  migrations/0000-baseline.md."
  SKIP=$((SKIP+1))
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0001 — Inject spec §11 Coding Discipline
# Testable non-interactively: idempotency check, conflict pre-flight, and
# byte-identity of the injection are validated against synthetic fixtures.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0001() {
  echo ""
  echo "${YELLOW}=== Migration 0001 — Inject spec §11 Coding Discipline ===${RESET}"

  local mirror="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
  if [ ! -f "$mirror" ]; then
    echo "  ${RED}FAIL${RESET} mirror missing: skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
    FAIL=$((FAIL+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local PROV='<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->'

  # Fixture A: AGENTS.md with a heading but no §11 → not yet applied.
  printf '# Title\n\n## Some Section\n\nbody\n' > "$tmp/a-AGENTS.md"
  ( cd "$tmp" && grep -qE "$PROV" a-AGENTS.md )
  assert_check "idempotency: fresh AGENTS.md needs apply" \
    "grep -qE '$PROV' a-AGENTS.md" "$tmp" "not-applied"

  # Fixture B: AGENTS.md already carrying the provenance anchor → applied (skip).
  printf '# Title\n\n<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n## Coding Discipline (NON-NEGOTIABLE)\n\n## Some Section\n' > "$tmp/b-AGENTS.md"
  assert_check "idempotency: provenance present → skip" \
    "grep -qE '$PROV' b-AGENTS.md" "$tmp" "applied"

  # Fixture C: unmanaged §11 heading (no provenance) → conflict must be detected.
  printf '# Title\n\n## Coding Discipline (NON-NEGOTIABLE)\n\nhand-written\n' > "$tmp/c-AGENTS.md"
  if ( cd "$tmp" && grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' c-AGENTS.md \
        && ! grep -qE "$PROV" c-AGENTS.md ); then
    echo "  ${GREEN}PASS${RESET} conflict pre-flight detects unmanaged §11 prose"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} conflict pre-flight did NOT detect unmanaged §11 prose"
    FAIL=$((FAIL+1))
  fi

  # Injection byte-identity: applying Step 1's awk to fixture A must produce a
  # §11 block byte-identical to the mirror.
  awk -v mirror="$mirror" '
    /^## / && !done {
      print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
      while ((getline line < mirror) > 0) print line
      close(mirror); print ""; done=1
    }
    { print }
  ' "$tmp/a-AGENTS.md" > "$tmp/a-injected.md"
  awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' \
    "$tmp/a-injected.md" > "$tmp/a-block.md"
  if diff -q "$tmp/a-block.md" "$mirror" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} injected §11 block is byte-identical to the mirror"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} injected §11 block differs from the mirror"
    FAIL=$((FAIL+1))
  fi

  # Mirror byte-identity vs core spec (only when the core spec repo is present).
  # Extract the canonical block FENCE-RELATIVE (content between the two four-backtick
  # fences) rather than by hardcoded line numbers — robust to spec edits that shift
  # line numbers (e.g. core 10f2c96 added blank lines around the anti-pattern lists).
  local core="$REPO_ROOT/../agenticapps-workflow-core/spec/11-coding-discipline.md"
  if [ -f "$core" ]; then
    if diff -q <(awk '/^````$/{f++; next} f==1{print}' "$core") "$mirror" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} mirror == core spec §11 canonical block (verbatim, fence-relative)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} mirror has drifted from core spec §11"
      FAIL=$((FAIL+1))
    fi
  else
    echo "  ${YELLOW}SKIP${RESET} core spec repo not adjacent — mirror/core diff not checked"
    SKIP=$((SKIP+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0002 — Add opencode-ts-declare-first skill (spec §13)
# Testable non-interactively: idempotency check + jq apply/rollback on a
# synthetic .planning/config.json fixture.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0002() {
  echo ""
  echo "${YELLOW}=== Migration 0002 — Add opencode-ts-declare-first skill ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-edit test not run"
    SKIP=$((SKIP+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Synthetic config without the §13 binding.
  cat > "$tmp/config.json" <<'JSON'
{ "hooks": { "per_task": { "tdd": { "skill": "superpowers:test-driven-development", "fires_when": "tdd=true", "commit_pair": ["test(RED):","feat(GREEN):"] } } } }
JSON

  assert_check "idempotency: fresh config needs the §13 binding" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"opencode-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply Step 1's jq.
  ( cd "$tmp" && jq '.hooks.per_task.tdd.strengthened_by = {
      "skill": "opencode-ts-declare-first",
      "implements_spec": "0.4.0",
      "fires_when": "task introduces a new TypeScript module public API surface in a TS-primary project",
      "commit_sequence": ["declare(ts):", "test(ts):", "feat(ts):"]
    }' config.json > config.tmp && mv config.tmp config.json )

  assert_check "after apply: §13 binding present" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"opencode-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "applied"

  # Base tdd binding must be intact (not clobbered).
  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} base tdd binding intact after strengthening"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} base tdd binding lost"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes the binding.
  ( cd "$tmp" && jq 'del(.hooks.per_task.tdd.strengthened_by)' config.json > config.tmp && mv config.tmp config.json )
  assert_check "after rollback: binding removed" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"opencode-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # The shipped skill has three SEPARATE template files (structural three-commit shape).
  local sk="$REPO_ROOT/skills/opencode-ts-declare-first"
  if [ -f "$sk/templates/example.declare.ts" ] && [ -f "$sk/templates/example.test.ts" ] && [ -f "$sk/templates/example.impl.ts" ]; then
    echo "  ${GREEN}PASS${RESET} three separate phase templates ship with the skill"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} ts-declare-first templates missing or incomplete"
    FAIL=$((FAIL+1))
  fi

  # The declare template must be declare-only (no implementation bodies).
  if grep -qE '(^|[^.])\bexport declare\b' "$sk/templates/example.declare.ts" 2>/dev/null \
     && ! grep -qE '^\s*(return|this\.[a-zA-Z]+ =)' "$sk/templates/example.declare.ts" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} declare template is declare-only (no impl bodies)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} declare template contains implementation bodies"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0003 — Delegate §10 observability to agenticapps-observability
# Testable non-interactively: idempotency + jq apply/rollback on a synthetic
# config; conditional AGENTS.md repoint on a synthetic fixture.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0003() {
  echo ""
  echo "${YELLOW}=== Migration 0003 — Delegate §10 observability ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-edit test not run"
    SKIP=$((SKIP+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Synthetic config without the delegation.
  cat > "$tmp/config.json" <<'JSON'
{ "hooks": { "per_task": { "tdd": { "skill": "superpowers:test-driven-development" } } } }
JSON

  assert_check "idempotency: fresh config needs the §10 delegation" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply Step 1's jq.
  ( cd "$tmp" && jq '.hooks.observability = {
      "delegated_to": "observability",
      "implements_spec": "0.4.0",
      "host": "opencode",
      "invoke": "$observability",
      "spec_section": "10"
    }' config.json > config.tmp && mv config.tmp config.json )

  assert_check "after apply: §10 delegation present" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "applied"

  # Base hooks must be intact.
  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} base hooks intact after delegation record"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} base hooks lost"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes the delegation.
  ( cd "$tmp" && jq 'del(.hooks.observability)' config.json > config.tmp && mv config.tmp config.json )
  assert_check "after rollback: delegation removed" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Step 2 §10.8 relocate: an anchored observability block in CLAUDE.md (init's
  # output) is moved to AGENTS.md, preserving its real content, and removed from
  # CLAUDE.md.
  printf '# Project\n\n<!-- agenticapps:observability:start -->\nobservability:\n  spec_version: 0.3.2\n  skill: add-observability\n  policy: lib/observability/policy.md\n<!-- agenticapps:observability:end -->\n' > "$tmp/CLAUDE.md"
  printf '# AGENTS\n\nbody\n' > "$tmp/AGENTS.md"
  ( cd "$tmp" \
    && awk '/<!-- agenticapps:observability:start -->/,/<!-- agenticapps:observability:end -->/' CLAUDE.md >> AGENTS.md \
    && awk 'BEGIN{d=0} /<!-- agenticapps:observability:start -->/{d=1} d==0{print} /<!-- agenticapps:observability:end -->/{d=0}' CLAUDE.md > CLAUDE.md.t && mv CLAUDE.md.t CLAUDE.md )
  if ( cd "$tmp" \
       && grep -q '^observability:' AGENTS.md \
       && grep -q 'policy: lib/observability/policy.md' AGENTS.md \
       && ! grep -q '<!-- agenticapps:observability:start -->' CLAUDE.md ); then
    echo "  ${GREEN}PASS${RESET} Step 2 relocates the §10.8 block CLAUDE.md→AGENTS.md (content preserved)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Step 2 relocate did not move the §10.8 block correctly"
    FAIL=$((FAIL+1))
  fi

  # Step 3 conditional repoint: a stale 'skill: add-observability' becomes 'skill: observability'
  # (anchored to a line-leading skill: key).
  ( cd "$tmp" && sed -i.bak -E 's/^([[:space:]]*skill:[[:space:]]*)add-observability/\1observability/' AGENTS.md && rm -f AGENTS.md.bak )
  if ( cd "$tmp" && grep -q 'skill: observability' AGENTS.md && ! grep -qE '^[[:space:]]*skill:[[:space:]]*add-observability' AGENTS.md ); then
    echo "  ${GREEN}PASS${RESET} Step 3 repoints a stale add-observability skill ref (anchored sed)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Step 3 repoint did not rewrite the stale skill ref"
    FAIL=$((FAIL+1))
  fi

  # The delegation/binding doc + ADR ship.
  if [ -f "$REPO_ROOT/docs/observability-delegation.md" ] && [ -f "$REPO_ROOT/docs/decisions/0005-adopt-observability-architecture.md" ]; then
    echo "  ${GREEN}PASS${RESET} delegation doc + ADR-0005 ship"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} delegation doc or ADR-0005 missing"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0004 — Re-vendor §11 mirror (blank-line drift fix)
# The live AGENTS.md §11 block MUST match the (corrected) mirror, and the mirror
# MUST match current core §11 (checked fence-relative in test_migration_0001).
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0004() {
  echo ""
  echo "${YELLOW}=== Migration 0004 — Re-vendor §11 mirror ===${RESET}"
  local mirror="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

  # The scaffolder's own AGENTS.md §11 block must be byte-identical to the
  # corrected mirror (this is the post-0004 invariant + the idempotency check).
  if awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' "$REPO_ROOT/AGENTS.md" \
       | diff -q - "$mirror" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} AGENTS.md §11 block == corrected mirror (re-vendor applied)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} AGENTS.md §11 block differs from the corrected mirror"
    FAIL=$((FAIL+1))
  fi

  # The mirror must be the 79-line (post-10f2c96) shape, not the stale 75-line one.
  local n; n=$(wc -l < "$mirror" | tr -d ' ')
  if [ "$n" -ge 79 ]; then
    echo "  ${GREEN}PASS${RESET} mirror is the current ($n-line) core §11 shape"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} mirror is the stale shape ($n lines; expected ≥79)"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0005 — Knowledge capture (spec §15)
# Testable non-interactively: the config merge resolves <repo-name> and
# preserves a pre-existing (codex) key; the AGENTS.md section insert is present
# and idempotent; the version bump round-trips.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0005() {
  echo ""
  echo "${YELLOW}=== Migration 0005 — Knowledge capture (spec §15) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — knowledge-capture test not run"
    SKIP=$((SKIP+1)); return
  fi

  local kctpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/config-knowledge-capture.json"
  local notetpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/obsidian-learnings-note.md"
  local agentstpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md"

  # Templates ship.
  if [ -f "$kctpl" ] && [ -f "$notetpl" ] && [ -f "$agentstpl" ]; then
    echo "  ${GREEN}PASS${RESET} knowledge-capture templates ship (config + note + agents-md)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} knowledge-capture templates missing"
    FAIL=$((FAIL+1)); return
  fi

  # Config template is host-neutral (enabled + note only; no host key).
  if jq -e '.knowledge_capture | (has("enabled") and has("note")) and ((keys | length) == 2)' "$kctpl" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} config template is host-neutral (enabled + note only)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} config template is not host-neutral"
    FAIL=$((FAIL+1))
  fi

  # Note skeleton declares hosts: [opencode].
  if grep -qE '^hosts: \[opencode\]$' "$notetpl"; then
    echo "  ${GREEN}PASS${RESET} note skeleton declares hosts: [opencode]"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} note skeleton missing hosts: [opencode]"
    FAIL=$((FAIL+1))
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Step 1 — config merge on a codex co-install (host-namespaced-looking hooks
  # present). The merge must add knowledge_capture, resolve <repo-name>, and
  # preserve the pre-existing key.
  cat > "$tmp/config.json" <<'JSON'
{ "host": "opencode", "hooks": { "per_task": { "tdd": { "skill": "superpowers:test-driven-development" } } } }
JSON

  assert_check "idempotency: fresh config needs knowledge_capture" \
    "jq -e '.knowledge_capture' config.json >/dev/null" "$tmp" "not-applied"

  ( cd "$tmp" \
    && KC="$(jq -c --arg name "widget-repo" '.knowledge_capture.note |= gsub("<repo-name>"; $name) | .knowledge_capture' "$kctpl")" \
    && jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' config.json > config.tmp && mv config.tmp config.json )

  assert_check "after apply: knowledge_capture present" \
    "jq -e '.knowledge_capture.enabled == true' config.json >/dev/null" "$tmp" "applied"

  if ( cd "$tmp" && jq -e '.knowledge_capture.note | endswith("widget-repo.md") and (contains("<repo-name>") | not)' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} <repo-name> resolved in note path (no placeholder remains)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} <repo-name> not resolved in note path"
    FAIL=$((FAIL+1))
  fi

  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development" and .host == "opencode"' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} pre-existing config keys preserved through merge"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} pre-existing config keys lost in merge"
    FAIL=$((FAIL+1))
  fi

  # Idempotent re-apply: block already present → merge is a no-op on the note.
  if ( cd "$tmp" && jq -e '.knowledge_capture' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} idempotency guard positive on second apply (block preserved verbatim)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} idempotency guard failed"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes only the added block.
  ( cd "$tmp" && jq 'del(.knowledge_capture)' config.json > config.tmp && mv config.tmp config.json )
  assert_check "after rollback: knowledge_capture removed, base intact" \
    "jq -e '.knowledge_capture' config.json >/dev/null" "$tmp" "not-applied"

  # Step 2 — AGENTS.md section insert. Synthetic AGENTS.md with the marker pair
  # but no section; apply the migration's extract+insert; assert section present
  # and a second apply is a no-op (idempotency grep).
  printf '# AGENTS\n\n<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->\n\n## Something\n\nbody\n\n<!-- END: agentic-apps-workflow sections -->\n' > "$tmp/AGENTS.md"

  ( cd "$tmp"
    SECFILE="$(mktemp)"
    awk '
      /^## Knowledge Capture — Ritual Tail \(spec §15\)/ {f=1}
      /^<!-- END: agentic-apps-workflow sections -->/    {f=0}
      f {buf[n++]=$0}
      END { last=n-1; while (last>=0 && buf[last]=="") last--; for(i=0;i<=last;i++) print buf[i] }
    ' "$agentstpl" > "$SECFILE"
    awk -v secfile="$SECFILE" '
      /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
        while ((getline line < secfile) > 0) print line
        close(secfile); print ""; ins=1
      }
      { print }
    ' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
    rm -f "$SECFILE" )

  if grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' "$tmp/AGENTS.md" \
     && grep -q '(opencode)' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} AGENTS.md section inserted with (opencode) host tag"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} AGENTS.md section not inserted correctly"
    FAIL=$((FAIL+1))
  fi

  # Section lands INSIDE the marker block (before END).
  if awk '/<!-- BEGIN: agentic-apps-workflow sections/{b=1} /^## Knowledge Capture/{if(b)k=1} /<!-- END: agentic-apps-workflow sections/{if(k)ok=1} END{exit ok?0:1}' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} section is inside the marker block (before END)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section landed outside the marker block"
    FAIL=$((FAIL+1))
  fi

  # Idempotency: the migration's grep guard is positive now → re-apply is a no-op.
  assert_check "idempotency: section present → skip re-insert" \
    "grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md" "$tmp" "applied"

  # Step 3 — version bump round-trip on a synthetic SKILL.md frontmatter.
  printf -- '---\nname: agentic-apps-workflow\nversion: 0.2.1\nimplements_spec: 0.4.0\n---\n' > "$tmp/SKILL.md"
  ( cd "$tmp" && sed -i.bak -E 's/^version: 0\.2\.1$/version: 0.3.0/' SKILL.md && rm -f SKILL.md.bak )
  if grep -q '^version: 0.3.0$' "$tmp/SKILL.md" && grep -q '^implements_spec: 0.4.0$' "$tmp/SKILL.md"; then
    echo "  ${GREEN}PASS${RESET} version bump 0.2.1→0.3.0 (implements_spec untouched)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} version bump did not round-trip"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0006 — config conformance claim + §13 binding.
#
# Regression cover for the fork-era defect (present since 50b5d76): the snapshot
# seeded implements_spec 0.1.0 and lacked 0002's strengthened_by binding, while
# templates/config-hooks.json carried both. The parity guard could not see it —
# it compares snapshot against the repo's live config, and both sides were
# equally wrong. The snapshot-vs-template check below is the one that bites.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0006() {
  echo ""
  echo "${YELLOW}=== Migration 0006 — config conformance claim + §13 binding ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — conformance-claim test not run"
    SKIP=$((SKIP+1)); return
  fi

  local snap="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/snapshot/planning-config.json"
  local tpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json"

  if [ ! -f "$snap" ] || [ ! -f "$tpl" ]; then
    echo "  ${RED}FAIL${RESET} snapshot and/or template config missing"
    FAIL=$((FAIL+1)); return
  fi

  # The invariant 0006 exists to restore: the claim and the §13 binding move
  # together. A config claiming a version without the §13 binding that version
  # requires is a FALSE claim — worse than an honestly stale one.
  #
  # Asserted against the trigger skill's claim rather than a hardcoded literal.
  # Pinning the version here would make this test a tripwire on every absorption
  # (it was pinned to 0.4.0 and fired on 0007's bump to 0.9.1). The bug 0006
  # fixed was config-vs-SKILL.md DISAGREEMENT plus a missing binding; that is
  # what this checks, at whatever version the host currently claims.
  local claim
  claim="$(sed -n 's/^implements_spec: //p' "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md" | head -1)"
  if [ -z "$claim" ]; then
    echo "  ${RED}FAIL${RESET} trigger SKILL.md carries no implements_spec — host is unversioned (spec/09)"
    FAIL=$((FAIL+1)); return
  fi
  echo "  ${YELLOW}info${RESET} host claims implements_spec: $claim"

  for f in "$snap" "$tpl" "$REPO_ROOT/.planning/config.json"; do
    local label; label="$(basename "$(dirname "$f")")/$(basename "$f")"
    if jq -e --arg claim "$claim" \
         '(.implements_spec == $claim)
          and (.hooks.per_task.tdd.strengthened_by.skill == "opencode-ts-declare-first")' \
         "$f" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} $label: claim mirrors SKILL.md ($claim) AND §13 binding present"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $label: claim/binding invariant broken"
      FAIL=$((FAIL+1))
    fi
  done

  # The base tdd binding must not be clobbered by the strengthener. 57df04d
  # rebound it upstream (opencode-tdd -> superpowers:test-driven-development)
  # without a migration; 0002's post-check was corrected to match in 0006.
  if jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' \
       "$snap" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} base tdd binding intact (upstream superpowers skill)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} base tdd binding clobbered or stale"
    FAIL=$((FAIL+1))
  fi

  # The regression test proper: the two seeding paths must agree. Setup Stage C
  # copies the snapshot; migration 0000 Step 2 copies the template. A project is
  # entitled to the same config either way.
  if diff -q <(jq -S 'del(.knowledge_capture)' "$tpl") \
              <(jq -S 'del(.knowledge_capture)' "$snap") >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} snapshot path == migration path (both seed one config)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} snapshot and template diverge — the two seeding paths disagree"
    FAIL=$((FAIL+1))
  fi

  # Every opencode-* skill ASSERTED in a migration post-check must exist. This is
  # what let 0002 keep asserting the deleted opencode-tdd through four releases:
  # the 57df04d rebind removed the skill without a migration, and nothing checked
  # that the post-checks still named real things.
  #
  # Scoped to post-check bullets (`- \`jq -e ... == "opencode-X"\``) on purpose: a
  # repair migration must be free to name the corpse in its prose and its sed
  # (0006 Step 5 does both), and that is not a live assertion.
  local dead=""
  for ref in $(grep -rhoE '^- `jq -e .*== "opencode-[a-z0-9-]+"' "$REPO_ROOT"/migrations/*.md 2>/dev/null \
               | grep -oE 'opencode-[a-z0-9-]+' | sort -u); do
    [ -d "$REPO_ROOT/skills/$ref" ] || dead="$dead $ref"
  done
  if [ -z "$dead" ]; then
    echo "  ${GREEN}PASS${RESET} every opencode-* skill asserted in a post-check exists"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} post-checks assert non-existent skills:$dead"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0007 — absorb core spec 0.4.0 -> 0.9.1.
#
# Guards the three requirements this migration exists to satisfy, plus the
# 0006 invariant it must not break (claim mirrored between SKILL.md and config).
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0007() {
  echo ""
  echo "${YELLOW}=== Migration 0007 — absorb core spec 0.9.1 ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — absorption test not run"
    SKIP=$((SKIP+1)); return
  fi

  local skill="$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md"
  local snap="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/snapshot/planning-config.json"
  local tpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json"

  # §02 (0.5.0) — plan-review bound on BOTH seeding paths, with the two
  # sub-requirements §02 makes normative: robust resolution order (a single
  # mutable pointer is non-conformant, core ADR-0025) and the grandfather rule.
  # Binding asserted by what it RESOLVES TO, not by an exact literal — 0008
  # re-labelled it to the annotated slash form. Pinning the string here would
  # make this a tripwire on its own successor, which is the mistake 0006's test
  # made and 0007 had to fix.
  for f in "$snap" "$tpl" "$REPO_ROOT/.planning/config.json"; do
    local label; label="$(basename "$(dirname "$f")")/$(basename "$f")"
    if jq -e '(.hooks.pre_execution.plan_review.skill | test("gsd-review"))
              and ((.hooks.pre_execution.plan_review.phase_resolution_order | length) == 4)
              and (.hooks.pre_execution.plan_review.grandfather | test("SUMMARY"))' \
         "$f" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} $label: plan-review bound (resolution order + grandfather)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $label: plan-review gate missing or incomplete"
      FAIL=$((FAIL+1))
    fi
  done

  # The claim, and 0006's invariant that the config mirrors it.
  if grep -q '^implements_spec: 0.9.1$' "$skill" \
     && jq -e '.implements_spec == "0.9.1"' "$REPO_ROOT/.planning/config.json" >/dev/null 2>&1 \
     && jq -e '.implements_spec == "0.9.1"' "$snap" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} claim 0.9.1 mirrored across SKILL.md, config, snapshot"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} claim not 0.9.1 or not mirrored (0006 invariant broken)"
    FAIL=$((FAIL+1))
  fi

  # §08 (0.9.0) — a snapshot host MUST name its guard in its instruction file,
  # and the guard it names must actually exist and actually run in CI.
  if grep -q 'check-snapshot-parity.sh' "$skill" \
     && [ -f "$REPO_ROOT/migrations/check-snapshot-parity.sh" ] \
     && grep -q 'check-snapshot-parity.sh' "$REPO_ROOT/.github/workflows/ci.yml"; then
    echo "  ${GREEN}PASS${RESET} §08: guard named in instruction file, exists, runs in CI"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §08: guard unnamed, missing, or not wired into CI"
    FAIL=$((FAIL+1))
  fi

  # §14 (0.6.0) — declared, since the trigger cannot occur here.
  if grep -q '^## Spec deltas (spec 0.9.1)' "$skill" && grep -q '§14' "$skill"; then
    echo "  ${GREEN}PASS${RESET} §14 declared in Spec deltas"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §14 not declared"
    FAIL=$((FAIL+1))
  fi

  # §09 gate count — core 0.9.0 corrected 15 -> 16 (plan-review was never counted).
  if grep -q '^The 16 gates from$' "$skill"; then
    echo "  ${GREEN}PASS${RESET} gate count says 16 (§09 fix, core 0.9.0)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} gate count stale — §02 enumerates 16"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0008 — the plan-review binding names the slash COMMAND it is.
#
# 0007 bound it as `"skill": "gsd-review"`. There is no gsd-review under
# skills/ — upstream gsd-opencode ships it as commands/gsd/gsd-review.md. The
# gate resolved either way, but a reader greps skills/, finds nothing, and
# concludes the binding is dead (which is exactly what happened, to the agent
# that wrote 0007, against its own code). A binding table that sends readers to
# the wrong place fails its one job (spec/09 item 3).
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0008() {
  echo ""
  echo "${YELLOW}=== Migration 0008 — plan-review binding names the command ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — binding-label test not run"
    SKIP=$((SKIP+1)); return
  fi

  local snap="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/snapshot/planning-config.json"
  local tpl="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json"

  # A GSD entry point is a slash command, not a $skill. Every gate bound to one
  # must say so in slash form — the idiom the trigger's Step 2 routing already
  # uses for /gsd-discuss-phase, /gsd-plan-phase, /gsd-execute-phase.
  for f in "$snap" "$tpl" "$REPO_ROOT/.planning/config.json"; do
    local label; label="$(basename "$(dirname "$f")")/$(basename "$f")"
    if jq -e '.hooks.pre_execution.plan_review.skill | startswith("/gsd-review")' \
         "$f" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} $label: plan-review names /gsd-review (slash-command form)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $label: plan-review binding is not in slash-command form"
      FAIL=$((FAIL+1))
    fi
  done

  # The generalized rule: no binding may name a bare `gsd-*` as though it were a
  # skill. gsd-opencode ships gsd-* as commands (commands/gsd/*.md); the only
  # gsd-* under skills/ are gsd-code-review / gsd-ui-review, which this host does
  # not bind. A bare gsd-* value here means someone repeated 0007's mistake.
  local bare
  bare="$(jq -r '[.. | objects | select(has("skill")) | .skill]
                 | map(select(type == "string" and test("^gsd-")))
                 | join(" ")' "$REPO_ROOT/.planning/config.json" 2>/dev/null)"
  if [ -z "$bare" ]; then
    echo "  ${GREEN}PASS${RESET} no binding names a bare gsd-* as a skill"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} bindings name bare gsd-* as skills (they are slash commands): $bare"
    FAIL=$((FAIL+1))
  fi

  # The claim must NOT have moved — 0008 corrects a label, not conformance.
  if grep -q '^implements_spec: 0.9.1$' "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md"; then
    echo "  ${GREEN}PASS${RESET} conformance claim untouched at 0.9.1"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} claim moved — 0008 must not touch implements_spec"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0009 — Region-aware §11 placement
#
# The §11 injector anchored on the first '## ' heading. In an AGENTS.md that
# leads with a GitNexus block, the first '## ' is '## Always Do' — inside
# <!-- gitnexus:start -->…<!-- gitnexus:end -->. The block lands in the region
# and the next `gitnexus analyze` regenerates the region and eats it silently.
# Recovery is closed (0001/0004 never replay), so this fixes forward.
#
# These fixtures EXTRACT and EXECUTE the migration's own Step 1 shell rather
# than copying it. A fixture that inlines a copy tests the copy, and the two
# drift silently — which is exactly what run-tests.sh:119 did for 0001's awk.
# ─────────────────────────────────────────────────────────────────────────────

# Extract a sentinel-delimited region from a migration document.
# Sentinels are `# name:begin` / `# name:end` — inert comments in both bash and
# awk, so they live inside the migration's real shell without altering it.
extract_region() { # $1 doc  $2 sentinel-name  $3 out-file
  awk -v b="# $2:begin" -v e="# $2:end" '
    index($0, b) { f=1; next }
    index($0, e) { f=0 }
    f { print }
  ' "$1" > "$3"
}

test_migration_0009() {
  echo ""
  echo "${YELLOW}=== Migration 0009 — region-aware §11 placement ===${RESET}"

  local doc="$REPO_ROOT/migrations/0009-spec-11-region-aware-placement.md"
  local mirror="$REPO_ROOT/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

  if [ ! -f "$doc" ] || [ ! -f "$mirror" ]; then
    echo "  ${RED}FAIL${RESET} 0009 document or §11 mirror missing"
    FAIL=$((FAIL+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local step1="$tmp/step1.sh"
  extract_region "$doc" "step1" "$step1"

  # Extractor shape assertion — fail LOUDLY if it locked onto the wrong fence.
  # Without this, a mis-extraction degrades into fixtures that vacuously pass.
  if [ -s "$step1" ] \
     && grep -q 'MIRROR=' "$step1" \
     && grep -q 'AGENTS.md' "$step1" \
     && grep -q 'awk' "$step1" \
     && ! grep -q '```' "$step1"; then
    echo "  ${GREEN}PASS${RESET} extractor locked onto 0009's Step 1 shell (shape ok)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} extractor did NOT lock onto Step 1's shell — fixtures below are meaningless"
    FAIL=$((FAIL+1)); return
  fi

  # Redirect the config dir at a temp mirror so the extracted shell resolves
  # $MIRROR exactly as it would inside a real project.
  local cfgmir="$tmp/cfg/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors"
  mkdir -p "$cfgmir"
  cp "$mirror" "$cfgmir/11-coding-discipline-0.4.0.md"

  run_step1() { # $1 workdir -> echoes exit code
    ( cd "$1" && OPENCODE_CONFIG_DIR="$1/../cfg" bash "$step1" >"$1/step1.log" 2>&1; echo $? )
  }
  lineno() { grep -n "$1" "$2" 2>/dev/null | head -1 | cut -d: -f1; }

  # ── Fixture 01 — gitnexus-led file, §11 absent (state C) ──────────────────
  # The regression shape: first '## ' is INSIDE the region.
  local w="$tmp/01"; mkdir -p "$w"
  printf '# AGENTS.md — demo\n\n<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n## Always Do\n\n- use the graph\n<!-- gitnexus:end -->\n\n## Project Notes\n\nbody\n' > "$w/AGENTS.md"
  run_step1 "$w" >/dev/null
  local p rs
  p="$(lineno 'spec-source' "$w/AGENTS.md")"; rs="$(lineno 'gitnexus:start' "$w/AGENTS.md")"
  if [ -n "$p" ] && [ -n "$rs" ] && [ "$p" -lt "$rs" ]; then
    echo "  ${GREEN}PASS${RESET} 01 gitnexus-led: §11 injected ABOVE the region (L$p < L$rs)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 01 gitnexus-led: §11 at L${p:-none}, region starts L${rs:-none} — inside/absent"
    FAIL=$((FAIL+1))
  fi

  # …and it must survive the region being regenerated (what `gitnexus analyze` does).
  awk '/^<!-- gitnexus:start -->$/{print; print "# GitNexus — regenerated"; skip=1; next}
       /^<!-- gitnexus:end -->$/{skip=0}
       !skip {print}' "$w/AGENTS.md" > "$w/regen.md"
  if grep -q 'Coding Discipline (NON-NEGOTIABLE)' "$w/regen.md"; then
    echo "  ${GREEN}PASS${RESET} 01 §11 survives a modelled region regeneration"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 01 §11 destroyed by region regeneration"
    FAIL=$((FAIL+1))
  fi

  # ── Fixture 02 — §11 already INSIDE a region (state B) ────────────────────
  w="$tmp/02"; mkdir -p "$w"
  {
    printf '# AGENTS.md — demo\n\n<!-- gitnexus:start -->\n# GitNexus\n\n'
    printf '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n'
    cat "$mirror"
    printf '\n## Always Do\n\n- stuff\n<!-- gitnexus:end -->\n\n## Project Notes\n\nbody\n'
  } > "$w/AGENTS.md"
  run_step1 "$w" >/dev/null
  p="$(lineno 'spec-source' "$w/AGENTS.md")"; rs="$(lineno 'gitnexus:start' "$w/AGENTS.md")"
  local n; n="$(grep -c 'spec-source' "$w/AGENTS.md")"
  if [ -n "$p" ] && [ -n "$rs" ] && [ "$p" -lt "$rs" ] && [ "$n" -eq 1 ]; then
    echo "  ${GREEN}PASS${RESET} 02 inside-region: §11 moved above the region, present exactly once"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 02 inside-region: §11 L${p:-none} vs region L${rs:-none}, count=$n (want above, count 1)"
    FAIL=$((FAIL+1))
  fi

  # ── Fixture 03 — healthy file (state A) → byte-identical, zero churn ──────
  # Uses this repo's REAL AGENTS.md: the strongest available no-op evidence.
  w="$tmp/03"; mkdir -p "$w"
  cp "$REPO_ROOT/AGENTS.md" "$w/AGENTS.md"
  run_step1 "$w" >/dev/null
  if diff -q "$REPO_ROOT/AGENTS.md" "$w/AGENTS.md" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} 03 healthy: real AGENTS.md byte-identical (zero churn)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 03 healthy: Step 1 churned an already-correct AGENTS.md"
    FAIL=$((FAIL+1))
  fi

  # ── Fixture 04 — no AGENTS.md → informational skip, exit 0 ────────────────
  w="$tmp/04"; mkdir -p "$w"
  local rc; rc="$(run_step1 "$w")"
  if [ "$rc" = "0" ] && grep -q 'no AGENTS.md' "$w/step1.log"; then
    echo "  ${GREEN}PASS${RESET} 04 absent AGENTS.md: informational skip, exit 0"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 04 absent AGENTS.md: rc=$rc (want 0 + skip notice)"
    FAIL=$((FAIL+1))
  fi

  # ── Fixture 05 — hand-pasted §11, no provenance (state D) → exit 3 ────────
  w="$tmp/05"; mkdir -p "$w"
  printf '# Title\n\n## Coding Discipline (NON-NEGOTIABLE)\n\nhand-written\n' > "$w/AGENTS.md"
  cp "$w/AGENTS.md" "$w/before.md"
  rc="$(run_step1 "$w")"
  if [ "$rc" = "3" ] && diff -q "$w/before.md" "$w/AGENTS.md" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} 05 unmanaged §11: refused with exit 3, file untouched"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 05 unmanaged §11: rc=$rc (want 3) or file was modified"
    FAIL=$((FAIL+1))
  fi

  # ── Fixture 06 — no '## ', no region → EOF append ─────────────────────────
  w="$tmp/06"; mkdir -p "$w"
  printf '# Only a title\n\nsome body\n' > "$w/AGENTS.md"
  run_step1 "$w" >/dev/null
  if grep -q 'spec-source' "$w/AGENTS.md" && grep -q 'Coding Discipline' "$w/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} 06 no heading/region: §11 appended at EOF"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 06 no heading/region: §11 not appended"
    FAIL=$((FAIL+1))
  fi

  # ── Self-conformance — this repo's own §11 sits above its own region ──────
  local sp sr
  sp="$(lineno 'spec-source.*§11' "$REPO_ROOT/AGENTS.md")"
  sr="$(lineno 'gitnexus:start' "$REPO_ROOT/AGENTS.md")"
  if [ -n "$sp" ] && { [ -z "$sr" ] || [ "$sp" -lt "$sr" ]; }; then
    echo "  ${GREEN}PASS${RESET} self-conformance: this repo's §11 (L$sp) is above its region (L${sr:-none})"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} self-conformance: §11 L${sp:-none} is not above region L${sr:-none}"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Drift test — the scaffolder's SKILL.md version MUST equal the latest
# migration's to_version (version is migration-coupled).
# ─────────────────────────────────────────────────────────────────────────────

test_drift() {
  echo ""
  echo "${YELLOW}=== Drift — SKILL.md version == latest migration to_version ===${RESET}"
  # Mechanism from the shared lib (run_drift_test); the POLICY (a mismatch is a
  # hard fail) is this consumer's, per ADR-0035.
  if run_drift_test "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md" "$REPO_ROOT/migrations"; then
    echo "  ${GREEN}PASS${RESET} SKILL.md version matches latest migration to_version"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} drift mismatch (see message above)"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Repo layout sanity checks
# These do not require fixtures; they verify the scaffolder itself
# ships the artifacts the migrations and skills reference.
# ─────────────────────────────────────────────────────────────────────────────

test_repo_layout() {
  echo ""
  echo "${YELLOW}=== Repo layout sanity ===${RESET}"

  for f in \
    skills/agentic-apps-workflow/SKILL.md \
    skills/setup-opencode-agenticapps-workflow/SKILL.md \
    skills/update-opencode-agenticapps-workflow/SKILL.md \
    skills/setup-opencode-agenticapps-workflow/templates/workflow-config.md \
    skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md \
    skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json \
    skills/setup-opencode-agenticapps-workflow/templates/adr-db-security-acceptance.md \
    skills/setup-opencode-agenticapps-workflow/templates/global-agents-additions.md \
    migrations/README.md \
    migrations/0000-baseline.md \
    migrations/0001-inject-spec-11-coding-discipline.md \
    migrations/0002-add-ts-declare-first-skill.md \
    migrations/0003-delegate-observability.md \
    migrations/0004-revendor-spec-11.md \
    migrations/0005-knowledge-capture.md \
    migrations/0006-fix-config-conformance-claim.md \
    migrations/0007-absorb-spec-0.9.1.md \
    migrations/0008-fix-plan-review-binding-label.md \
    skills/setup-opencode-agenticapps-workflow/templates/config-knowledge-capture.json \
    skills/setup-opencode-agenticapps-workflow/templates/obsidian-learnings-note.md \
    docs/decisions/0008-knowledge-capture.md \
    migrations/test-fixtures/README.md \
    vendor/agenticapps-shared/migrations/lib/helpers.sh \
    vendor/agenticapps-shared/migrations/lib/drift-test.sh \
    docs/observability-delegation.md \
    docs/decisions/0005-adopt-observability-architecture.md \
    skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md \
    skills/opencode-ts-declare-first/SKILL.md \
    skills/opencode-ts-declare-first/templates/example.declare.ts \
    skills/opencode-ts-declare-first/templates/example.test.ts \
    skills/opencode-ts-declare-first/templates/example.impl.ts \
    install.sh ; do
    if [ -f "$f" ]; then
      echo "  ${GREEN}PASS${RESET} $f exists"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $f MISSING"
      FAIL=$((FAIL+1))
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

if [ -z "$FILTER" ] || [ "$FILTER" = "0000" ]; then
  test_migration_0000
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0001" ]; then
  test_migration_0001
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0002" ]; then
  test_migration_0002
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0003" ]; then
  test_migration_0003
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0004" ]; then
  test_migration_0004
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0005" ]; then
  test_migration_0005
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0006" ]; then
  test_migration_0006
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0007" ]; then
  test_migration_0007
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0008" ]; then
  test_migration_0008
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0009" ]; then
  test_migration_0009
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "drift" ]; then
  test_drift
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "layout" ]; then
  test_repo_layout
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "${YELLOW}=== Summary ===${RESET}"
echo "  ${GREEN}PASS${RESET}: $PASS"
[ $FAIL -gt 0 ] && echo "  ${RED}FAIL${RESET}: $FAIL"
[ $SKIP -gt 0 ] && echo "  ${YELLOW}SKIP${RESET}: $SKIP"

if [ $FAIL -gt 0 ]; then
  exit 1
elif [ $PASS -eq 0 ] && [ $SKIP -eq 0 ]; then
  echo "  ${RED}NO TESTS RAN${RESET}"
  exit 1
else
  exit 0
fi

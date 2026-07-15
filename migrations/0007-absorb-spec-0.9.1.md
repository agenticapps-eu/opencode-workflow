---
id: 0007
slug: absorb-spec-0.9.1
title: Absorb core spec 0.4.0 -> 0.9.1 — plan-review gate, §14 delta, §08 guard (v0.3.1 -> 0.4.0)
from_version: 0.3.1
to_version: 0.4.0
applies_to:
  - .planning/config.json                      # bind plan-review gate; implements_spec 0.4.0 -> 0.9.1
  - skills/agentic-apps-workflow/SKILL.md       # claim, gate count, plan-review row, §14 delta, §08 guard, version bump
  - docs/ENFORCEMENT-PLAN.md                    # conformance claim + binding table (scaffolder-only)
  - .opencode/workflow-version.txt              # record new project version
requires: []
optional_for: []
---

# Migration 0007 — Absorb core spec 0.4.0 → 0.9.1 (v0.3.1 → 0.4.0)

Moves the host's conformance claim from **0.4.0 to 0.9.1**, closing the five
minors it had drifted behind. Three of the five needed no work; two did.

| Core spec | Requires | Status before this migration |
|---|---|---|
| 0.5.0 | §02 `plan-review` pre-execution gate | **Missing** — not bound, not declared a delta |
| 0.6.0 | §14 prompt-injection | **Missing** — not wired, not declared N/A |
| 0.7.0 | §15 knowledge capture | Already done (migration `0005`) |
| 0.8.0 | §04 addition composition | Already compliant — exactly 13 flags, no additions |
| 0.9.0 | §08 guarded snapshot + §09 gate count 15→16 | Guard already ran in CI; **not named** in the instruction file |
| 0.9.1 | §08 prose clarification | No host action |

**Why the claim was the liability.** Core spec 0.9.0 amended §08 so that a
guarded snapshot install is conformant — a change written *because of* this
host: the 0.9.0 changelog names `opencode-workflow` (ADR-0007) and
`claude-workflow` as the two hosts that independently shipped snapshot installs
against a §08 that required replay, and states both "were non-conformant on a
MUST". So while this host cited 0.4.0, its own install strategy was forbidden by
the §08 of the version it claimed. Moving to 0.9.1 **retires an existing
violation** rather than taking on new obligations — the opposite of how a
version bump usually reads.

**`implements_spec` is the host's claim, not a per-skill stamp.** Only the
primary instruction file's citation is normative (spec/09). The `opencode-*`
gate skills cite the version of the *contract they implement* and do NOT move
with the claim: `opencode-ts-declare-first` stays at `0.4.0` because §13 is
still a 0.4.0 section. This matches the reference host — `claude-workflow` cites
`0.9.0` on its trigger and `0.4.0` on its `ts-declare-first`. `.planning/config.json`
mirrors the claim, per the invariant migration `0006` restored.

**Why a minor scaffolder bump (0.3.1 → 0.4.0):** a new gate is bound, which is
additive behavior. No gate is removed or rebound. Every live project is at 0.3.1
after `0006`, so `0.3.1 → 0.4.0` is the shape that reaches the fleet via
`$update-opencode-agenticapps-workflow`.

**Supported upgrade floor:** `0.3.1 → 0.4.0`. Projects below 0.3.1 replay the
chain through `0006` first.

## Pre-flight

```bash
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }
test -f .planning/config.json || { echo ".planning/config.json missing — run 0000 first"; exit 1; }
jq -e '.hooks' .planning/config.json >/dev/null || { echo ".hooks absent"; exit 1; }
# 0006 must have landed: the claim/binding invariant is this migration's baseline.
jq -e '.implements_spec == "0.4.0"' .planning/config.json >/dev/null \
  || { echo "ABORT: config implements_spec is not 0.4.0 — run 0006 first"; exit 1; }
```

## Steps

### Step 1: Bind the `plan-review` gate (§02, core 0.5.0)

The 16th gate. It fires after a phase's plans exist and before the first
code-touching execution edit, and is bound to `gsd-review` — this host binds
upstream GSD rather than re-porting it (`57df04d`). Two sub-requirements from
§02 are recorded declaratively in the gate body because this host's hooks are
prose the agent executes, not shell:

- **Phase resolution order** — explicit pointer → workflow state → newest plan
  by mtime → fail-open. §02 makes a single mutable pointer non-conformant on its
  own (core ADR-0025).
- **Grandfather rule** — a `*-SUMMARY.md` for the resolved phase means the phase
  already executed, so the gate allows the edit. Without this, enabling the gate
  retroactively blocks work shipped before it existed.

**Idempotency check:** `jq -e '.hooks.pre_execution.plan_review.skill == "gsd-review"' .planning/config.json >/dev/null`
**Pre-condition:** `.planning/config.json` is valid JSON with a `.hooks` object
**Apply:**
```bash
tmp="$(mktemp)"
jq '.hooks = ({
  "pre_execution": {
    "plan_review": {
      "skill": "gsd-review",
      "fires_when": "phase has one or more *-PLAN.md and no *-SUMMARY.md exists for the resolved phase — fires before the first code-touching execution edit",
      "evidence": "{phase}-REVIEWS.md in the phase directory, carrying independent plan review from at least two external AI reviewers",
      "phase_resolution_order": [
        "explicit phase pointer",
        "workflow state (current_phase)",
        "newest plan artifact by mtime",
        "fail-open (allow)"
      ],
      "grandfather": "a *-SUMMARY.md for the resolved phase means the phase already executed — the gate allows the edit, so enabling enforcement never retroactively blocks work shipped before the gate functioned",
      "implements_spec": "0.5.0"
    }
  }
} + .hooks)' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq 'del(.hooks.pre_execution)' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```

### Step 2: Move the conformance claim to 0.9.1

The claim and the config mirror move together — the invariant `0006` restored.

**Idempotency check:** `jq -e '.implements_spec == "0.9.1"' .planning/config.json >/dev/null && grep -q '^implements_spec: 0.9.1$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** both currently read `0.4.0` (abort otherwise — never overwrite an unpredicted claim)
**Apply:**
```bash
tmp="$(mktemp)"
jq '.implements_spec = "0.9.1"' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
sed -i.0007.bak -E \
  -e 's/^implements_spec: 0\.4\.0$/implements_spec: 0.9.1/' \
  -e 's/^version: 0\.3\.1$/version: 0.4.0/' \
  skills/agentic-apps-workflow/SKILL.md
# Prose citation in the skill body + the corrected gate count (§09 said 15; §02
# enumerates 16 — the count was never updated when plan-review landed at 0.5.0,
# fixed in core 0.9.0).
sed -i.0007.bak -E \
  -e 's/^v0\.4\.0\. The frontmatter `implements_spec: 0\.4\.0` is the conformance$/v0.9.1. The frontmatter `implements_spec: 0.9.1` is the conformance/' \
  -e 's/^The 15 gates from$/The 16 gates from/' \
  skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0007.bak
```
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md`, and
`jq '.implements_spec = "0.4.0"'` back onto the config.

### Step 3: Name the drift guard in the instruction file (§08, core 0.9.0)

§08 v0.9.0: a host installing from a snapshot **MUST** name its guard in its
instruction file. The guard already ran in CI — this step makes the claim
checkable by a reader of the skill, which is what §08 asks for.

**Idempotency check:** `grep -q 'check-snapshot-parity.sh' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `test -f migrations/check-snapshot-parity.sh` (never name a guard that does not exist)
**Apply:** insert the `## Setup strategy — guarded snapshot (spec §08)` section
into `skills/agentic-apps-workflow/SKILL.md`, naming
`migrations/check-snapshot-parity.sh` and its CI step. Prose insert — see the
section body in the shipped skill for the exact text.
**Rollback:** delete the section.

### Step 4: Declare the §14 delta (core 0.6.0)

**Idempotency check:** `grep -q '^## Spec deltas (spec 0.9.1)' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** none — prose insert
**Apply:** insert the `## Spec deltas (spec 0.9.1)` section, declaring §14
**trivially conformant** (this scaffolder builds no LLM prompts from
non-self-authored values, so §14's trigger cannot occur; §09 requires only that
the host say so), plus the eight trigger-impossible gates and the §10 delegation
for readers who look for them. Also annotate the `security` gate row with §02's
v0.6.0 obligation to record §14 evidence on LLM-scoped changesets.
**Rollback:** delete the section and revert the `security` row.

### Step 5: Record the new project version

**Idempotency check:** `grep -q '^0.4.0$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.4.0" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.3.1" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. plan-review bound, with both §02 sub-requirements recorded
jq -e '.hooks.pre_execution.plan_review.skill == "gsd-review"' .planning/config.json >/dev/null
jq -e '.hooks.pre_execution.plan_review.phase_resolution_order | length == 4' .planning/config.json >/dev/null
jq -e '.hooks.pre_execution.plan_review.grandfather | test("SUMMARY")' .planning/config.json >/dev/null

# 2. Claim moved, and the 0006 invariant (claim mirrored in config) still holds
grep -q '^implements_spec: 0.9.1$' skills/agentic-apps-workflow/SKILL.md
jq -e '.implements_spec == "0.9.1"' .planning/config.json >/dev/null

# 3. §08 guard named in the instruction file; the named guard exists
grep -q 'check-snapshot-parity.sh' skills/agentic-apps-workflow/SKILL.md
test -f migrations/check-snapshot-parity.sh

# 4. §14 declared
grep -q '^## Spec deltas (spec 0.9.1)' skills/agentic-apps-workflow/SKILL.md

# 5. Gate count corrected (§09 fix, core 0.9.0)
grep -q '^The 16 gates from$' skills/agentic-apps-workflow/SKILL.md

# 6. Version recorded
grep -q '^version: 0.4.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^0.4.0$' .opencode/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.4.0) == latest migration `to_version` (0.4.0)
- Snapshot parity green: rebuilt via `check-snapshot-parity.sh --rebuild`

## Skip cases

- **`from_version` mismatch** (project not at 0.3.1) → migration framework skips
  silently. Projects below 0.3.1 replay the chain first.
- **Config seeded from `templates/config-hooks.json` at 0.4.0-scaffolder or
  later** → Steps 1–2 idempotency checks are already positive; both no-op and
  Steps 3–5 still run.
- **`implements_spec` at some value other than `0.4.0`/`0.9.1`** → Step 2's
  pre-condition aborts. A hand-edited claim is a human decision.

## Compatibility

- **Additive (minor) bump** to `0.4.0`: one gate bound, three prose sections
  added, one scalar moved. No gate removed or rebound; no canonical prose
  touched (§04's block is byte-identical to core's — v0.8.0 changed only the
  rules around it, and this host adds no red flags, so it was already
  compliant).
- **No downstream break.** `plan-review`'s grandfather rule means enabling it
  cannot retroactively block a project that already shipped phases.
- **Drift coupling:** as the highest-numbered migration, `0007`'s `to_version`
  (0.4.0) is the drift target; the trigger SKILL.md is bumped in lockstep
  (`run-tests.sh` `test_drift`).
- **Snapshot parity (ADR-0007):** the snapshot is rebuilt from the corrected
  end state, so fresh installs get the absorption by construction and existing
  installs get it via this migration.

## Not in scope

- **§13's implicit trigger.** `opencode-ts-declare-first` ships and its
  declarative trigger is recorded in the config (`strengthened_by.fires_when`).
  §13's Conformance section is SHOULD/MAY throughout and this scaffolder is not
  a TypeScript project, so `full` is preserved either way.
- **A programmatic gate for `plan-review`.** §02 says hosts bind the skill and
  **SHOULD** enforce it with a programmatic gate. This host's hooks are prose
  the agent executes (there is no shell hook layer, unlike claude's
  `.claude/hooks/`), so the binding is declarative and the SHOULD is
  deliberately unmet — consistent with every other gate here.

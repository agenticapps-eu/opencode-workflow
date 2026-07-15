---
id: 0008
slug: fix-plan-review-binding-label
title: Name the plan-review binding as the slash command it is (v0.4.0 -> 0.4.1)
from_version: 0.4.0
to_version: 0.4.1
applies_to:
  - .planning/config.json                      # plan_review.skill -> annotated /gsd-review
  - skills/agentic-apps-workflow/SKILL.md       # Step 3 row + version bump 0.4.0 -> 0.4.1
  - docs/ENFORCEMENT-PLAN.md                    # binding row (scaffolder-only)
  - .opencode/workflow-version.txt              # record new project version
requires: []
optional_for: []
---

# Migration 0008 — Name the plan-review binding correctly (v0.4.0 → 0.4.1)

Migration `0007` bound the §02 `plan-review` gate as:

```json
"skill": "gsd-review"
```

**`gsd-review` is not a skill.** Upstream gsd-opencode ships it as a slash
*command* — `commands/gsd/gsd-review.md`, installed to
`${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/commands/gsd/gsd-review.md`.
There is no `gsd-review` under `skills/`, in this repo or in the gsd-opencode
package (verified against `gsd-opencode@1.38.5`: its `skills/` ships
`gsd-code-review` and `gsd-ui-review`, but no `gsd-review`).

**Why this matters even though the gate works.** The binding resolves — the
command exists, and `/gsd-review` is how it is invoked. But the whole purpose of
a binding table (spec/09 item 3: *"the host MUST document the bound skill (or
plugin, or tool)"*) is telling a reader where to find the bound thing. Labelled
`"skill": "gsd-review"`, a reader greps `skills/`, finds nothing, and concludes
the binding is dead. That is not hypothetical: it happened to the agent that
wrote `0007`, against its own freshly-merged code, within the hour.

`0007`'s label was also inconsistent with this host's own conventions: the
trigger skill's Step 2 routing table already writes every GSD entry point in
slash form (`/gsd-discuss-phase`, `/gsd-plan-phase`, `/gsd-execute-phase`),
because `$name` is the *skill* idiom and `/name` is the *command* idiom. Only
this one binding used the bare form.

**Reference shape.** `claude-workflow` — the host that authors the spec's
canonical prose — annotates the identical binding:

```json
"skill": "/gsd-review (slash command from templates/gsd-patches/patches/workflows/review.md)"
```

This migration adopts the same shape with this host's provenance. The `skill`
key keeps its name (it is the config's generic binding field, and spec/09 reads
"skill **or plugin, or tool**"); only the value becomes honest.

**Why a patch bump:** nothing about the gate's behavior changes. The same
command was bound before and after; this corrects what the binding *says*. No
gate added, removed, or rebound. Every live project is at 0.4.0 after `0007`, so
`0.4.0 → 0.4.1` is the shape that reaches the fleet via
`$update-opencode-agenticapps-workflow`.

**Why not amend `0007` in place:** `0007` shipped (merged, v0.4.0). The binding
value is real state in an installed project's `.planning/config.json`, not inert
prose — so a project that already ran `0007` needs an upgrade path, and editing
a released migration would silently diverge new installs from existing ones.
Same discipline `0006` applied to `0001`. (Contrast `0006` Step 5, which *did*
edit `0002` in place — that was a post-check, prose an operator runs, inert for
installed projects.)

**Supported upgrade floor:** `0.4.0 → 0.4.1`. Projects below 0.4.0 replay the
chain through `0007` first.

## Pre-flight

```bash
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }
test -f .planning/config.json || { echo ".planning/config.json missing — run 0000 first"; exit 1; }
jq -e '.hooks.pre_execution.plan_review' .planning/config.json >/dev/null \
  || { echo "ABORT: plan_review gate absent — run 0007 first"; exit 1; }
```

## Steps

### Step 1: Name the binding as the slash command it is

**Idempotency check:** `jq -e '.hooks.pre_execution.plan_review.skill | startswith("/gsd-review")' .planning/config.json >/dev/null`
**Pre-condition:** `jq -e '.hooks.pre_execution.plan_review.skill == "gsd-review"' .planning/config.json >/dev/null` (abort on any other value — never overwrite a hand-edited binding)
**Apply:**
```bash
tmp="$(mktemp)"
jq '.hooks.pre_execution.plan_review.skill =
    "/gsd-review (slash command from upstream gsd-opencode: commands/gsd/gsd-review.md)"' \
  .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq '.hooks.pre_execution.plan_review.skill = "gsd-review"' .planning/config.json > "$tmp" \
  && mv "$tmp" .planning/config.json
```

### Step 2: Correct the two prose surfaces that repeat the mislabel

**Idempotency check:** `! grep -qE '^\| `plan-review` \| `gsd-review`' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** none — prose edit, inert for installed projects
**Apply:** in the trigger skill's Step 3 gate table and
`docs/ENFORCEMENT-PLAN.md`'s binding table, rewrite the `plan-review` row to name
**`/gsd-review`** and say plainly that it is a slash command from upstream
gsd-opencode (`commands/gsd/gsd-review.md`), not a skill under `skills/`.
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md docs/ENFORCEMENT-PLAN.md`

### Step 3: Bump the scaffolder version

**Idempotency check:** `grep -q '^version: 0.4.1$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.4.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0008.bak -E 's/^version: 0\.4\.0$/version: 0.4.1/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0008.bak
```
(`implements_spec: 0.9.1` is unchanged — do NOT touch it. This migration corrects
a label, not a conformance claim.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.4\.1$/version: 0.4.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.4.1$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.4.1" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.4.0" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. Binding names the command, in slash form (ALWAYS true on success)
jq -e '.hooks.pre_execution.plan_review.skill | startswith("/gsd-review")' .planning/config.json >/dev/null

# 2. The gate is otherwise untouched — 0007's §02 sub-requirements still recorded
jq -e '.hooks.pre_execution.plan_review.phase_resolution_order | length == 4' .planning/config.json >/dev/null
jq -e '.hooks.pre_execution.plan_review.grandfather | test("SUMMARY")' .planning/config.json >/dev/null

# 3. The conformance claim did NOT move
grep -q '^implements_spec: 0.9.1$' skills/agentic-apps-workflow/SKILL.md

# 4. Version bumped
grep -q '^version: 0.4.1$' skills/agentic-apps-workflow/SKILL.md
grep -q '^0.4.1$' .opencode/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.4.1) == latest migration `to_version` (0.4.1)
- Snapshot parity green: rebuilt via `check-snapshot-parity.sh --rebuild`

## Skip cases

- **`from_version` mismatch** (project not at 0.4.0) → migration framework skips
  silently. Projects below 0.4.0 replay the chain first.
- **Binding already in slash form** (config seeded from a 0.4.1-or-later
  template) → Step 1 idempotency is positive; it no-ops and Steps 2–4 still run.
- **Binding hand-edited to some third value** → Step 1's pre-condition aborts.

## Compatibility

- **Patch bump** to `0.4.1`: behavior identical. The same upstream command was
  bound before and after — only the label changes.
- **`implements_spec` unchanged at 0.9.1.** §02 asks that the host bind a
  multi-AI plan-review skill and document it; the binding existed and resolved
  before this migration. This makes the documentation true, not the conformance.
- **Drift coupling:** as the highest-numbered migration, `0008`'s `to_version`
  (0.4.1) is the drift target; the trigger SKILL.md moves in lockstep.
- **Snapshot parity (ADR-0007):** snapshot rebuilt from the corrected end state.

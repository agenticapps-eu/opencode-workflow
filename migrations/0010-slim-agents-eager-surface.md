---
id: 0010
slug: slim-agents-eager-surface
title: Slim the eager AGENTS.md to §11 + pointers — spec 0.10.0 §12 (v0.5.0 -> 0.6.0)
from_version: 0.5.0
to_version: 0.6.0
applies_to:
  - AGENTS.md                                               # drop relocated sections, install pointers
  - skills/agentic-apps-workflow/SKILL.md                   # absorb session-handoff; version + claim bump
  - skills/setup-opencode-agenticapps-workflow/snapshot/agents-block.md      # rebuilt end-state
  - skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md  # rebuilt end-state
  - .planning/config.json                                   # mirror the claim (0006 invariant)
  - docs/ENFORCEMENT-PLAN.md                                # bindings now live in the trigger skill
  - .opencode/workflow-version.txt                          # record new project version
requires: []
optional_for: []
---

# Migration 0010 — Slim the eager AGENTS.md (v0.5.0 → 0.6.0)

Core spec **0.10.0** added an "Instruction-surface economy (eager vs lazy)"
convention to §12 (core ADR-0020). §12 already governed *where in* the
always-loaded instruction file behavior-critical prose sits; 0.10.0 extends that
from ordering to **membership**:

> A host implementation **SHOULD** keep the always-loaded file to the minimum
> that must be resident on *every* turn: the §11 canonical block, verbatim and
> near the top, and a short pointer to the trigger skill that carries the rest.

`AGENTS.md` is injected on every turn — including turns that never touch code —
so its whole content is re-billed per turn. This host was carrying ~150 lines of
procedure there that only binds once a code task is underway, and three of those
four blocks were **already duplicated verbatim** in the trigger skill:

| Block | Was in `AGENTS.md` | Also in `SKILL.md`? |
|---|---|---|
| Workflow Enforcement Hooks (gate table) | 110–141 | yes — Step 3, richer (the normative copy) |
| Skill routing (task size) | 143–154 | yes — Step 1, the authoritative table |
| Knowledge Capture ritual tail (§15) | 173–236 | yes — verbatim, and §15 already *requires* it to live there |
| Session handoff | 156–171 | **no** — this migration moves it |

So for three of the four this is a **de-duplication**, not a relocation: the
eager copy was the redundant one. Only the session-handoff protocol genuinely
moves, and step 2 puts it in the skill before step 1 removes it from `AGENTS.md`.

## Why this is a minor bump, not a patch

It changes the shape of an artifact installed into consuming projects, and it
advances the conformance claim (`implements_spec: 0.9.1 → 0.10.0`). It removes
no gate and weakens no enforcement — see the scope note below — so it is not a
major.

## Scope note — prose moves, enforcement does not

The §12 convention is explicit that a host "whose runtime enforces a gate
programmatically keeps the *hook wiring* where the runtime needs it; only the
explanatory prose moves." Accordingly this migration touches **no** enforcement
surface:

- `.planning/config.json` gate bindings — untouched (except the `implements_spec`
  mirror that 0006 requires).
- `.github/workflows/ci.yml` and `migrations/check-snapshot-parity.sh` — untouched.
- The §11 block, its `<!-- spec-source -->` provenance anchor, and the marker
  pair — untouched. This migration edits only content **below** the §11
  terminator line and **above** the END marker.

A reader who only ever loads `AGENTS.md` still gets §11 (the one block that must
bind on every turn) plus an explicit pointer to where the rest lives.

## Interaction with 0009's strip/inject rules

`0009` manages the §11 block as the span from the provenance line to the
terminator `…session-level discipline the model brings to every diff.`, and its
strip rule deletes exactly that span. Two invariants therefore constrain this
migration, and it preserves both:

1. **Nothing may land between the provenance line and the terminator.** This
   migration's transform ignores every line until the first `## ` heading *after*
   `## Coding Discipline (NON-NEGOTIABLE)`, so the §11 span is passed through
   byte-for-byte.
2. **The §11 block must be followed by a `## ` line or EOF** (the bound 0001
   established for replace and rollback). `## Development Workflow` survives as
   the first heading after the block — rewritten in place, never removed.

Post-check 4 of 0009 (`exactly one` provenance comment) also still holds: this
migration adds no `spec-source` anchor.

## States handled

| Condition | Behaviour |
|---|---|
| Marker pair absent | ABORT (exit 1) — nothing to slim; run `0000`/setup first |
| §11 provenance absent | ABORT (exit 1) — a file outside 0001/0009's management; refuse to edit |
| Already slimmed (pointer present) | No-op (idempotency guard) |
| Full v0.5.0 block present | Slim it |
| Block partially hand-edited (some sections already gone) | Slim what remains; absent sections are simply not matched |

## Pre-flight

```bash
grep -qE '^version: 0\.(5\.0|6\.0)$' skills/agentic-apps-workflow/SKILL.md \
  || { echo "ABORT: expected scaffolder version 0.5.0 (or 0.6.0 if re-running); replay through 0009 first"; exit 1; }
grep -q '^<!-- BEGIN: agentic-apps-workflow sections' AGENTS.md \
  || { echo "ABORT: AGENTS.md has no managed marker block"; exit 1; }
grep -qE '^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$' AGENTS.md \
  || { echo "ABORT: no §11 provenance anchor — file is outside 0001/0009 management"; exit 1; }
```

## Steps

### Step 1: Absorb the session-handoff protocol into the trigger skill

Done **before** step 2 removes it from `AGENTS.md`, so the contract is never
absent from both files at once.

**Idempotency check:** `grep -q '^## Session handoff$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `skills/agentic-apps-workflow/SKILL.md` exists.
**Apply:** insert a `## Session handoff` section immediately above
`## Knowledge Capture — Ritual Tail (spec §15)`, carrying the full protocol that
`AGENTS.md` used to hold: read `.opencode/session-handoff.md` at session start
when it is under 7 days old; **only** the opencode handoff, never a bare root
`session-handoff.md` or another host's (handoffs are host-scoped so several
hosts can share one working tree); write it before ending a session; it is
gitignored because it is a working artifact, not a shipped one. Close with the
ordering constraint that the §15 ritual tail runs *after* the handoff is written.
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md`

### Step 2: Slim the eager AGENTS.md

**Idempotency check:** `grep -q 'Full protocol in the trigger skill' AGENTS.md`
**Pre-condition:** pre-flight (markers + provenance present).
**Apply:**
```bash
# step2:begin
# Drop the three relocated/duplicated sections outright and rewrite the two that
# survive as pointers. Scoped strictly to the managed marker block; the §11 span
# (provenance -> terminator) is never matched because '## Coding Discipline
# (NON-NEGOTIABLE)' falls through to mode="pass" and its subheads are '### '.
awk '
BEGIN { inblk=0; mode="pass" }

/^<!-- BEGIN: agentic-apps-workflow sections/ { inblk=1; print; next }
/^<!-- END: agentic-apps-workflow sections -->/ { inblk=0; mode="pass"; print; next }

!inblk { print; next }

/^## / {
  if ($0 == "## Workflow Enforcement Hooks (MANDATORY)" || \
      $0 == "## Skill routing" || \
      $0 ~ /^## Knowledge Capture — Ritual Tail \(spec §15\)$/) {
    mode="drop"; next
  }
  if ($0 == "## Development Workflow") {
    mode="drop"
    print "## Development Workflow"
    print ""
    print "This repo uses the AgenticApps spec-first workflow on the opencode host."
    print "On any code-touching task the `agentic-apps-workflow` trigger skill"
    print "activates, emits the canonical commitment ritual before any tool call,"
    print "and carries the gate bindings, task-size routing, plan-review, and"
    print "knowledge-capture procedures — read them there, not here."
    print "Project-specific bindings live in `.planning/config.json`; gates that do"
    print "not fire on this project are documented in `docs/ENFORCEMENT-PLAN.md`."
    print "Do not bypass a gate — accept-via-ADR is the override path. Spec:"
    print "[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)."
    print "Version stamp: `.opencode/workflow-version.txt`."
    print ""
    next
  }
  if ($0 == "## Session handoff") {
    mode="drop"
    print "## Session handoff"
    print ""
    print "Read `.opencode/session-handoff.md` at session start if newer than 7"
    print "days; write it before ending a session. Only the opencode handoff —"
    print "never another host'\''s. Full protocol in the trigger skill."
    print ""
    next
  }
  mode="pass"
}

mode=="pass" { print }
' AGENTS.md > AGENTS.md.0010.tmp && mv AGENTS.md.0010.tmp AGENTS.md
# step2:end
```
**Rollback:** `git checkout -- AGENTS.md`

### Step 3: Advance the conformance claim to 0.10.0

Unlike `0009` (which explicitly must not move the claim), this migration **is** an
adoption: it satisfies a new 0.10.0 SHOULD. The claim moves, and 0006's invariant
requires the config mirrors to move with it.

**Idempotency check:** `grep -q '^implements_spec: 0.10.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^implements_spec: 0.9.1$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0010.bak -E 's/^implements_spec: 0\.9\.1$/implements_spec: 0.10.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0010.bak
for f in .planning/config.json \
         skills/setup-opencode-agenticapps-workflow/snapshot/planning-config.json \
         skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json; do
  [ -f "$f" ] || continue
  tmp="$(mktemp)"; jq '.implements_spec = "0.10.0"' "$f" > "$tmp" && mv "$tmp" "$f"
done
```
(The **nested** `implements_spec` values inside those JSON files — `0.5.0` on the
plan-review gate, `0.4.0` on the ts-declare-first gate — are per-gate contract
versions, not the host claim. Do NOT touch them.)
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md .planning/config.json skills/setup-opencode-agenticapps-workflow/snapshot/planning-config.json skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json`

### Step 4: Record the §12 adoption in the trigger skill

**Idempotency check:** `grep -q '^## Instruction surface — eager vs lazy (spec §12)$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** none — prose.
**Apply:** add an `## Instruction surface — eager vs lazy (spec §12)` section
stating what `AGENTS.md` now carries and what moved here, and why (per-turn
re-billing; keeping §11 out of mid-context). Retitle `## Spec deltas (spec 0.9.1)`
to `(spec 0.10.0)` and re-date the audit line. Update the skill's opening prose
from `v0.9.1` to `v0.10.0`. Rewrite the §15 cross-reference that claimed the tail
"mirrors the same section in the project `AGENTS.md`" — after step 2 that is
false; it is now the only copy.
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md`

### Step 5: Note the relocation in ENFORCEMENT-PLAN.md

**Idempotency check:** `grep -q 'instruction-surface economy' docs/ENFORCEMENT-PLAN.md`
**Pre-condition:** none — prose.
**Apply:** advance the conformance claim to core v0.10.0, add §12's
instruction-surface economy to the satisfied list, and correct the document's
self-description: it is no longer "the host-side companion to `AGENTS.md`'s
Workflow Enforcement Hooks table" (that table is gone) but to the trigger skill's
Step 3 bindings.
**Rollback:** `git checkout -- docs/ENFORCEMENT-PLAN.md`

### Step 6: Rebuild the snapshot and the installer template

The snapshot is a build artifact of the end state (ADR-0007); §08 conformance
depends on it matching. `--rebuild` regenerates `snapshot/`, but it does **not**
cover `templates/agents-md-additions.md`, which must be rebuilt by hand as the
snapshot plus the marker pair.

**Idempotency check:** `bash migrations/check-snapshot-parity.sh` exits 0.
**Pre-condition:** steps 2–3 applied.
**Apply:**
```bash
# step6:begin
bash migrations/check-snapshot-parity.sh --rebuild
SNAP="skills/setup-opencode-agenticapps-workflow/snapshot/agents-block.md"
TPL="skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md"
{ printf '%s\n' '<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->'
  cat "$SNAP"
  printf '%s\n' '<!-- END: agentic-apps-workflow sections -->'
} > "$TPL.0010.tmp" && mv "$TPL.0010.tmp" "$TPL"
bash migrations/check-snapshot-parity.sh
# step6:end
```
**Rollback:** `git checkout -- skills/setup-opencode-agenticapps-workflow/`

### Step 7: Bump the scaffolder version

**Idempotency check:** `grep -q '^version: 0.6.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.5.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0010.bak -E 's/^version: 0\.5\.0$/version: 0.6.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0010.bak
```
**Rollback:** `sed -i.bak -E 's/^version: 0\.6\.0$/version: 0.5.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 8: Record the new project version

**Idempotency check:** `grep -q '^0.6.0$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.6.0" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.5.0" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. §11 survives byte-identical to the mirror (the load-bearing assertion).
awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' AGENTS.md \
  | diff -q - skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md

# 2. Exactly one provenance anchor (0009 post-check 4 still holds).
[ "$(grep -c 'spec-source: agenticapps-workflow-core' AGENTS.md)" -eq 1 ]

# 3. The relocated blocks are gone from the eager file.
! grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' AGENTS.md
! grep -q '^## Skill routing$' AGENTS.md
! grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' AGENTS.md

# 4. ...and the pointers are present.
grep -q 'Full protocol in the trigger skill' AGENTS.md
grep -q 'agentic-apps-workflow` trigger skill' AGENTS.md

# 5. The §11 block is still followed by a '## ' line (0001's bound).
awk '/session-level discipline the model brings to every diff\.$/{getline; getline; print; exit}' AGENTS.md | grep -q '^## '

# 6. The relocated procedures actually exist in the trigger skill.
grep -q '^## Session handoff$' skills/agentic-apps-workflow/SKILL.md
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' skills/agentic-apps-workflow/SKILL.md
grep -q '^## Step 3 — Gate-to-skill bindings' skills/agentic-apps-workflow/SKILL.md

# 7. Claim advanced and mirrored (0006 invariant).
grep -q '^implements_spec: 0.10.0$' skills/agentic-apps-workflow/SKILL.md
jq -e '.implements_spec == "0.10.0"' .planning/config.json >/dev/null

# 8. Snapshot equals the end state.
bash migrations/check-snapshot-parity.sh
```

### REQUIRED operator check

The eager surface is a judgment call, not just a line count. Read the resulting
`AGENTS.md` end to end and confirm a session that loads **only** that file still
knows: (a) the four §11 rules, (b) that a trigger skill exists and carries the
gates, and (c) where the handoff lives. If any of those three is not obvious from
the file alone, the slimming went too far.

## Skip cases

- **`.opencode/workflow-version.txt` already reads `0.6.0`** — fully applied; skip.
- **`AGENTS.md` contains `Full protocol in the trigger skill`** — step 2 already
  applied; the remaining steps are individually idempotent and safe to re-run.
- **No marker pair in `AGENTS.md`** — the project was never set up by this
  scaffolder. Pre-flight aborts; run setup instead of this migration.
- **A project that deliberately keeps the gate table eager.** §12's convention is
  **SHOULD**, not MUST: a heavy eager file is below the bar but not
  non-conformant. Such a project may skip step 2 and still claim 0.10.0, provided
  it records the choice. Steps 1 and 3–8 remain applicable.

## Compatibility

- **opencode runtime:** unaffected. Skill discovery is by frontmatter
  `description`, which is unchanged; only the skill body grew.
- **Downgrade:** every step has a `git checkout`-shaped rollback. Reverting step 2
  alone restores the heavy file without touching the claim; revert step 3 too if
  the claim must return to 0.9.1.
- **Consuming projects on 0.5.0** pick this up via
  `/update-opencode-agenticapps-workflow`. Projects that hand-edited the managed
  block keep their edits for any section this migration does not name.

## Notes

- Three of the four relocated blocks were already duplicated in the trigger
  skill, so the eager copies were pure redundancy. The §15 tail in particular was
  *already* obliged to live in `SKILL.md` by core §15 — its `AGENTS.md` copy had
  been off-pattern since it was introduced in `0005`.
- `run-tests.sh`'s 0005 test extracted the §15 section from
  `templates/agents-md-additions.md`. With that section relocated, the test now
  sources it from `skills/agentic-apps-workflow/SKILL.md`; 0005's contract (the
  section is installable, carries the `(opencode)` host tag, lands inside a
  marker block) is unchanged.
- The pre-existing orphan table header in the old `AGENTS.md` (a duplicated
  `| Gate | Bound skill | Applies to scaffolder? |` header with no rows, above
  the real table) is removed as a side effect — it was inside the enforcement
  section this migration drops.

## References

- Core spec §12, "Instruction-surface economy (eager vs lazy)" (v0.10.0).
- Core [ADR-0020](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0020-instruction-surface-economy.md) — eager file = §11 + pointer.
- Core spec §15 — already required the ritual tail to live in the host's SKILL.md.
- [ADR-0007](../docs/decisions/0007-snapshot-install.md) — snapshot install + parity guard.
- Migration [`0009`](0009-spec-11-region-aware-placement.md) — the §11 strip/inject rules this migration works within.

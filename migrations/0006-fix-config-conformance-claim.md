---
id: 0006
slug: fix-config-conformance-claim
title: Correct the config conformance claim + restore the §13 binding (v0.3.0 -> 0.3.1)
from_version: 0.3.0
to_version: 0.3.1
applies_to:
  - .planning/config.json                      # implements_spec 0.1.0 -> 0.4.0; restore §13 strengthened_by
  - skills/agentic-apps-workflow/SKILL.md       # scaffolder version bump 0.3.0 -> 0.3.1
  - .opencode/workflow-version.txt              # record new project version
requires: []
optional_for: []
---

# Migration 0006 — Config conformance claim + §13 binding (v0.3.0 -> 0.3.1)

Repairs two defects in `.planning/config.json` that have been present since the
fork from `codex-workflow` (`50b5d76`) and were never correct in this repo:

1. **`implements_spec` was left at `0.1.0`.** Migration `0001` is the declared
   sole bumper of the conformance claim, but it bumps only the trigger skill's
   frontmatter (`skills/agentic-apps-workflow/SKILL.md`) — it never touched the
   config. So every shipped artifact cites `0.4.0` while the config it seeds
   still claims `0.1.0`.
2. **The §13 `strengthened_by` binding was missing.** Migration `0002` binds
   `opencode-ts-declare-first` to the `tdd` gate, and
   `templates/config-hooks.json` carries that block — but the repo's own config
   (and therefore `snapshot/planning-config.json`, which is rebuilt from it)
   never had it.

**Why this reached users.** opencode ships a snapshot, not a migration replay
(ADR-0007). Setup Stage C step 8 copies `$SNAP/planning-config.json` and
describes it as "the **latest** hook config (all migrations already folded in)".
That claim was false: the snapshot was missing `0002`'s binding and carried
`0000`'s pre-bump `implements_spec`. Every project scaffolded by
`$setup-opencode-agenticapps-workflow` inherited both defects.

**Why the parity guard did not catch it.** `check-snapshot-parity.sh` compares
`snapshot/planning-config.json` against the repo's live `.planning/config.json`.
Both carried the identical defect, so the two agreed and the check passed. The
guard verifies snapshot-vs-repo, not snapshot-vs-replay; the divergence is only
visible against `templates/config-hooks.json`, which the migration path (`0000`
Step 2) copies and which has been correct all along.

**The two fields move together.** A config claiming `implements_spec: 0.4.0`
while missing the §13 binding that 0.4.0 requires is a *false* conformance
claim — worse than an honestly stale `0.1.0`. Steps 1 and 2 apply both or
neither; never land one without the other.

**Why a patch bump:** no behavior is added. The gate stack, the ritual surfaces,
and the spec claim of the shipped skills are all unchanged — this migration only
makes the config say what the scaffolder has claimed since `0001`. Every live
project is at `0.3.0` after `0005`, so `0.3.0 -> 0.3.1` is the shape that
reaches the fleet via `$update-opencode-agenticapps-workflow`.

**`implements_spec` stays `0.4.0`, not `0.7.0`.** Core spec is at 0.7.0, but
§05's `plan-review` gate (0.5.0) and §14 prompt-injection (0.6.0) are not wired
on this host, and the sibling hosts (`claude-workflow`, `codex-workflow`) both
also cite `0.4.0`. Moving the claim to 0.7.0 is a fleet-wide absorption, out of
scope here.

**Supported upgrade floor:** `0.3.0 -> 0.3.1`. Projects below 0.3.0 replay the
chain through `0005` first.

## Pre-flight

```bash
# jq is required for both config edits
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }

# Config must exist and be valid JSON with the tdd gate present
test -f .planning/config.json || { echo ".planning/config.json missing — run 0000 first"; exit 1; }
jq -e '.hooks.per_task.tdd' .planning/config.json >/dev/null || { echo ".hooks.per_task.tdd absent"; exit 1; }
```

## Steps

### Step 1: Correct the conformance claim in .planning/config.json

**Idempotency check:** `jq -e '.implements_spec == "0.4.0"' .planning/config.json >/dev/null`
**Pre-condition:** `jq -e '.implements_spec == "0.1.0"' .planning/config.json >/dev/null` (abort if some other value — never overwrite a claim this migration did not predict)
**Apply:**
```bash
tmp="$(mktemp)"
jq '.implements_spec = "0.4.0"' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq '.implements_spec = "0.1.0"' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```

### Step 2: Restore the §13 strengthened_by binding on the tdd gate

The block is byte-identical to the one `0002` Step 1 writes and to the one
`templates/config-hooks.json` already carries — this migration only replays it
onto configs that never received it.

**Idempotency check:** `jq -e '.hooks.per_task.tdd.strengthened_by.skill == "opencode-ts-declare-first"' .planning/config.json >/dev/null`
**Pre-condition:** `.planning/config.json` is valid JSON with a `.hooks.per_task.tdd` object
**Apply:**
```bash
tmp="$(mktemp)"
jq '.hooks.per_task.tdd.strengthened_by = {
  "skill": "opencode-ts-declare-first",
  "implements_spec": "0.4.0",
  "fires_when": "task introduces a new TypeScript module'\''s public API surface in a TS-primary project",
  "commit_sequence": ["declare(ts):", "test(ts):", "feat(ts):"]
}' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq 'del(.hooks.per_task.tdd.strengthened_by)' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```

### Step 3: Bump the scaffolder version (implements_spec of the SKILL unchanged)

**Idempotency check:** `grep -q '^version: 0.3.1$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.3.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0006.bak -E 's/^version: 0\.3\.0$/version: 0.3.1/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0006.bak
```
(The SKILL's `implements_spec: 0.4.0` is unchanged — do NOT touch it. This
migration moves the *config* up to the claim the SKILL has cited since `0001`.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.3\.1$/version: 0.3.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.3.1$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.3.1" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.3.0" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. Claim corrected (ALWAYS true on success)
jq -e '.implements_spec == "0.4.0"' .planning/config.json >/dev/null

# 2. §13 binding present, base tdd binding not clobbered (ALWAYS true on success)
jq -e '.hooks.per_task.tdd.strengthened_by.skill == "opencode-ts-declare-first"' .planning/config.json >/dev/null
jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' .planning/config.json >/dev/null

# 3. Claim and binding agree — the invariant this migration exists to restore
jq -e '(.implements_spec == "0.4.0") and (.hooks.per_task.tdd.strengthened_by != null)' .planning/config.json >/dev/null

# 4. Version bumped to 0.3.1 (ALWAYS true on success)
grep -q '^version: 0.3.1$' skills/agentic-apps-workflow/SKILL.md
grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md   # unchanged
grep -q '^0.3.1$' .opencode/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.3.1) == latest migration `to_version` (0.3.1)
- Snapshot parity green: `snapshot/planning-config.json` == this repo's
  `.planning/config.json` modulo `knowledge_capture`, rebuilt via
  `check-snapshot-parity.sh rebuild`

## Skip cases

- **`from_version` mismatch** (project not at 0.3.0) → migration framework skips
  silently. Projects below 0.3.0 replay the chain first.
- **Config seeded from `templates/config-hooks.json`** (the `0000` migration
  path rather than the snapshot path) → both Step 1 and Step 2 idempotency
  checks are already positive; both no-op and Steps 3–4 still run.
- **`implements_spec` at some value other than `0.1.0`/`0.4.0`** → Step 1's
  pre-condition aborts. A hand-edited claim is a human decision; this migration
  does not overwrite it.

## Compatibility

- **Patch bump** to `0.3.1`: no gate is added, removed, or rebound. Step 1
  rewrites one scalar; Step 2 adds one key under an existing gate. Both are
  additive to every other config key.
- **Base `tdd` binding preserved.** Step 2 sets only `.strengthened_by`, leaving
  `.hooks.per_task.tdd.skill` (`superpowers:test-driven-development`, per the
  `57df04d` upstream rebind) untouched.
- **Drift coupling:** as the highest-numbered migration, `0006`'s `to_version`
  (0.3.1) is the drift target; `skills/agentic-apps-workflow/SKILL.md` is bumped
  to 0.3.1 in lockstep (`run-tests.sh` `test_drift`).
- **Snapshot parity (ADR-0007):** `snapshot/planning-config.json` is rebuilt from
  the corrected config, so fresh installs get the fix by construction and
  existing installs get it via this migration.

## Known adjacent defect (not fixed here)

`0002`'s post-check asserts `.hooks.per_task.tdd.skill == "opencode-tdd"`, but
that skill was removed by the `57df04d` upstream rebind. A fresh replay of the
chain would fail that check. Out of scope for this patch — tracked separately.

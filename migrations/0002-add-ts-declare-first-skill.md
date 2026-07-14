---
id: 0002
slug: add-ts-declare-first-skill
title: Add opencode-ts-declare-first skill (spec §13) + bind to the tdd gate
from_version: 0.2.0
to_version: 0.2.0
applies_to:
  - .planning/config.json
requires:
  - skill: opencode-ts-declare-first
    install: |
      Re-run opencode-workflow install.sh from the scaffolder root:
      bash install.sh   (symlinks skills/opencode-ts-declare-first/ into
                         ${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/)
    verify: "test -f \"${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/opencode-ts-declare-first/SKILL.md\""
optional_for: []
---

# Migration 0002 — Add opencode-ts-declare-first skill (spec §13)

`agenticapps-workflow-core` 0.4.0 adds **§13 — declare-first TypeScript
discipline**, a SHOULD-level declarative contract that names
`opencode-workflow` explicitly as a TS-targeting host expected to ship the
skill (core CHANGELOG 0.4.0 entry).

This migration is **additive** — it rides on the `to_version: 0.2.0`
established by migration `0001` and does **not** move the version or the
`implements_spec` claim (§11 is what earned 0.4.0; §13 is absorbed under
the same scaffolder minor). The drift test stays green because `0002` is
the latest migration by filename sort and its `to_version` (0.2.0)
matches the trigger SKILL.md `version` (0.2.0).

On the opencode host, skills are discovered globally from
`${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/` after `install.sh`, so — unlike
claude-workflow's `0015`, which creates a per-project slash-discovery
symlink — this migration does **not** symlink anything per project. Its
only per-project effect is to wire the skill into the project's
`.planning/config.json` as a strengthener of the `tdd` gate, so the
project's planners/executors route new-TS-module tasks through it.

The skill itself (`skills/opencode-ts-declare-first/`) and its three
template files ship in the scaffolder and are installed globally by
`install.sh` (which globs `skills/*/`). The trigger skill's Step 3 gate
table and `templates/config-hooks.json` already carry the binding; this
migration applies the same binding to an already-installed project.

## Pre-flight

```bash
# Project root must be a git repo
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# Project must already be at >= 0.2.0 (migration 0001 applied)
test -f .planning/config.json || { echo ".planning/config.json missing — run migration 0000/0001 first"; exit 1; }

# The §13 skill must be installed globally (scaffolder install.sh)
SKILL="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/opencode-ts-declare-first/SKILL.md"
test -f "$SKILL" || { echo "opencode-ts-declare-first not installed at $SKILL — re-run opencode-workflow install.sh"; exit 1; }

# jq is required for the config edit
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }
```

## Steps

### Step 1: Bind opencode-ts-declare-first to the tdd gate in .planning/config.json

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

## Post-checks

- `jq -e '.hooks.per_task.tdd.strengthened_by.skill == "opencode-ts-declare-first"' .planning/config.json` — binding present
- `jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' .planning/config.json` — base tdd binding intact (not clobbered)
- `test -f "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/opencode-ts-declare-first/SKILL.md"` — skill installed
- Drift test green: trigger SKILL.md `version` (0.2.0) == latest migration `to_version` (0.2.0)

> **Base binding value.** This post-check named `opencode-tdd` until v0.3.1.
> That skill was removed by the `57df04d` upstream rebind (gates now bind
> `superpowers:*` rather than re-ported `opencode-*` copies), which rewrote
> `templates/config-hooks.json` in place **without** shipping a migration. So
> `0000` Step 2 seeds `superpowers:test-driven-development`, and this check —
> still asserting the deleted `opencode-tdd` — failed on any fresh replay of the
> chain. Corrected in `0006`. Only the *base* binding moved; the strengthener
> above is still the host-authored `opencode-ts-declare-first`, which exists.

## Skip cases

- **Already bound** (idempotency check passes) — Step 1 no-ops.
- **Project below 0.2.0** — pre-flight aborts; apply migration 0001 first.
- **Skill not installed** — pre-flight aborts with the install pointer; re-run
  the scaffolder `install.sh`.
- **Non-TS project** — the binding is harmless (it only fires for new TS
  modules in TS-primary projects); it is still recorded so the project's
  contract is complete if TS is added later.

## Notes

Testable non-interactively via `test_migration_0002` in
`migrations/run-tests.sh` (idempotency check + jq apply/rollback on a
synthetic config fixture). The skill's templates ship as three SEPARATE
files (`example.declare.ts` / `example.test.ts` / `example.impl.ts`) so
the three-commit shape is structurally enforced on copy.

Per migration immutability, the chain stays contiguous (`0000` → `0001`
→ `0002`). The §10 delegation ships as `0003`.

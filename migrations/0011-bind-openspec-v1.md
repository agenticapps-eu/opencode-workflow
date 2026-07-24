---
id: 0011
slug: bind-openspec-v1
title: Bind the OpenSpec + Superpowers front end, retire the GSD engine (v0.6.0 -> 1.0.0)
from_version: 0.6.0
to_version: 1.0.0
applies_to:
  - .planning/config.json                                   # GSD hooks -> OpenSpec lifecycle; claim 0.10.0 -> 1.0.0
  - skills/agentic-apps-workflow/SKILL.md                   # Step 1/2/3 + verification retargeted; version 1.0.0
  - skills/opencode-spec-review/                            # DELETED — spec-review collapses into `openspec validate`
  - skills/opencode-openspec-change-review/                 # NEW — multi-AI review producer (writes REVIEWS.md)
  - skills/opencode-*/SKILL.md                              # gate skills implements_spec 0.4.0 -> 1.0.0
  - opencode.json                                           # drop mcp.gitnexus
  - AGENTS.md                                               # Development Workflow -> OpenSpec loop; drop Code Intelligence
  - CLAUDE.md                                               # gitnexus reindex note -> pointer to AGENTS.md
  - bin/openspec-change-gate.sh                             # NEW — §18 host-agnostic gate (real enforcement surface)
  - bin/openspec-change-gate.ts                             # NEW — opencode tool.execute.before plugin wiring
  - bin/reviewer-cli.sh                                     # NEW — reviewer-CLI wrapper (</dev/null + timeout)
  - bin/git-hooks/pre-commit                                # NEW — agent-agnostic enforcement floor
  - docs/WORKFLOW.md                                        # NEW — opencode workflow explainer
  - docs/decisions/0010-openspec-superpowers-adoption.md    # NEW — the adoption ADR (supersedes ADR-0009)
  - skills/setup-opencode-agenticapps-workflow/             # scaffold openspec init + gate + collapsed gates
  - skills/update-opencode-agenticapps-workflow/            # carry this migration + recipe 0001 for targets
  - .opencode/workflow-version.txt                          # record new project version
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "npm i -g @fission-ai/openspec"
  - tool: reviewer-clis
    verify: "gemini --version && codex --version"
    install: "install >=2 external-vendor reviewer CLIs the §18 gate calls"
optional_for:
  - tag: db
    detect: "test -d supabase || test -d migrations/sql || grep -rqi 'rls' ."
    note: "no DB surface -> database-security stays unbound (§17 conditional)"
  - tag: ui
    detect: "test -d frontend || test -d src/components"
    note: "no UI surface -> design gates stay unbound (§17 conditional)"
---

# Migration 0011 — Bind OpenSpec + Superpowers (v0.6.0 → 1.0.0)

This migration adopts `agenticapps-workflow-core` **spec v1.0.0**: the
OpenSpec + Superpowers front end (spec §16–§19, core ADR-0021). It
replaces the 0.x GSD phase engine as the **planning** discipline while
keeping Superpowers as the **execution** discipline unchanged. See
[ADR-0010](../docs/decisions/0010-openspec-superpowers-adoption.md).

It is the largest migration in the chain — it restructures the
gate-binding config, removes gitnexus, installs the §18 change-gate, and
retargets the instruction surface. Because so much is a wholesale
restructure rather than a field edit, the config and skill steps replace
from the shipped template/snapshot rather than patch in place; the
`knowledge_capture` block (repo-specific, §15) is preserved across the
restructure.

**Supported upgrade floor:** `0.6.0 → 1.0.0`. Projects below 0.6.0 replay
the chain through `0010` first.

## Pre-flight

```bash
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run inside a git repo"; exit 1; }
test -f .planning/config.json || { echo ".planning/config.json missing — run 0000 first"; exit 1; }
openspec --version >/dev/null 2>&1 || echo "note: install openspec (npm i -g @fission-ai/openspec) before the gate's validate branch can pass"
```

## Steps

### Step 1: Restructure `.planning/config.json` to the OpenSpec lifecycle

**Idempotency check:** `jq -e '.lifecycle.validate.change_gate' .planning/config.json >/dev/null`
**Pre-condition:** `jq -e '.hooks.pre_execution.plan_review' .planning/config.json >/dev/null` (a 0.x GSD-shaped config)
**Apply:** replace the `hooks` block (pre_execution/pre_phase/per_task/
post_phase/finishing) with the `lifecycle` block (propose/validate/
execute/archive/ship) from the shipped template, add the `front_end` and
`openspec` blocks, bump `implements_spec` to `1.0.0`, and **preserve**
`knowledge_capture`:
```bash
TPL="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/config-hooks.json"
tmp="$(mktemp)"
jq --slurpfile tpl "$TPL" \
  '$tpl[0] + (if .knowledge_capture then {knowledge_capture} else {} end)' \
  .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:** `git checkout -- .planning/config.json`

### Step 2: Remove gitnexus from live surfaces

**Idempotency check:** `! jq -e '.mcp.gitnexus' opencode.json >/dev/null 2>&1 && ! test -d .claude/skills/gitnexus`
**Pre-condition:** none (fixes forward; a repo with no gitnexus no-ops)
**Apply:** drop `mcp.gitnexus` from `opencode.json`; delete
`.claude/skills/gitnexus/` and the untracked `.gitnexus/` data dir;
remove the `## Code Intelligence` section (+ `gitnexus:skip` note) from
`AGENTS.md`; replace the gitnexus `## Reindexing` note in `CLAUDE.md`
with a pointer to `AGENTS.md`. Historical records (migration 0009,
ADR-0009, CHANGELOG, the region-placement design doc) are retained per
§08 supersede-don't-delete.
**Rollback:** `git checkout -- opencode.json AGENTS.md CLAUDE.md && git checkout -- .claude/skills/gitnexus 2>/dev/null; true`

### Step 3: Install the §18 change-gate and initialize the spec slot

**Idempotency check:** `test -x "$HOME/.agenticapps/bin/openspec-change-gate.sh" && test -d openspec/changes`
**Pre-condition:** `openspec --version >/dev/null 2>&1` (else skip the init with a note; install the CLI first)
**Apply:**
```bash
mkdir -p "$HOME/.agenticapps/bin"
install -m 0755 bin/openspec-change-gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
install -m 0755 bin/reviewer-cli.sh         "$HOME/.agenticapps/bin/reviewer-cli.sh"
mkdir -p "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/plugin"
install -m 0644 bin/openspec-change-gate.ts "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/plugin/openspec-change-gate.ts"
install -m 0755 bin/git-hooks/pre-commit "$(git rev-parse --git-path hooks)/pre-commit"
openspec init --tools opencode --profile core --force   # generates .opencode opsx commands + openspec/ slot
```
**Rollback:** remove the installed script/plugin/pre-commit and the generated `.opencode/commands/opsx-*.md` + `openspec/` slot.

### Step 4: Retarget the instruction surface (trigger skill + AGENTS.md)

**Idempotency check:** `grep -q '^implements_spec: 1.0.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** none — prose edit, inert for installed projects
**Apply:** in the trigger skill, retarget Step 1 sizing, Step 2 routing
(the `/opsx:*` lifecycle), Step 3 gate bindings (§17 collapsed/retained/
conditional/lint), the Verification Check (change artifacts, not phases),
and the knowledge-capture triggers; keep the canonical Superpowers blocks
verbatim. In `AGENTS.md`, rewrite the `## Development Workflow` section to
the OpenSpec loop and point at `docs/WORKFLOW.md` (the §11 block and its
`@0.4.0` spec-source marker are unchanged).
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md AGENTS.md`

### Step 5: Collapse the gate skills

**Idempotency check:** `! test -d skills/opencode-spec-review && test -d skills/opencode-openspec-change-review`
**Pre-condition:** none
**Apply:** delete `skills/opencode-spec-review/` (its structural role is
now `openspec validate --all`); add `skills/opencode-openspec-change-review/`
(the multi-AI review producer). `cso`/security stays always-on;
database-sentinel/qa/design/impeccable are conditional; ts-declare-first
is demoted to a CI lint gate; impeccable + any Go skills stay behind the
ADR-0021 measured trial (MEASUREMENT.md) — not removed.
**Rollback:** `git checkout -- skills/opencode-spec-review skills/opencode-openspec-change-review`

### Step 6: Bump versions (0.6.0 → 1.0.0, implements_spec → 1.0.0)

**Idempotency check:** `grep -q '^version: 1.0.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.6.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
printf '1.0.0\n' > VERSION
printf '1.0.0\n' > .opencode/workflow-version.txt
sed -i.bak -E 's/^version: 0\.6\.0$/version: 1.0.0/; s/^implements_spec: 0\.10\.0$/implements_spec: 1.0.0/' \
  skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak
for f in skills/opencode-*/SKILL.md; do
  sed -i.bak -E 's/^implements_spec: 0\.4\.0$/implements_spec: 1.0.0/' "$f" && rm -f "$f.bak"
done
```
**Rollback:** `git checkout -- VERSION .opencode/workflow-version.txt skills/agentic-apps-workflow/SKILL.md skills/opencode-*/SKILL.md`

## Post-checks

```bash
# 1. Config is on the OpenSpec lifecycle, claim bumped, no standalone plan/spec-review
jq -e '.lifecycle.validate.change_gate and .lifecycle.validate.multi_ai_review' .planning/config.json >/dev/null
jq -e '.implements_spec == "1.0.0" and .front_end == "openspec"' .planning/config.json >/dev/null
jq -e '(.hooks.pre_execution.plan_review // null) == null' .planning/config.json >/dev/null

# 2. The multi-AI review producer exists; the collapsed spec-review skill is gone
test -d skills/opencode-openspec-change-review && ! test -d skills/opencode-spec-review

# 3. gitnexus is absent from live config
! jq -e '.mcp.gitnexus' opencode.json >/dev/null 2>&1

# 4. Claim mirrored across SKILL.md, config, snapshot; version bumped
grep -q '^implements_spec: 1.0.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^version: 1.0.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^1.0.0$' .opencode/workflow-version.txt

# 5. The §18 gate blocks before review and allows after (direct invocation)
printf '{"tool":"edit","tool_input":{"file_path":"x.go"}}' | bash bin/openspec-change-gate.sh; test $? -eq 0   # no active change -> allow
```

- Drift test green: SKILL.md `version` (1.0.0) == latest migration `to_version` (1.0.0)
- Snapshot parity green: rebuilt via `check-snapshot-parity.sh --rebuild`

## Skip cases

- **`from_version` mismatch** (project not at 0.6.0) → framework skips
  silently; projects below 0.6.0 replay the chain through 0010 first.
- **Already at 1.0.0** (config has `.lifecycle.validate.change_gate`) →
  every step's idempotency check is positive; the migration no-ops.
- **openspec CLI absent** → Step 3's `openspec init` is skipped with a
  note; the gate installs but its `validate` branch blocks until the CLI
  is present (an unvalidatable change must not pass — §18).
- **No DB / UI surface** → the conditional gates stay unbound (§17).

## Compatibility

- **Minor→major:** `implements_spec` 0.10.0 → **1.0.0** (the OpenSpec
  front end is spec v1.0.0); workflow `version` 0.6.0 → **1.0.0**. This is
  a front-end replacement, the largest change since baseline.
- **Superpowers execution discipline unchanged** (§01/§03/§04/§05/§06/§11)
  — TDD, evidence, independent review, the commitment ritual, and the §11
  Coding Discipline block all carry forward verbatim.
- **plan-review reconciliation:** the multi-AI review is KEPT (§17), as the
  §18 change-gate predicate + the `opencode-openspec-change-review`
  producer — NOT a standalone gate. The 0.x `plan_review` binding is
  retired; ADR-0009 (region-aware §11 placement) is superseded (gitnexus
  gone).
- **Drift coupling:** as the highest-numbered migration, `0011`'s
  `to_version` (1.0.0) is the drift target; the trigger SKILL.md moves in
  lockstep.
- **Snapshot parity (ADR-0007):** snapshot rebuilt from the 1.0.0 end state.

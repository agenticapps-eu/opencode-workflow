---
id: 0005
slug: knowledge-capture
title: Knowledge capture into the Obsidian vault — spec §15 (v0.2.1 -> 0.3.0)
from_version: 0.2.1
to_version: 0.3.0
applies_to:
  - .planning/config.json                      # seed the host-neutral knowledge_capture block
  - AGENTS.md                                   # insert the "Knowledge Capture — Ritual Tail" section
  - skills/agentic-apps-workflow/SKILL.md       # scaffolder version bump 0.2.1 -> 0.3.0
  - .opencode/workflow-version.txt              # record new project version
requires: []
optional_for: []
---

# Migration 0005 — Knowledge capture (v0.2.1 -> 0.3.0)

Implements core spec [§15](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/15-knowledge-capture.md)
(v0.7.0, core ADR-0017) on the opencode host: distill **1–5 transferable
learnings** to **one Obsidian note per repo** as the final step of the three
rituals — session handoff, plan completion, phase completion. The wiring is
prose the agent executes (spec §15 permits any mechanism); this migration
teaches an **existing install** the config block and the AGENTS.md ritual-tail
section.

**opencode ships a snapshot, not a migration replay (ADR-0007).** Fresh installs
get the feature by construction: `snapshot/agents-block.md` already carries the
ritual-tail section, and `$setup-opencode-agenticapps-workflow` seeds the
host-neutral `knowledge_capture` block into `.planning/config.json` (Stage C,
resolving `<repo-name>` from `config-knowledge-capture.json`). This migration is
the **upgrade path** for projects already installed at v0.2.1, and — as the
highest-numbered migration — the **drift/parity anchor** that keeps the snapshot
honest (`check-snapshot-parity.sh`; the ritual-tail section it adds to AGENTS.md
must equal `snapshot/agents-block.md`).

**Config lives in the single, shared, host-neutral `.planning/config.json`.**
Unlike codex (which namespaces its *hooks* to `.planning/config.codex.json`),
opencode keeps one un-namespaced `.planning/config.json` holding `$schema`,
`implements_spec`, `host`, and `hooks`. The `knowledge_capture` block merges
into that same file (`. + {knowledge_capture}`), preserving every existing key,
and is host-neutral: a future dual-host tree (opencode + codex/claude) reads the
identical block and differs only by the `(opencode)` / `(codex)` / `(claude)`
tag in the Log heading. The block must be the **same** destination across hosts
because the vault note is one-per-repo, shared, its `hosts:` frontmatter listing
every writer.

**Why a 0.x minor bump:** the update engine applies a migration only when
`installed >= from_version AND installed < to_version`. Every live project is at
`0.2.1` after 0004, so a `0.2.1 -> 0.3.0` migration is the shape that reaches the
fleet via `$update-opencode-agenticapps-workflow`. `implements_spec: 0.4.0` is
**unchanged** — §15 wiring is real conformance either way; `implements_spec`
tracks the last full audit, unchanged here.

**Supported upgrade floor:** `0.2.1 -> 0.3.0`. Projects below 0.2.1 replay the
chain through 0004 first.

## Pre-flight

```bash
# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the config merge
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the config merge"; exit 2; }

# Workflow scaffolder is at the supported floor (0.2.1), or 0.3.0 for re-apply.
grep -qE '^version: 0\.(2\.1|3\.0)$' skills/agentic-apps-workflow/SKILL.md || {
  INSTALLED=$(grep -E '^version:' skills/agentic-apps-workflow/SKILL.md 2>/dev/null | sed 's/version: //')
  echo "ABORT: scaffolder version is $INSTALLED (need 0.2.1)."
  echo "       Apply prior migrations first via \$update-opencode-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.2.1 -> 0.3.0."
  exit 3
}

# Templates ship in the installed scaffolder (single source of truth).
OPENCODE="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
test -f "$OPENCODE/skills/setup-opencode-agenticapps-workflow/templates/config-knowledge-capture.json" || {
  echo "ABORT: config-knowledge-capture.json template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
test -f "$OPENCODE/skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md" || {
  echo "ABORT: agents-md-additions.md template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
```

## Steps

### Step 1: Seed the host-neutral `knowledge_capture` block into `.planning/config.json`

The destination is per-repo config (spec §15.2), never hardcoded in skill logic.
The `<repo-name>` placeholder is resolved to the repo directory name at
configuration time (§15.2: written out literally, never substituted at runtime).

**Idempotency check:** `test -f .planning/config.json && jq -e '.knowledge_capture' .planning/config.json >/dev/null`
(Returns 0 when the block already exists — e.g. a codex/claude co-install seeded
it; its value is preserved verbatim, this step is a no-op.)
**Pre-condition:** template present (checked in pre-flight); `jq` available.
**Apply:**
```bash
OPENCODE="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
TEMPLATE="$OPENCODE/skills/setup-opencode-agenticapps-workflow/templates/config-knowledge-capture.json"
REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
mkdir -p .planning

# Resolve <repo-name> in the template's note path, take just the block object.
KC="$(jq -c --arg name "$REPO_NAME" \
        '.knowledge_capture.note |= gsub("<repo-name>"; $name) | .knowledge_capture' \
        "$TEMPLATE")"

if [ -f .planning/config.json ]; then
  # Merge: add knowledge_capture, preserve every existing key (host, hooks, $schema).
  jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' \
     .planning/config.json > .planning/config.json.tmp \
    && mv .planning/config.json.tmp .planning/config.json
else
  # No config yet: create the shared file with only the host-neutral block.
  jq -n --argjson kc "$KC" '{knowledge_capture: $kc}' > .planning/config.json
fi
```
**Rollback:** if `.planning/config.json` existed pre-step, `jq 'del(.knowledge_capture)' .planning/config.json > tmp && mv tmp .planning/config.json`; if this step created the file, `rm -f .planning/config.json`.

### Step 2: Insert the "Knowledge Capture — Ritual Tail" section into `AGENTS.md`

The section text is **extracted from the scaffolder's `agents-md-additions.md`
template** (single source of truth) so a migrated install is byte-identical to a
fresh one (the same section ships in `snapshot/agents-block.md`) and the prose
cannot drift. It is inserted inside the existing `agentic-apps-workflow` marker
block, immediately before the closing marker.

**Idempotency check:** `grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md`
(Returns 0 when the section is already present — a fresh/snapshot install got it
from `agents-block.md`; this step is then a no-op.)
**Pre-condition:** `AGENTS.md` carries the closing marker
`grep -q '<!-- END: agentic-apps-workflow sections -->' AGENTS.md`
**Apply:**
```bash
OPENCODE="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
TPL="$OPENCODE/skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md"

# Extract the section from the template: from its heading through the last
# non-blank line (dropping the single trailing blank the template keeps before
# its END marker; the insert below re-adds exactly one). Portable buffered awk —
# BSD/macOS awk rejects a multi-line -v assignment.
SECFILE="$(mktemp)"
awk '
  /^## Knowledge Capture — Ritual Tail \(spec §15\)/ {f=1}
  /^<!-- END: agentic-apps-workflow sections -->/    {f=0}
  f {buf[n++]=$0}
  END { last=n-1; while (last>=0 && buf[last]=="") last--; for(i=0;i<=last;i++) print buf[i] }
' "$TPL" > "$SECFILE"

# Insert the section (+ one trailing blank line) before the project's END marker.
# getline-from-file is portable (BSD/macOS awk rejects a multi-line -v assignment).
awk -v secfile="$SECFILE" '
  /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
    while ((getline line < secfile) > 0) print line
    close(secfile)
    print ""
    ins=1
  }
  { print }
' AGENTS.md > AGENTS.md.0005.tmp && mv AGENTS.md.0005.tmp AGENTS.md
rm -f "$SECFILE"
```
**Rollback:** `git checkout -- AGENTS.md`. Manual anchor: delete from the line
`## Knowledge Capture — Ritual Tail (spec §15)` through the blank line before
`<!-- END: agentic-apps-workflow sections -->`.

### Step 3: Bump the scaffolder version (implements_spec unchanged)

**Idempotency check:** `grep -q '^version: 0.3.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.2.1$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0005.bak -E 's/^version: 0\.2\.1$/version: 0.3.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0005.bak
```
(`implements_spec: 0.4.0` is unchanged — do NOT touch it. §15 wiring is real
conformance either way; `implements_spec` tracks the last full audit.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.3\.0$/version: 0.2.1/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.3.0$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.3.0" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.2.1" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. Config block present, host-neutral, placeholder resolved (ALWAYS true on success)
jq -e '.knowledge_capture.enabled | type == "boolean"' .planning/config.json >/dev/null
! grep -qF '<repo-name>' .planning/config.json

# 2. Ritual-tail section wired into AGENTS.md (ALWAYS true on success)
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md

# 3. Version bumped to 0.3.0 (ALWAYS true on success)
grep -q '^version: 0.3.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md   # unchanged
grep -q '^0.3.0$' .opencode/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.3.0) == latest migration `to_version` (0.3.0)
- Snapshot parity green: the AGENTS.md ritual-tail section == `snapshot/agents-block.md`

## Skip cases

- **`from_version` mismatch** (project not at 0.2.1) → migration framework skips
  silently. Projects below 0.2.1 replay the chain first.
- **Block already present** (a codex/claude co-install seeded `.planning/config.json`)
  → Step 1 idempotency is positive; the existing block is preserved verbatim and
  Steps 2–4 still run.
- **Section already present** (snapshot/fresh install got it from the template)
  → Step 2 is a no-op; Steps 1, 3, 4 still run.
- **No vault on this machine** → not this migration's concern: the block is
  seeded regardless; the *skill's* graceful skip (spec §15.3) handles an absent
  vault folder at trigger time, never here.

## Compatibility

- **Additive (minor) bump** to `0.3.0`: no breaking change. Step 1 only adds a
  key (existing config keys preserved); Step 2 only inserts a section inside the
  existing marker block.
- **Host-neutrality:** the `knowledge_capture` block carries no host-specific
  keys, so opencode + codex/claude read the identical block from the shared
  `.planning/config.json` without collision.
- **Drift coupling:** as the highest-numbered migration file, 0005's
  `to_version` (0.3.0) is the drift target; `skills/agentic-apps-workflow/SKILL.md`
  is bumped to 0.3.0 in lockstep (`run-tests.sh` `test_drift`).
- **Snapshot parity (ADR-0007):** the ritual-tail section this migration inserts
  into `AGENTS.md` is byte-identical to `snapshot/agents-block.md`, so
  `check-snapshot-parity.sh` stays green. The host-neutral, repo-specific
  `knowledge_capture` block is excluded from the verbatim config parity (its
  `note` path carries the resolved repo name; see the guard).
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → … → `0004` → `0005`).

## Notes

- **Testable** non-interactively via `test_migration_0005` in
  `migrations/run-tests.sh`: it asserts the config merge resolves `<repo-name>`
  and preserves a pre-existing (codex) key, the AGENTS.md section insert +
  idempotent re-apply, and the version-bump round-trip.
- **Mirrors** codex-workflow's `0007-knowledge-capture` and claude-workflow's
  reference implementation (ADR-0038) in opencode's own idiom, per core
  ADR-0017's downstream-hosts note. Unlike codex, opencode ships a snapshot, so
  the fresh-install path is snapshot-driven and this migration doubles as the
  parity anchor.

## References

- Core spec: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0)
- Core ADR: `agenticapps-workflow-core/adrs/0017-knowledge-capture-obsidian.md`
- This repo's ADR: `docs/decisions/0008-knowledge-capture.md`
- Snapshot install: `docs/decisions/0007-snapshot-install.md`
- Vault schema: `~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/CLAUDE.md`
- Sibling precedent: codex-workflow `migrations/0007-knowledge-capture.md`

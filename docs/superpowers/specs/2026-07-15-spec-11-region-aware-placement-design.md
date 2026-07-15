# Migration 0009 — region-aware §11 placement

**Date:** 2026-07-15
**Status:** Approved (brainstorming → design approved 2026-07-15)
**Scope:** `migrations/0009-*`, `skills/setup-opencode-agenticapps-workflow/SKILL.md` step 9,
`migrations/run-tests.sh`, CHANGELOG, ADR-0009
**Lineage:** propagation of `claude-workflow`'s migration 0029
(`docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md`),
following the downstream-hosts mirroring pattern that `claude-workflow`'s
[ADR-0037](https://github.com/agenticapps-eu/claude-workflow/blob/main/docs/decisions/0037-commit-phase-artifacts.md)
documents — a decision taken in `claude-workflow` and mirrored by `codex-workflow`
and `opencode-workflow`, each host re-deriving its own facts rather than copying
the original's conclusions. See "Divergences" below for where this host's facts
differ.

## Problem

The §11 injector anchors the canonical "Coding Discipline" block immediately
before the first `## ` heading in `AGENTS.md`. That placement was deliberate: it
guarantees the block is followed by a `## ` line, which is what the replace and
rollback logic depends on to bound the managed section.

It is only a safe boundary if that heading belongs to project content. In an
`AGENTS.md` that leads with a GitNexus block, the first `## ` is `## Always Do` —
inside `<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The block is injected
into the region, and the next `gitnexus analyze` regenerates that region and
destroys the block silently.

Reproduced against a modelled region-led file: the naive anchor placed §11 at L6
of a region spanning L3–L90.

### Recovery is closed

`update` marks a migration pending iff `installed >= from_version && installed <
to_version`. 0001's and 0004's `to_version` are long past, so they never replay.
Their pre-flight version gates also abort the `--migration NNNN` force path. Once
the block is eaten it is unrecoverable without a hand-paste.

0001 and 0004 are immutable — this fixes forward.

### Sites carrying the naive anchor

| Site | Nature |
|---|---|
| `migrations/0001-inject-spec-11-coding-discipline.md:91` | immutable, applied |
| `migrations/0004-revendor-spec-11.md:77` | immutable, applied |
| `migrations/run-tests.sh:119` | **an inlined copy** in the test suite |

The third site was not in the propagation brief. It is a fixture that inlines a
copy of the awk rather than extracting it from the migration, so it tests the
copy and the two can drift silently.

### Fleet scan (2026-07-15)

| File | §11 | Region | State |
|---|---|---|---|
| `opencode-workflow/AGENTS.md` | L17 | L240 | healthy — above region |
| `codex-workflow/AGENTS.md` | L17 | L271 | healthy — above region |
| `workflow-testbed/AGENTS.md` | L5 | none | healthy |
| `workflow-testbed-codex/AGENTS.md` | L5 | none | healthy |
| `bench-opencode/AGENTS.md` | L5 | none | healthy |
| `bench-codex/AGENTS.md` | L5 | none | healthy |

**The defect is LATENT here, not live.** 0/6 files are hit, because each has
project `## ` headings above its region. Unlike `claude-workflow` — which had a
live broken repo (`agenticapps-dashboard`, missing §11 entirely) — there is no
repo to repair. This is a placement fix for projects scaffolded going forward,
plus self-protection.

## Design

### The anchor rule

> Insert immediately before the first line that is **either** a `## ` heading
> **or** a `<!-- gitnexus:start -->` marker — whichever comes first. If neither
> exists, append at EOF.

A one-alternation delta to 0001's awk, so 0001's structural reasoning survives:
the block is still always followed by a `## ` line or EOF, which is what bounds
the managed section for replace and rollback.

**Validated empirically before the migration was written.** With any existing
block stripped, the rule re-derives the block's current position exactly in all
six real fleet files — a true no-op, zero churn. On a modelled gitnexus-led file
it anchors at L3, above the region at L84, where the naive anchor put it at L6
*inside* the region. On a file with no `## ` and no region it falls to EOF.

#### Alternatives rejected

- **"Before `gitnexus:start` if a region exists, else the first `## `."** The
  obvious reading of "put it above the region", and wrong. Tested against the
  real `codex-workflow/AGENTS.md`, whose region starts at L271: §11 would move
  from L17 to **L190**, violating §12's placement advisory ("near the top", "not
  below long appendices"). The region is only the anchor when it comes *first* —
  which is what `whichever comes first` encodes. Confirmed by measurement, not
  by inheriting the brief's warning.
- **"Always immediately after the H1."** Simpler to state, but moves the block in
  every healthy file for no benefit, and breaks the followed-by-`## ` invariant.

### States healed

| State | Condition | Behaviour |
|---|---|---|
| A | §11 present, correctly anchored | no-op |
| B | §11 present, inside a region | move above the region |
| C | §11 absent | inject at the anchor |
| D | `## Coding Discipline (NON-NEGOTIABLE)` heading, no provenance comment | refuse, `exit 3` |

State D inherits 0001's conflict rule verbatim: a heading without provenance
means the block was hand-pasted outside the migration's management, and is
refused rather than silently overwritten.

State B is handled rather than deferred because it is reachable *going forward*,
even though no repo is in it today.

Explicitly **not** handled: a healthy block that sits somewhere other than the
canonical anchor. No failure mode motivates moving it, and doing so would churn
project files gratuitously (Surgical Changes).

Idempotency is provenance-based, as in 0001, with an added region predicate: skip
iff the current-version provenance is present **and** the block is not inside a
region. That keeps state A a no-op while letting state B re-run.

### The setup path — safe by construction, with one residual

This host's setup path is **structurally unlike `claude-workflow`'s**, and the
difference is load-bearing.

`claude-workflow`'s `setup/SKILL.md` step e2 carries the same naive first-`## `
anchor awk as its migration, which is why its design mandates an `anchor-parity`
guard extracting the awk from both files.

This host's setup step 9 has **no anchor awk at all**. §11 is pre-baked at the
*top* of `snapshot/agents-block.md` (lines 2–3), and setup inserts that whole
marker-delimited block. Wherever the marker pair lands, §11 is at its head. The
first-`## `-anchor defect therefore cannot occur via setup.

**Consequence: no `anchor-parity` guard is built.** There is no second copy of
the anchor awk to drift against. Building the reference design's guard here would
be cargo-culting a control with nothing to control. §08 parity for the block's
*content* is already covered by `check-snapshot-parity.sh`, which diffs
`agents-block.md` against the repo's own extracted block.

**The residual.** Step 9's prose reads "insert (at top, after any existing
title)". On a region-led `AGENTS.md` the first title is GitNexus's own
`# GitNexus — Code Intelligence` H1 *inside* the region — so the prose admits an
insertion into the region. Same defect class, different mechanism. Step 2 tightens
the prose to place the block above any gitnexus region. This is prose-only: it
adds no awk to setup and keeps setup's simple marker-insertion nature.

Rejected: giving setup a real region-aware anchor awk mirroring the migration,
then building the parity guard for real. Structurally strongest, but converts a
simple marker insertion into anchor machinery it never had — a large blast radius
for a latent defect.

### Mechanics

- `from_version: 0.4.1`, `to_version: 0.5.0`; pre-flight gate
  `^version: 0\.(4\.1|5\.0)$`, accepting both.
- Step 1 heals placement; Step 2 hardens setup's prose; Step 3 bumps the
  installed scaffolder version and `.opencode/workflow-version.txt`.
- The canonical block is read from
  `${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`,
  as 0001 does. The mirror stays at `@0.4.0` — that is the block's *content*
  version, unchanged since; it is not the spec version (0.9.1).
- `implements_spec` is **not** touched. It appears in many files here with no
  single authoritative one; resolving that is separate work, and the resolution
  should declare which occurrence is normative rather than reconciling every
  discovered copy — the same stance `agenticapps-workflow-core`'s ADR-0019 takes
  for drift-report scoping ("checks a declared prose set, not the whole clone").
  This migration is scoped strictly to §11 placement.
- 0001 and 0004 are **not** edited.

### Testing

A fence extractor pulls the migration's own awk out of the 0009 document, so a
fixture tests the migration and not a stale duplicate. It carries a shape
assertion that fails loudly if it locks onto the wrong fence. The existing
inlined copy at `run-tests.sh:119` is repointed at the extractor, retiring the
drift trap.

| Fixture | Asserts |
|---|---|
| `01-gitnexus-led-inject` | state C on a region-led file → block above the region; survives a modelled region regeneration |
| `02-inside-region-move` | state B → block moved above the region, present exactly once |
| `03-healthy-noop` | state A → `AGENTS.md` byte-identical; proves zero churn |
| `04-no-agentsmd` | absent `AGENTS.md` → informational skip, later steps still run |
| `05-unmanaged-conflict` | state D → `exit 3`, file untouched |
| `06-no-heading-eof` | no `## `, no region → EOF append |

Plus a self-conformance guard: this repo's own §11 sits above its own gitnexus
region. The existing `check-snapshot-parity.sh` must stay green.

Verification evidence: a `test(RED)` commit with fixtures failing against the
naive anchor, then `feat(GREEN)`; `run-tests.sh` PASS ≥ 84 (current baseline on
merged main: 84 PASS / 0 FAIL / 1 SKIP).

## Divergences from the reference design

Recorded because the propagation brief asked for this host's facts to be
determined rather than inherited:

1. **No live breakage.** `claude-workflow` had `agenticapps-dashboard` missing
   §11 entirely (its defect 2). No opencode-scaffolded repo is in that state;
   there is no repair to perform, only prevention.
2. **No `anchor-parity` guard**, because setup carries no anchor awk. This is the
   single largest structural divergence.
3. **A third naive-anchor site** (`run-tests.sh:119`) that the brief did not
   list, addressed via the extractor.
4. **No CHANGELOG "known issues" entry to retire** — the defect was never filed
   against this host.

## Consequences

- Projects scaffolded into a gitnexus-led `AGENTS.md` no longer risk silent §11
  loss on the next `gitnexus analyze`.
- Six healthy fleet files take a version-stamp bump and no content change.
- ADR-0009 records the anchor-rule decision and both rejected alternatives.
- `codex-workflow` shares this host's `agents-block.md` shape and carries the
  same naive anchor in its own migrations; its propagation is tracked separately,
  not in this migration.

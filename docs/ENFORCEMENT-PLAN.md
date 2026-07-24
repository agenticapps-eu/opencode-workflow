# Enforcement Plan — opencode-workflow

> **Updated for spec v1.0.0 (OpenSpec + Superpowers).** The gate model is
> now the §17 lifecycle mapping (propose → validate → execute → archive →
> ship): `plan-review` and `spec-review` **collapse into validate** (the
> §18 change-gate + the `opencode-openspec-change-review` producer);
> `code-review`/`tdd`/`verification`/`security` are retained; design/db/qa/
> impeccable are conditional; `ts-declare` is a lint. The current, canonical
> sources are [`docs/WORKFLOW.md`](WORKFLOW.md), the trigger skill's
> **Step 3** table, and [ADR-0010](decisions/0010-openspec-superpowers-adoption.md).
> The "gates whose trigger cannot occur" table below remains current; the
> narrative of how this scaffolder was built (Phases 0–6) is retained as
> history.

This document records which `agenticapps-workflow-core/spec/02-hook-taxonomy.md`
gates fire for `opencode-workflow`'s **own** development, which gates do not
apply (with rationale), and which skill is bound to each. Gates marked
**(Superpowers)** or **(GSD)** bind to the upstream opencode distributions
(the Superpowers plugin and `npx gsd-opencode`); the rest are this repo's
`opencode-*` gates. See `docs/BINDING.md` for the binding architecture. It is
the host-side companion to the trigger skill's **Step 3 — Gate-to-skill
bindings** table. (Until v0.6.0 it companioned a duplicate of that table in
`AGENTS.md`; migration `0010` removed the eager copy under spec 0.10.0's §12
instruction-surface economy convention — the bindings now live in the
lazily-loaded `skills/agentic-apps-workflow/SKILL.md`, with the machine-readable
copy in `.planning/config.json`.)

The scaffolder repo dogfoods its own workflow per Phase 6 of the
build-out (`docs/dogfood-2026-05-10.md`).

## Conformance claim

`opencode-workflow` claims **`full` conformance** to
`agenticapps-workflow-core` v0.10.0 per spec/09 because:

1. The trigger skill `agentic-apps-workflow` reproduces the **five**
   canonical-prose blocks verbatim — Step 0 Commitment Ritual,
   Rationalization Table, Red Flags, Pressure-Test (spec/01,/03,/04,/05),
   and **§11 Coding Discipline** (injected into `AGENTS.md` behind a
   provenance anchor, byte-matched against the vendored mirror
   `skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`).
2. Every declarative-contract MUST in spec/02, /06, /07, /08, **/10,
   /12, /13** is satisfied by some `opencode-*` skill, an `install.sh` /
   migration-framework mechanism, or a delegation:
   - **§10 (observability)** — delegated to the standalone
     `agenticapps-observability` skill (see "§10 Observability —
     delegated binding" below); a *satisfied* MUST per §09.
   - **§12 (authoring conventions), incl. the v0.10.0
     instruction-surface economy SHOULD** — the always-loaded `AGENTS.md`
     carries the §11 canonical block plus two short pointers (the trigger
     skill, and the session-handoff protocol). The §02 gate table, task-size
     routing, the session-handoff procedure and the §15 knowledge-capture
     ritual tail all live in the lazily-loaded trigger skill, which loads on
     exactly the code-touching turns where they bind. Gate *enforcement* is
     unaffected — `.planning/config.json` and the CI guards are unchanged;
     only prose moved. Migration `0010`; core ADR-0020.
   - **§12 (authoring conventions)** — branchy workflows newly
     authored/edited at 0.4.0 render as Mermaid `flowchart`s
     (`opencode-ts-declare-first` refusals; trigger Step 2 routing).
     Surgical scope per §12 (no bulk conversion required).
   - **§13 (declare-first TS)** — `opencode-ts-declare-first` skill
     strengthens the `tdd` gate for new TS modules.
   - **§08 (migration format, v0.9.0)** — setup installs a prebuilt
     snapshot rather than replaying `0000`→latest (ADR-0007). §08 makes
     that conformant *provided a drift guard proves the snapshot equals
     the chain's end state*, and requires the host to name the guard in
     its instruction file. Named:
     **`migrations/check-snapshot-parity.sh`**, run in CI on every push
     (`.github/workflows/ci.yml`, step *Snapshot drift guard*). An
     unguarded snapshot would be non-conformant. Before v0.9.0, §08
     required replay outright — this scaffolder's snapshot install was
     non-conformant on a MUST for as long as it cited a pre-0.9.0
     version.
   - **§14 (prompt-injection, v0.6.0)** — *trivially conformant*: this
     scaffolder builds no LLM prompts from non-self-authored values, so
     the trigger cannot occur; §09 requires only that the host say so.
     Downstream coverage is delegated to `injection-guard`
     (agenticapps-observability), same basis as §10. The `security`
     gate carries the §02 obligation to record §14 evidence on
     LLM-scoped changesets.
3. Host-specific bindings exist for every gate **whose trigger
   condition can occur in this scaffolder's project type**. Gates
   whose triggers cannot occur are listed under "Spec Deltas" with
   the rationale per spec/09.
4. `skills/agentic-apps-workflow/SKILL.md` carries
   `implements_spec: 0.9.1` in frontmatter — this is the host's
   conformance claim, and it is the only normative carrier per spec/09
   ("the host's primary instruction file"). `.planning/config.json`
   mirrors it (the invariant migration `0006` restored). The individual
   `opencode-*` gate skills cite the spec version of the **contract they
   implement**, not the host's claim, so they do not move in lockstep:
   `opencode-ts-declare-first` stays at `0.4.0` because §13 is still a
   0.4.0 section. (This matches the reference host — `claude-workflow`
   cites 0.9.0 on its trigger and 0.4.0 on its `ts-declare-first`.)
   The GSD entry-point and Superpowers discipline skills are bound
   upstream (see `docs/BINDING.md`), not re-shipped here.
5. Each phase produces CONTEXT.md / PLAN.md / VERIFICATION.md /
   REVIEW.md as well-formed, machine-discoverable artifacts. (For
   the build-out itself the artifacts live in PR descriptions and
   commit messages; once opencode-workflow ships, the scaffolder's
   own ongoing development uses `.planning/phases/<N>/` per
   project convention.)

## Gate-to-skill bindings (opencode-workflow self-apply)

### Gates that fire on this repo's development

| Gate | Bound skill | When fires here | Notes |
|---|---|---|---|
| `brainstorm-architecture` | `superpowers:brainstorming` (Superpowers, architecture mode) | Adding a new skill, template, or migration | The Phase 0 ADR set is the reference shape |
| `tdd` | `superpowers:test-driven-development` (Superpowers) | Any task adding logic to `install.sh` or `migrations/run-tests.sh` | Markdown content (skills, templates, ADRs) does not require TDD |
| `tdd` (new TS module) | `opencode-ts-declare-first` | A new TypeScript module's public API surface (spec §13) | Strengthens `tdd`: three atomic commits `declare(ts):` → `test(ts):` (RED) → `feat(ts):` (GREEN). Does not fire on this markdown scaffolder; bound for downstream TS projects |
| `plan-review` → **collapsed into validate** | `opencode-openspec-change-review` (producer) + the §18 change-gate | Before code, on the active OpenSpec change | Evidence: `openspec/changes/<slug>/REVIEWS.md` from ≥2 external-vendor reviewers. Not a standalone gate under 1.0.0 (§17) — enforced by `~/.agenticapps/bin/openspec-change-gate.sh` |
| `verification` | `superpowers:verification-before-completion` (Superpowers) | Always — every PR | Evidence shapes here are typically grep results, file existence, and `run-tests.sh` output |
| `spec-review` → **collapsed into validate** | `openspec validate --all` | Before code, on the active change | The machine check the §18 change-gate calls; the former Stage-1 "spec compliance" pass |
| `code-review` | `superpowers:requesting-code-review` (Superpowers) | Always — every PR | Stage 2; `opencode run` child process per ADR-0002 |
| `security` | `opencode-cso` | When changing `install.sh` or any executable script | OWASP-aligned scan; for a scaffolder the relevant axes are: command injection, path traversal, secret exposure, unsafe `eval` of remote content |
| `branch-close` | `superpowers:finishing-a-development-branch` (Superpowers) | Every PR | The PRs for Phases 1–6 each demonstrate this binding |

### Spec Deltas — gates whose trigger cannot occur

Per spec/09, gates that have no possible trigger in the scaffolder's
project type can be omitted with a documented justification. These
deltas do NOT downgrade the conformance claim from `full` to
`partial` because the spec explicitly permits omission when triggers
cannot occur (spec/09 final paragraph in "full" section).

| Gate | Bound skill (for downstream projects) | Why no trigger here |
|---|---|---|
| `brainstorm-ui` | `superpowers:brainstorming` (Superpowers, ui mode) | The scaffolder ships no UI. All contributors interact via CLI / git / markdown. |
| `design-shotgun` | `opencode-design-shotgun` | Same — no visual surface to vary. |
| `design-critique` | `opencode-design-critique` | Same — no UI to critique. |
| `ui-preview` | `opencode-qa` (preview mode) | Same — no frontend code, no dev server. |
| `qa` | `opencode-qa` (phase-qa mode) | Same — no dev server reachable on a local port. |
| `impeccable-audit` | `opencode-impeccable-audit` | Same — no shipping UI surface. |
| `database-security` | `opencode-database-sentinel-audit` (phase-scoped) | The scaffolder has no database, no schema, no RLS rules. |
| `db-pre-launch-audit` | `opencode-database-sentinel-audit` (pre-launch) | Same. |

These eight bindings exist in the trigger skill's gate table because
**downstream projects** using opencode-workflow may have UI / databases /
dev servers; the bindings are not vestigial. They simply don't fire
on the scaffolder's own development.

## §10 Observability — delegated binding

§10 (introduced in core 0.2.0; current 0.3.2) obliges every host to
provide an observability **generator** (§10.7). opencode-workflow satisfies
§10 by **delegation**, not by shipping its own generator — see **ADR-0004**
(decision) and **ADR-0005** (adoption of core ADR-0014's architecture).

| Spec area | How opencode-workflow satisfies it | Mechanism |
|---|---|---|
| §10.1–10.6 wrapper interface, envelope, `traceparent`, instrumentation, operational reqs, destination independence | Delegated | `agenticapps-observability` skill (`$observability init`) |
| §10.5 `Flush(timeout)` primitive | Delegated | obs skill per-stack wrappers |
| §10.7 generator obligation | Delegated | obs skill; installed on opencode via `install-codex.sh` |
| §10.7.1 module-root path resolution | Delegated | obs skill |
| §10.8 project metadata block (`AGENTS.md`) | Host-managed | `$observability init` emits the anchored block (currently into `CLAUDE.md`); migration `0003` **relocates** it into `AGENTS.md` (the canonical opencode file), preserving init's real content, and repoints a stale skill ref. Flow: run `$observability init`, then `$update-opencode-agenticapps-workflow`. The obs-init host-awareness (writing `AGENTS.md` directly) is a tracked obs-repo follow-up; until it lands, migration 0003's relocate closes the gap on the opencode side |
| §10.9 baseline + `--since-commit` delta + CI | Delegated | obs skill (`$observability scan --since-commit`, `.observability/baseline.json`) |

A delegation to a consumable skill is a **satisfied** §10 MUST per §09 —
**not** a spec delta. The obligation is met by the consumed skill;
opencode-workflow remains the conformance claimant. This is distinct from the
eight "Spec Deltas" above (gates whose triggers cannot occur on this
scaffolder): §10 *is* satisfied, by delegation.

Setup/update guidance: `docs/observability-delegation.md`. Wiring:
`migrations/0003-delegate-observability.md`. Cross-repo enabler:
`agenticapps-observability` `install-codex.sh` (v0.12.0, PR #3).

## Process notes

- Every PR for this scaffolder uses a feature branch per the global
  CLAUDE.md feature-branch + PR rule. Direct commits to main are
  reserved for the bootstrap phase (see commits prior to Phase 1).
- The two-stage review for opencode-workflow's PRs runs Stage 1 in the
  authoring session and Stage 2 in a `opencode run` child process per
  ADR-0002. For PRs authored on Claude Code (as Phases 0–6 were),
  Stage 2 substitution is acceptable: a fresh Claude Code session
  with no prior session context can stand in for the independent
  reviewer until opencode sub-agent surfaces mature.
- Per-phase PRs: see PR #1 (trigger), PR #2 (gates), PR #3 (GSD
  entry-points), PR #4 (lifecycle + migrations + install), PR #5
  (Phase 6 self-apply, this PR's predecessor when this file is
  read in main).

## Drift detection

`agenticapps-workflow-core/tools/drift-report.sh` is the upstream
advisory check that compares canonical-block presence across known
host clones. Run it locally (from this scaffolder's parent
directory) to catch drift between the trigger skill's
canonical-prose blocks and the spec source of truth:

```bash
bash ~/Sourcecode/agenticapps-workflow-core/tools/drift-report.sh
```

Drift on canonical-prose blocks is a `gap` outcome at Stage 1
review and blocks PR merge until resolved.

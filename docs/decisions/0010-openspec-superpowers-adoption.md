# ADR-0010 — Adopt the OpenSpec + Superpowers front end (spec v1.0.0), retiring the GSD planning engine

**Status:** Accepted
**Date:** 2026-07-24
**Applies to:** `opencode-workflow` (this repo) — the opencode host scaffolder
**Supersedes:** ADR-0009 (§11 region-aware placement). Retires the 0.x
standalone plan-review gate binding; this repo's ADR-0002 / ADR-0003
GSD-entry-point framing is now historical.
**Relates to:** `agenticapps-workflow-core` spec v1.0.0 §16–§19 and core
ADR-0021; MEASUREMENT.md, PILOT-REPORT.md (this repo).

## Context

The 0.x line planned with a GSD `.planning/` phase engine as its front end:
roadmap → phase discuss → plan → execute, each phase a directory of artifacts.
`agenticapps-workflow-core` spec **v1.0.0** (§16–§19, core ADR-0021) replaces
that front end with **OpenSpec** while **keeping the Superpowers execution
discipline** unchanged — TDD, brainstorming, subagent-driven execution, and the
verification-before-completion contract all survive. Only the planning surface
moves: from a bespoke phase engine to a spec lifecycle whose CLI is the
authority.

This host adopts v1.0.0 as the **pilot host**. No sibling host — claude, codex,
or pi — is bound to v1.0.0 yet; opencode goes first, and PILOT-REPORT.md records
what the other hosts inherit. Everything below is the opencode instantiation of
the host-agnostic spec, not a re-specification of it.

## Decision

**Bind OpenSpec upstream as the planning front end, re-express the adversarial
review as the §18 change-gate predicate, collapse the redundant quality gates,
and remove gitnexus from all live surfaces.** Concretely:

### OpenSpec binding (§16)

Bind OpenSpec **upstream, not vendored**. Setup runs
`openspec init --tools opencode --profile core` (CLI `@fission-ai/openspec`),
which generates the opsx command set and the per-project `openspec/` slot. The
**CLI is authoritative over prose** — where this ADR or any skill body describes
a command's behaviour, the installed CLI wins. We track upstream rather than
freezing a copy.

### Lifecycle (§17)

The planning lifecycle is `propose → validate → execute → archive → ship`.
`archive` and `ship` are distinct steps: archiving a change closes its
`openspec/changes/<slug>/` record; shipping is the separate PR/merge act.
Conflating them is a spec violation.

### The change-gate (§18, retargeted)

The real enforcement surface is a **host-agnostic shell script**,
`~/.agenticapps/bin/openspec-change-gate.sh`, with an exit-code truth table it
owns. On opencode it is wired via a `tool.execute.before` **plugin hook that
throws to block** the tool call, backed by a git **pre-commit hook** and **CI**
as the agent-agnostic floor.

opencode's hook surface was marked **"unconfirmed"** in the port prompt. It is
now **RESOLVED**: opencode has **no `PreToolUse` setting** (that is a
Claude-host construct), but its plugin **`tool.execute.before`** hook is the
host-equivalent interposition point, and **throwing from it aborts the tool
call**. §18 explicitly permits a host-equivalent interposition point where the
named one is absent, so this satisfies the spec.

### plan-review reconciliation (called out explicitly)

The port prompt said "keep the plan-review gate." Spec §17 **forbids a
standalone plan-review / spec-review gate** under 1.0.0. These are reconciled,
not traded off:

- The **multi-AI adversarial review is KEPT**, re-expressed as the §18
  change-gate **predicate**: the gate passes only when `openspec validate --all`
  is green **AND** `openspec/changes/<slug>/REVIEWS.md` exists with **≥2
  `## Reviewer:` headings**.
- A reviewer **producer** skill, `opencode-openspec-change-review`, critiques the
  active OpenSpec change and writes that `REVIEWS.md`.
- It is **NOT a separately-named gate**. Same adversarial mechanism, 1.0.0
  framing — the review is a precondition the change-gate checks, not a step of
  its own.

### Gate collapse (§17)

- The spec-review **structural** role folds into `openspec validate`.
- `cso` / security review stays **always-on**.
- `database-sentinel`, `qa`, `design-critique`, `design-shotgun`, and
  `impeccable` become **conditional** (triggered by change surface, not run
  every time).
- `ts-declare-first` is **demoted to a CI lint gate**.
- `impeccable` and any Go skills are **kept behind the ADR-0021 measured trial**
  (MEASUREMENT.md) — retained under measurement, **not removed**.

### gitnexus removed

gitnexus is removed **entirely from every live surface**: the `opencode.json`
mcp block, `.claude/skills/gitnexus/`, the ~30 MB `.gitnexus/` directory, all
`AGENTS.md` / `CLAUDE.md` / `SETUP-REMOTE` / `BINDING` references, and the
setup-skill region-placement logic. Historical records are **retained** per
supersede-don't-delete: migration `0009`, ADR-0009, the CHANGELOG entries, and
the region-placement design doc stay as provenance.

### Versions

- `implements_spec` **0.10.0 → 1.0.0**.
- Workflow package `VERSION` **0.6.0 → 1.0.0**, reconciling the prior 0.5.0 /
  0.6.0 split into a single 1.0.0 stamp.

### Scaffolder guardrail

This repo **keeps its own `.planning/` intact** — it is the scaffolder, and its
planning history is not migrated. Recipe `0001` (planning → openspec) is
**packaged into the setup/update skills for TARGET repos**; it is not run
against this scaffolder itself.

## Supersedes

- **Supersedes ADR-0009** (§11 region-aware placement). ADR-0009 existed only to
  keep §11 clear of the gitnexus-injected region; with gitnexus gone, the region
  no longer exists and the region-placement logic is removed. ADR-0009 should be
  marked **Superseded-by-0010** in the index.
- **Retires the 0.x standalone plan-review gate binding.** This repo's ADR-0002 /
  ADR-0003 framing of GSD as the workflow entry point is now historical — the
  entry point is the OpenSpec lifecycle.

## Consequences

- As the **pilot host**, opencode establishes the pattern the other hosts inherit
  through PILOT-REPORT.md. Getting the hook resolution and the review
  reconciliation right here is what unblocks claude / codex / pi.
- The opencode `tool.execute.before` hook **cannot gate the session that is
  installing it** — the plugin is not yet loaded during its own install. The
  pre-commit hook and CI **floor** cover that window, which is exactly why the
  gate is defined as a shell script with two agent-agnostic backstops rather than
  a hook alone.
- The trial is **measured** (MEASUREMENT.md). `impeccable` and any Go skills are
  retained on that basis, not on conviction; a **sustained negative signal is
  grounds to revisit** their retention — and, if the measured cost outweighs the
  benefit, to revisit this adoption's scope.
- Removing gitnexus reclaims ~30 MB per scaffolded repo and deletes a live MCP
  dependency, at the cost of losing graph-based code lookup — an accepted trade,
  with provenance kept for anyone who needs the history.

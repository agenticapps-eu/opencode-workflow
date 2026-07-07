# Changelog

All notable changes to `opencode-workflow` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repo cites `implements_spec: <version>` against
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
in every shipped artifact's frontmatter.

## [Unreleased]

### Changed
- **Documented the `.planning/phases/` gitignore discipline.** Workflow-testbed
  round-2 benchmark feedback traced a gitignore friction (phase evidence
  silently uncommitted because `.planning/phases/` was ignored) to the
  testbed/claude scaffolder, not this one — the opencode scaffolder emits no
  such rule: `install.sh` and `setup-opencode-agenticapps-workflow` write no
  host `.gitignore`, and this repo's own `.gitignore` targets only
  `.planning/cache/` and `.planning/state/`. Promoted the round-2 run's
  improvised fix to documented behavior: a new Verification Check in the
  `agentic-apps-workflow` trigger skill probes `git check-ignore
  .planning/phases/` before committing evidence and, if the host project
  ignores it, un-ignores the path in a dedicated chore commit flagged in
  RUN-NOTES/handoff. Mirrors the claude-workflow amendment in
  `docs/standards/gsd-binding-and-planning.md` (conformance checklist: "MUST
  NOT gitignore `.planning/phases/` — phase artifacts are committed"). No
  migration: scaffolder output is unchanged. `check-snapshot-parity.sh` PASS;
  `run-tests.sh` 46 PASS / 1 SKIP.

### Backlog (beyond conformance)

- Plugin packaging — re-evaluate after in-the-wild use (ADR-0001 F2).
- Cross-host Stage 2 review via Claude Code MCP (ADR-0002 Option B).
- Upstream follow-up: `agenticapps-observability` `init` Phase 6 emits the
  §10.8 metadata block to `CLAUDE.md`; making it host-aware (`AGENTS.md` on
  Codex) would remove migration 0003's relocate round-trip.

## [0.3.0] — 2026-07-07

### Added
- **Knowledge capture ritual tail — core spec §15 (migration `0005`, ADR-0008).**
  Every ritual — session handoff, plan completion (`/gsd-plan-phase`), phase
  completion (`/gsd-execute-phase`) — now ends by distilling **1–5 transferable
  learnings** to **one Obsidian note per repo** in the operator's vault
  (`~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/<repo-name>.md`).
  Wired as an explicit, mechanical prose section on the always-loaded surfaces
  (the `agentic-apps-workflow` trigger `SKILL.md` and the project `AGENTS.md`),
  with a `(opencode)` Log host tag. Destination is config-routed via a
  host-neutral `knowledge_capture {enabled, note}` block in the single shared
  `.planning/config.json` (opencode does not namespace config); a co-installed
  codex/claude host reads the same block and writes to the same note. Graceful
  skip (spec §15.3) when the block is absent, `enabled: false`, or the vault
  folder is missing — never creates the folder, never fails or commits.
  - Fresh installs get it from the snapshot (`snapshot/agents-block.md` carries
    the section) plus a new setup Stage-C seed step that resolves `<repo-name>`
    from the `config-knowledge-capture.json` template. Existing installs get it
    via migration `0005` (0.2.1 → 0.3.0), which seeds the block (jq merge,
    preserving hooks) and inserts the section extracted from the
    `agents-md-additions.md` template (single source of truth).
  - New templates: `config-knowledge-capture.json`, `obsidian-learnings-note.md`
    (`hosts: [opencode]`). `implements_spec` stays `0.4.0` (tracks the last full
    audit, not §15 wiring).

### Changed
- **Snapshot parity guard hardened for §15.** `check-snapshot-parity.sh` now
  compares `.planning/config.json` **modulo** the repo-specific
  `knowledge_capture` block (its `note` carries the resolved repo name, so it is
  absent from the generic snapshot; §15.2/ADR-0017), and was made bash-3.2-safe
  (dropped `declare -A`) so the config comparison runs on macOS, not only CI.
- `run-tests.sh` adds `test_migration_0005` (config merge resolves `<repo-name>`
  and preserves a pre-existing key; AGENTS.md section insert + idempotency; the
  `(opencode)` tag; version-bump round-trip). Drift target is now 0.3.0.

## [0.2.1] — 2026-06-09

### Fixed
- **§11 mirror byte-drift vs current core (migration `0004`).** The v0.2.0
  mirror was vendored from a stale local checkout of `agenticapps-workflow-core`;
  core `10f2c96` (merged via core #12) had added blank lines around the §11
  anti-pattern lists (block 75 → 79 lines, fence 26–102 → 26–106), so the
  shipped mirror + `AGENTS.md` block had drifted from the authoritative core
  §11 — a canonical-prose conformance defect (§09 item 1). Migration `0004`
  (`0.2.0 → 0.2.1`, additive to `implements_spec` which stays `0.4.0`)
  re-vendors the mirror byte-identical to current core and re-injects the
  corrected block into `AGENTS.md`.
- **Harness hardened against recurrence.** `run-tests.sh` now extracts the
  canonical block **fence-relative** (between the four-backtick fences) instead
  of by hardcoded line numbers, so future spec line-shifts cannot silently
  reintroduce the drift; `test_migration_0004` asserts the live `AGENTS.md`
  block matches the corrected (79-line) mirror. `run-tests.sh`: PASS 46 / FAIL
  0 / SKIP 1.

### Changed
- Scaffolder `version` `0.2.0 → 0.2.1` (trigger SKILL.md + `.codex/workflow-version.txt`).
  `implements_spec` unchanged at `0.4.0` (10f2c96 is a markdown-clean patch, not
  a spec version bump).

## [0.2.0] — 2026-06-09

Catch-up to `agenticapps-workflow-core` **spec 0.4.0** (full conformance),
from the 0.1.0 baseline. Feature-bearing minor: new canonical prose, a new
skill, observability delegation, and surgical Mermaid. Migration chain
`0001`–`0003` (contiguous; `0001` is the sole version/`implements_spec`
bumper). `run-tests.sh`: PASS 43 / FAIL 0 / SKIP 1.

### Added
- **§11 Coding Discipline (canonical prose).** Reproduced verbatim in
  `AGENTS.md` behind the provenance anchor
  `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->`; vendored
  byte-identical mirror at
  `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`.
  Migration `0001` (from 0.1.0 → 0.2.0) injects it and is the **sole bumper**
  of `version` (→0.2.0) and `implements_spec` (→0.4.0). (Phase 1)
- **§13 declare-first TypeScript.** New gate skill `codex-ts-declare-first`
  (strengthens the `tdd` gate): three atomic commits
  `declare(ts):` → `test(ts):` (RED) → `feat(ts):` (GREEN), three refusals,
  three separate phase templates. Bound in the trigger Step 3 gate table and
  `config-hooks.json`. Migration `0002` (additive). (Phase 2)
- **§12 authoring conventions (surgical Mermaid).** `flowchart` decision
  skeletons for the newly authored/edited branchy workflows
  (`codex-ts-declare-first` refusals; trigger Step 2 routing); criteria stay
  in prose. No bulk conversion (§12 does not require it). (Phase 4)
- **§10 observability (delegation).** Satisfied by delegating to the
  standalone `agenticapps-observability` skill — installed on Codex via that
  repo's new `install-codex.sh` (agenticapps-observability v0.12.0, PR #3) —
  rather than re-owning a generator. Migration `0003` records the delegation,
  relocates the §10.8 metadata block into `AGENTS.md`, and repoints a stale
  skill ref (no auto-install; D-03 mirror). ADR-0004 (decision), ADR-0005
  (adopt core ADR-0014), `docs/observability-delegation.md`. (Phase 3)
- Drift test in `migrations/run-tests.sh` (`SKILL.md version` == latest
  migration `to_version`); per-migration tests `0001`–`0003`.
- ADR-0006 records the core ADR-0015 outcome (secret scanner **stays on
  gitleaks**; no scanner code change here). (Phase 5)

### Changed
- `implements_spec: 0.4.0` across the trigger, 14 gate skills, 5 GSD
  entry-point skills, 2 lifecycle skills, and `config-hooks.json`. (Phase 5)
- `.codex/workflow-version.txt` → `0.2.0`; trigger `SKILL.md` `version` → `0.2.0`.
- `docs/ENFORCEMENT-PLAN.md` conformance claim 0.1.0 → 0.4.0 (+ §10 delegated
  binding section, §13 binding row). README + this CHANGELOG updated. (Phase 5)
- **install.sh restructure (Phase 6):** `templates/` moved permanently under
  `skills/setup-codex-agenticapps-workflow/templates/` (history-preserving);
  the secondary templates-symlink step removed (no install-time write inside
  the source tree); the obsolete `skills/*/templates` `.gitignore` rule dropped.
  Fixed a dangling-symlink bug — `install_one` now tests `-L` before `-e`, so
  stale/dangling skill links (e.g. after a repo relocation) are repointed
  instead of leaving `ln -s` to fail "File exists".
- **agenticapps-shared submodule (Phase 6):** added at `vendor/agenticapps-shared/`
  (pinned v1.0.0); `migrations/run-tests.sh` now sources the shared harness
  primitives (helpers / fixture-runner / drift-test) instead of local copies;
  install.sh refreshes the submodule. SPLIT-01 parity.

### Verified (Phase 6)
- Empirical checks recorded in ADR appendices (Codex 0.130.0): AGENTS.md
  concat is git-root-down to cwd (ADR-0001 A2); `allow_implicit_invocation:
  false` is honored — the GSD entry points do not leak into unrelated sessions
  (ADR-0003 F2).

## [0.1.0] — 2026-05-10

Initial release. Full-conformance Codex CLI host implementation of
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
v0.1.0. Sibling of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).

### Inventory

- 1 trigger skill — `agentic-apps-workflow` (canonical-prose blocks
  byte-matched against spec/01, /03, /04, /05)
- 13 gate-fulfilling skills — every spec/02 gate has a binding
- 5 GSD entry-point skills — explicit-only via
  `policy.allow_implicit_invocation: false`
- 2 lifecycle skills — `setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`
- 5 project-side templates
- Migration framework — `0000-baseline.md`, `run-tests.sh`,
  `test-fixtures/`, `README.md` (implements
  spec/08-migration-format.md)
- `install.sh` — symlinks skills into `$CODEX_HOME/skills/`
- 3 architecture decision records
- `docs/ENFORCEMENT-PLAN.md` documenting `full` conformance with
  Spec Deltas for gates whose triggers cannot occur on a UI-less
  DB-less scaffolder (per spec/09)
- `docs/dogfood-2026-05-10.md` — Phase 6 self-apply log

### Phase-by-phase

- Phase 0 — Repo bootstrap and Codex CLI research
  - README skeleton, MIT LICENSE, .gitignore, AGENTS.md placeholder
  - Trivial CI workflow (`.github/workflows/ci.yml`) that prints the phase
    name; replaced with real CI in Phase 7
  - Three ADRs documenting the five Phase 0 research findings:
    - `docs/decisions/0001-codex-skill-naming.md` — skill directory paths,
      naming convention, packaging choice (loose skills + `install.sh` for
      v0.1.0; plugin manifest deferred to v0.2.0)
    - `docs/decisions/0002-stage2-independent-reviewer-on-codex.md` — Stage 2
      reviewer is implemented via `codex exec` child process with optional
      `--model` override; cross-host review via Claude Code MCP deferred
    - `docs/decisions/0003-gsd-entry-points-as-prompts.md` — Codex has no
      native `prompts/` surface; GSD entry points ship as skills with
      `policy.allow_implicit_invocation: false` and `default_prompt` in
      `agents/openai.yaml`
  - `research-complete` tag marks the end of Phase 0

- Phase 1 — Trigger skill
  - `skills/agentic-apps-workflow/SKILL.md` authored against
    `agenticapps-workflow-core` v0.1.0
  - Frontmatter cites `implements_spec: 0.1.0` per spec/09 conformance
  - Four canonical-prose blocks reproduced verbatim and byte-match
    confirmed against `agenticapps-workflow-core/spec/`:
    - Step 0 — Commitment Ritual (spec/01)
    - Rationalization Table (spec/03)
    - 13 Red Flags (spec/04)
    - Pressure-Test Scenarios (spec/05)
  - Step 1 (4-row task-size table), Step 2 (GSD entry-point routing),
    Step 3 (15-gate binding table mapping every spec/02 gate to a
    `codex-*` skill), Step 4 (ADR capture pointers), Verification
    Check (5 host-specific bash snippets covering commitment block,
    TDD commit pairs, Stage 2 evidence, per-`must_have` evidence,
    and `implements_spec` currency)

- Phase 2 — 13 gate-fulfilling skills
  - Each skill cites `implements_spec: 0.1.0` and an `implements_gate`
    field naming the spec/02 gate(s) it satisfies. Codex's loader reads
    only `name` and `description`; the extension fields are ignored at
    load and read by conformance audits per ADR-0001 D6.
  - **Every-phase skills** — `codex-tdd` (RED + GREEN commit pair),
    `codex-verification` (refuses completion without `must_have`
    evidence per spec/06), `codex-spec-review` (Stage 1 of the
    two-stage review per spec/07), `codex-code-review` (Stage 2,
    spawns independent reviewer via `codex exec` per ADR-0002)
  - **Pre-phase + design** — `codex-brainstorming` (≥2 named
    alternatives for UI or architecture per spec/02), `codex-design-shotgun`
    (≥3 visual variants), `codex-design-critique` (impeccable-style
    7-dimension scoring + 24-anti-pattern scan per ADR-0011)
  - **Security + QA** — `codex-cso` (OWASP-aligned phase audit),
    `codex-qa` (dual-mode: per-task `ui-preview` + post-phase
    `qa`), `codex-impeccable-audit` (post-implementation visual
    audit, blocks branch close on Red findings per ADR-0011),
    `codex-database-sentinel-audit` (dual-mode: phase-scoped sub-gate
    + pre-launch full-surface, blocks on Critical/High per ADR-0012)
  - **Methodology + finishing** — `codex-systematic-debugging`
    (Observe → Hypothesize → Test → Conclude four-phase protocol;
    not bound to a spec gate, invoked by `$gsd-debug`),
    `codex-finishing-branch` (composes PR description from phase
    artifacts; opens PR via `gh`)

- Phase 3 — 5 GSD entry-point skills (per ADR-0003: skills, not prompts)
  - Each skill ships as `skills/gsd-<verb>/SKILL.md` plus
    `agents/openai.yaml` carrying
    `policy.allow_implicit_invocation: false` and a
    `default_prompt` that names the skill as `$gsd-<verb>` per the
    Codex `openai_yaml.md` reference's explicit-mention rule.
  - **`gsd-discuss-phase`** — surfaces open questions, writes
    `CONTEXT.md` with resolved decisions; routes to
    `codex-brainstorming` when a brainstorm gate fires
  - **`gsd-plan-phase`** — reads `CONTEXT.md`, decomposes into
    tasks with gate triggers and must_haves, authors `PLAN.md`
    plus `RESEARCH.md` / `UI-SPEC.md` as needed; pre-flight checks
    that every required `codex-*` skill is installed
  - **`gsd-execute-phase`** — heavyweight wave executor; emits
    commitment block per task, fires applicable spec/02 gates,
    refuses task completion without `codex-verification` evidence,
    runs the post-phase pipeline (spec-review → code-review →
    security/qa/audits) and finishes with `codex-finishing-branch`
  - **`gsd-quick`** — for tiny/small tasks; minimal commitment
    block + direct route to `codex-tdd` / `codex-verification` /
    `codex-finishing-branch`; refuses medium/large tasks and
    routes to `gsd-discuss-phase` instead
  - **`gsd-debug`** — thin user-facing entry that hands off to
    `codex-systematic-debugging` (the four-phase protocol)

- Phases 4 + 5 — Lifecycle skills, migration framework, templates, install.sh
  - **Templates** at `templates/` — five project-side artifacts that
    setup copies into a fresh project:
    - `agents-md-additions.md` — workflow sections for project AGENTS.md
    - `workflow-config.md` — project-specific config with
      `{{PLACEHOLDERS}}` (project name / repo / client / budget /
      backend / frontend / database / LLM / quality bars / etc.)
    - `config-hooks.json` — `.planning/config.json` template binding
      every spec/02 gate to its `codex-*` skill
    - `adr-db-security-acceptance.md` — ADR template for accepting
      database-sentinel Critical/High findings (per ADR-0012)
    - `global-agents-additions.md` — optional `~/.codex/AGENTS.md`
      append for Option A install
  - **Migration framework** at `migrations/` — implements the
    declarative contract from
    `agenticapps-workflow-core/spec/08-migration-format.md`:
    - `README.md` — host-side manifestation of the migration format
      contract, with Codex paths
    - `0000-baseline.md` — six-step baseline migration (project
      workflow-config, .planning/config.json, AGENTS.md sections,
      docs/decisions/README.md, .codex/workflow-version.txt, optional
      global AGENTS.md additions)
    - `run-tests.sh` — fixture-based test harness; SKIPs the
      interactive-only baseline; runs repo layout sanity checks
    - `test-fixtures/README.md` — fixture contract (extract from git
      refs rather than static fixture files)
  - **Lifecycle skills** at `skills/`:
    - `setup-codex-agenticapps-workflow` — apply baseline migration
      to a fresh project; pre-flights Codex CLI + scaffolder install;
      gathers placeholder values; refuses to re-run on installed
      project
    - `update-codex-agenticapps-workflow` — apply pending migrations
      between project's recorded version and scaffolder version;
      supports `--dry-run`, `--migration NNNN`, `--from VERSION`
  - **`install.sh`** — symlinks every `skills/<name>/` into
    `$CODEX_HOME/skills/<name>/` (default `~/.codex/skills/`) plus a
    `templates/` symlink so migration apply steps can `cp` from a
    stable scaffolder path; idempotent; refuses to clobber non-symlink
    directories; `--copy` and `--dry-run` flags

- Phase 6 — Self-applied workflow + dogfood
  - **Real `bash install.sh`** run against `~/.codex/skills/`. 22
    entries created (21 skill symlinks + 1 templates symlink).
    Idempotent re-run confirms 0 installed / 22 skipped.
  - **AGENTS.md populated** — placeholder replaced with the
    populated structure (Development Workflow, Workflow Enforcement
    Hooks table marking which gates apply to the scaffolder vs which
    don't, Skill routing, Session handoff)
  - **`.planning/config.json`** seeded from
    `templates/config-hooks.json`
  - **`.codex/workflow-config.md`** authored with substituted values
    for codex-workflow's own metadata (project = codex-workflow,
    no UI, no DB, no dev server — gates whose triggers can't fire
    are documented as Spec Deltas in ENFORCEMENT-PLAN, NOT a
    `partial` conformance claim per spec/09)
  - **`.codex/workflow-version.txt`** = `0.1.0` (the durable record
    that `update-codex-agenticapps-workflow` will read on future
    upgrades)
  - **`docs/decisions/README.md`** — index of the three Phase 0 ADRs
  - **`docs/ENFORCEMENT-PLAN.md`** — gate-to-skill bindings for
    codex-workflow's own development; explicitly enumerates the 8
    gates that don't fire on this scaffolder (with rationale per
    spec/09); claims `full` conformance
  - **`docs/dogfood-2026-05-10.md`** — log of the Phase 6 self-apply
    plus a walk-through of a `$gsd-quick` micro-cycle (the README
    refresh that's part of this PR); records the open follow-ups
    for the AGENTS.md root-down concat verification and the
    `policy.allow_implicit_invocation: false` empirical check
  - **README refresh** (the dogfood micro-cycle) — Status, What
    ships, Layout, and Install sections updated to reflect the
    actual shipped state

- Phase 7 — Release
  - This CHANGELOG entry; final README pass
  - `v0.1.0` git tag
  - Repo flipped from private to public
  - Sibling PR against `agenticapps-workflow-core` updating the
    `reference-implementations/README.md` codex-workflow row from
    "repo not yet created" to "v0.1.0 shipped, full-conformance"
  - Follow-up issue opened against `agenticapps-dashboard` for
    Codex host detection in HostAdapter

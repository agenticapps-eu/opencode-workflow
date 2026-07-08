# ADR-0008: Knowledge capture ritual tail — spec §15 on the opencode host

**Status**: Accepted  **Date**: 2026-07-07
**Core contract**: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0), core ADR-0017
**Sibling hosts**: claude-workflow ADR-0038 (reference), codex-workflow ADR-0008

## Context

Core ADR-0017 added spec §15: every host writes 1–5 distilled, transferable
learnings to **one Obsidian note per repo**
(`~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/<repo-name>.md`)
at three ritual boundaries — session handoff, plan completion, phase
completion. Today those learnings die where they were made:
`.opencode/session-handoff.md` is overwritten by the next session, and
ADRs/CHANGELOGs capture repo-scoped facts by design. Nothing carries a root
cause from one repo to an agent in another, or an opencode insight to a codex
session sharing the same working tree.

claude-workflow is the reference host (ADR-0038); codex-workflow mirrored it
(ADR-0008). Core ADR-0017's downstream note obliges opencode to mirror it **in
its own idiom**. Three forces shape the opencode mirror:

1. **opencode binds upstream GSD, not a custom port.** The three rituals are
   driven by GSD entry-point skills (`/gsd-plan-phase`, `/gsd-execute-phase`)
   and the session-handoff instruction in `AGENTS.md`. The capture step lives on
   this repo's *own* always-loaded surfaces — the trigger `SKILL.md` and the
   project `AGENTS.md` — not inside those upstream skills.
2. **opencode reads `AGENTS.md` root-down and loads skills on match.** The
   reliable home for a ritual tail that must fire on a plain session-handoff turn
   (which may not match the trigger skill) is the project `AGENTS.md`, with the
   trigger `SKILL.md` mirroring it for code-task turns.
3. **opencode ships a snapshot, not a migration replay (ADR-0007).** This is the
   decisive divergence from codex. Fresh installs copy `snapshot/`; a drift guard
   (`check-snapshot-parity.sh`) requires the snapshot to equal the migration
   end-state. So §15 has to be wired into *both* the migration chain (for
   upgrades) **and** the snapshot (for fresh installs), kept in lockstep by the
   guard.

## Decision

1. **Wiring is a prose section on two surfaces, not a hook.** A
   `## Knowledge Capture — Ritual Tail (spec §15)` section is added to (a) the
   trigger `skills/agentic-apps-workflow/SKILL.md`, (b) the project `AGENTS.md`
   (via the `agents-md-additions.md` template and this repo's own `AGENTS.md`),
   and — because opencode installs fresh from a snapshot — (c)
   `snapshot/agents-block.md`, byte-identical to the AGENTS.md block the guard
   checks. §15 permits any mechanism; a prose step keeps the selectivity bar (an
   LLM judgment call) where an LLM executes it, needs no new runtime, and
   survives opencode's AGENTS.md concat model. The section is written maximally
   explicit and mechanical — exact headings, exact config key path, exact skip
   conditions, exact Log-heading shape — because the host (GLM 5.2) follows
   verbatim rather than inferring.

2. **Destination is config-routed, in the single shared `.planning/config.json`.**
   Unlike codex (which namespaces its *hooks* to `.planning/config.codex.json`),
   opencode keeps one un-namespaced `.planning/config.json` holding `$schema`,
   `implements_spec`, `host`, and `hooks`. The host-neutral `knowledge_capture`
   block (`enabled` + `note` only) merges into that same file. The vault note is
   one-per-repo, shared across hosts (its `hosts:` frontmatter lists
   `[opencode, …]`); a co-installed codex/claude host resolves the *same*
   destination and differs only by the `(opencode)` / `(codex)` / `(claude)` tag
   in the Log heading. Hardcoding the path in skill logic is rejected — it
   violates repo self-containment (core ADR-0017's reason for per-repo config).

3. **Fresh installs: snapshot + a setup seed step.** `snapshot/agents-block.md`
   carries the ritual-tail section; `$setup-opencode-agenticapps-workflow`
   Stage C seeds the `knowledge_capture` block into `.planning/config.json` with
   `<repo-name>` resolved (from `config-knowledge-capture.json`) — NOT baked into
   the snapshot config, because the note path is repo-specific.

4. **Existing installs: migration 0005 (0.2.1 → 0.3.0).** Step 1 seeds the block
   via a `. + {knowledge_capture}` merge that preserves every existing key and is
   skipped when the block already exists. Step 2 inserts the AGENTS.md section by
   **extracting it from the `agents-md-additions.md` template** — single source
   of truth, so a migrated install is byte-identical to a fresh one. Steps 3–4
   bump the scaffolder version and record the project version. As the
   highest-numbered migration, 0005 is also the parity anchor.

5. **Snapshot parity treats `knowledge_capture` as repo-specific.** The parity
   guard compares `.planning/config.json` to `snapshot/planning-config.json`
   **modulo** the `knowledge_capture` block (its `note` carries the resolved repo
   name, so it is deliberately absent from the generic snapshot). Everything else
   is still compared. (The guard was also made bash-3.2-safe so this comparison
   runs on macOS, not only CI.)

6. **Graceful skip (spec §15.3).** Block absent, `enabled: false`, or the vault
   parent folder missing → skip with at most one info line, never create the
   folder, never fail the ritual. The vault write is never committed.

## Alternatives Rejected

- **A Stop/PostToolUse-style hook.** opencode's rituals run through bound GSD
  skills this repo does not own; the selectivity bar + Key-Learnings curation are
  judgment calls a shell hook cannot make. Spec §15 non-requirements bless a
  prose step.
- **Baking `knowledge_capture` into `snapshot/planning-config.json`.** The note
  path is repo-specific; a snapshot with a resolved name would misconfigure every
  other repo, and one with a literal `<repo-name>` would break parity's verbatim
  config diff and leave a placeholder at runtime (§15.2 forbids runtime
  substitution). Seeding at config time with parity exclusion is correct.
- **Putting `knowledge_capture` in a host-specific config file.** opencode has no
  such split; and even where a host namespaces hooks, the vault destination must
  be the *same* across hosts, so the block stays host-neutral in the shared file.
- **Duplicating the section text inside migration 0005.** A self-contained
  heredoc drifts the moment the template changes; extraction from the template
  keeps one canonical copy, and the snapshot copy is guard-verified against it.

## Consequences

- v0.3.0 (minor, additive). Fresh installs get §15 from the snapshot + setup seed
  step; the fleet reaches it via `$update-opencode-agenticapps-workflow`
  (migration 0005). Repos opt out per-repo (`enabled: false`) or per-machine (no
  vault folder) without touching code.
- The vault-side `CLAUDE.md` in the learnings folder stays authoritative for the
  note format; the skill/AGENTS.md section and
  `templates/obsidian-learnings-note.md` mirror it and must be patched if it
  changes (the sync obligation core §15.4 documents).
- `implements_spec` stays at `0.4.0`: it tracks the last full-conformance audit;
  §15 wiring is real either way, and bumping the citation requires auditing the
  §§ added in later core versions — out of scope here.
- Drift coupling: migration 0005's `to_version` (0.3.0) is the drift target; the
  trigger skill `version:` is bumped to 0.3.0 in lockstep (`run-tests.sh`
  `test_drift`). Snapshot parity stays green (`check-snapshot-parity.sh`).

## References

- Core spec: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0)
- Core ADR: `agenticapps-workflow-core/adrs/0017-knowledge-capture-obsidian.md`
- Snapshot install: `docs/decisions/0007-snapshot-install.md`
- Migration: `migrations/0005-knowledge-capture.md`
- Sibling precedent: codex-workflow `docs/decisions/0008-knowledge-capture.md`, claude-workflow ADR-0038

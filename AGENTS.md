# AGENTS.md — opencode-workflow

This is the **scaffolder repo** that ships the AgenticApps spec-first
workflow for the opencode host. It self-applies its own
workflow per Phase 6 of the build-out.

The trigger skill, gate skills, GSD entry points, and lifecycle skills
this repo authors are linked into `${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/`
via `install.sh` (run from this repo's root). opencode auto-discovers
them on next session start.

The version of `opencode-workflow` this repo's own development is
asserted against is recorded at `.opencode/workflow-version.txt`.

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->
## Coding Discipline (NON-NEGOTIABLE)

These four rules are reread every session because the failure modes
they prevent recur every session.

### 1. Think Before Coding

State assumptions explicitly before writing any line. When the request
is ambiguous, present the alternative interpretations and ask which
applies. When the request contradicts itself, surface the contradiction
rather than silently picking one side. When you are confused, stop and
ask — confusion is signal, not friction.

Anti-patterns this rule prevents:

- Diving into implementation without restating what was actually requested.
- Picking one reading of an ambiguous instruction silently and shipping it.
- Treating two contradictory requirements as if both can be satisfied without comment.
- Treating "I'll figure it out as I go" as a substitute for understanding the goal.
- Generating code first and asking clarifying questions only after a failure.

### 2. Simplicity First

Write the smallest thing that satisfies the request. No features
beyond what was asked. No abstractions for code with one caller. No
flexibility for callers that do not exist. No error handling for
scenarios that cannot occur given the code's invariants. The
senior-engineer test: would a senior engineer reviewing this say it is
overcomplicated for what was asked?

Anti-patterns this rule prevents:

- Adding a helper function "in case we need to call this from elsewhere later."
- Introducing a configuration option for behavior that has one consumer.
- Wrapping internal calls in try/catch when no internal caller throws.
- Designing for a hypothetical second consumer that does not exist.
- Replacing three similar lines with a parameterised abstraction.
- Shipping a "framework" when a function would do.

### 3. Surgical Changes

Touch only what you must to satisfy the task. Adjacent code is out of
scope. Match the existing style of the file you are editing rather than
the style you would have chosen. Clean up only the orphans your own
change created. If you notice an unrelated improvement, leave it as a
follow-up note, not a diff.

Anti-patterns this rule prevents:

- Reformatting untouched lines to "fix style" while editing nearby.
- Refactoring a function that the task did not name.
- Renaming a variable across the file because the new name is "better."
- Deleting code you decided is unused without verifying it has no callers.
- Pulling adjacent code into the diff because "while I'm here."
- Bundling a cleanup pass into a feature commit.

### 4. Goal-Driven Execution

Every task is a goal, not a list of imperative steps. Restate the goal
in a form that is verifiable from on-disk artifacts before writing any
code. For bug fixes: write the failing test that reproduces the bug
first, then make it pass. For performance work: capture the measurement
first, then change the code, then capture it again. For behavioral
changes: define the assertion the diff must satisfy before the diff
exists. "Done" is "the goal is verifiably satisfied," not "the code now
exists."

Anti-patterns this rule prevents:

- "Fix the bug" without a failing test that reproduces it.
- "Improve performance" without a measurement before and a measurement after.
- "Make it work" without a definition of "work" the diff can be checked against.
- Marking a task complete on the basis of "the code now exists" rather than "the goal is satisfied."
- Writing implementation before there is anything that can fail to confirm the goal is met.

These four rules apply to every code-touching turn. They do not
replace the commitment ritual, the rationalisation table, the red
flags, or the evidence rules — they sit alongside them as the
session-level discipline the model brings to every diff.

## Development Workflow

This repo uses the AgenticApps spec-first workflow on the OpenAI
opencode host. The trigger skill `agentic-apps-workflow` activates
on every code-touching task and emits the canonical commitment
ritual before any tool call. See
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
for the spec, this repo for the host-specific binding.

The version of `opencode-workflow` this project was set up against is
recorded at `.opencode/workflow-version.txt`.

## Workflow Enforcement Hooks (MANDATORY)

The `agentic-apps-workflow` trigger skill binds every spec/02 gate
to a `opencode-*` skill. Project-specific gate bindings live in
`.planning/config.json`. Do not bypass a gate — accept-via-ADR is
the override path. Gates that do not apply to this scaffolder repo
(no UI, no DB, no auth) are documented in `docs/ENFORCEMENT-PLAN.md`
with the rationale.

| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
Gates marked **(Superpowers)** or **(GSD)** bind to the upstream opencode skills
(installed via the Superpowers plugin and `npx gsd-opencode`); see `docs/BINDING.md`.
The rest are AgenticApps/gstack gates shipped by this repo.

| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
| brainstorm-ui | `superpowers:brainstorming` (Superpowers) | No (no UI) |
| brainstorm-architecture | `superpowers:brainstorming` (Superpowers) | Yes (when adding skills/templates/migrations) |
| design-shotgun | `opencode-design-shotgun` | No (no UI) |
| design-critique | `opencode-design-critique` | No (no UI) |
| tdd | `superpowers:test-driven-development` (Superpowers) | Yes (any logic in `install.sh` / `run-tests.sh`) |
| ui-preview | `opencode-qa` (preview mode) | No (no UI) |
| verification | `superpowers:verification-before-completion` (Superpowers) | Yes (always) |
| spec-review | `opencode-spec-review` | Yes (always) |
| code-review | `superpowers:requesting-code-review` (Superpowers) | Yes (always) |
| security | `opencode-cso` | Yes (executable scripts) |
| database-security | `opencode-database-sentinel-audit` | No (no DB) |
| qa | `opencode-qa` | No (no dev server) |
| impeccable-audit | `opencode-impeccable-audit` | No (no UI) |
| db-pre-launch-audit | `opencode-database-sentinel-audit` | No (no DB) |
| branch-close | `superpowers:finishing-a-development-branch` (Superpowers) | Yes (always) |

## Skill routing

For any task in this scaffolder repo, route through the trigger
skill's task-size table:

- **Tiny** (typo, comment, README) → `superpowers:verification-before-completion`
- **Small** (single-file logic) → `superpowers:test-driven-development` → `superpowers:verification-before-completion` → `superpowers:finishing-a-development-branch`
- **Medium** (new skill, new template, new migration) → `/gsd-discuss-phase` → `/gsd-plan-phase` → `/gsd-execute-phase` (GSD)
- **Large** (cross-cutting refactor, new lifecycle, breaking changes) → same as medium plus `opencode-cso` for any security-sensitive scripts

Bug reports route through `/gsd-debug` (GSD) or
`superpowers:systematic-debugging` (Observe → Hypothesize → Test → Conclude).

## Session handoff

At the start of every session, check for `.opencode/session-handoff.md`.
If it exists and was modified in the last 7 days, read it before doing
anything else and confirm what was found. **Only read the opencode
handoff** — do NOT read a bare root `session-handoff.md` or another
host's handoff (e.g. the Codex host's `session-handoff.md`, which
lives under its own marker dir); handoffs are
host-scoped so multiple hosts can share one working tree without
cross-contaminating context.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write
`.opencode/session-handoff.md`. The file is in `.gitignore`
because it is a working artifact for cross-session continuity, not
a shipped scaffolder artifact.

## Knowledge Capture — Ritual Tail (spec §15)

Transferable learnings must not die in a `.opencode/session-handoff.md` that
the next session overwrites. This step routes them to a cross-repo memory:
**one Obsidian note per repo** in the operator's vault. It is the FINAL step of
three rituals — run it AFTER, never before, the ritual's own artifact exists:

1. **Session handoff** — after `.opencode/session-handoff.md` is written.
2. **Plan completion** — after a phase plan is authored/marked complete under
   `.planning/` (`/gsd-plan-phase`).
3. **Phase completion** — after the phase artifacts are committed
   (`/gsd-execute-phase`).

The vault write is machine-local: it MUST NEVER be committed to the repo, and
it MUST NEVER fail, block, or roll back the ritual that triggered it — on any
failure print one warning line and continue.

Procedure (mechanical — follow every branch exactly):

1. **Read the config.** Open `.planning/config.json` — the single, shared,
   host-neutral file (opencode does not namespace it) — and read its
   `knowledge_capture` object. **Skip** — print at most one line
   `knowledge-capture: skipped (<reason>)` and continue the ritual — when ANY
   of these holds:
   - `.planning/config.json` is absent, or has no `knowledge_capture` key, or
   - `knowledge_capture.enabled` is `false`, or
   - the parent folder of `knowledge_capture.note` does not exist (expand a
     leading `~` against `$HOME` first).
   NEVER create the parent folder: an absent vault means "not this machine",
   not "set up the vault".
2. **Distill 1–5 transferable learnings** from the ritual just completed. A
   learning qualifies ONLY if it would change how you, another agent, or
   another host works next time: gotchas whose root cause generalizes; decision
   rationale with reusable trade-offs; tooling/workflow insights (what made the
   agent fast or slow); wrong assumptions and what corrected them. Status
   updates, restatements of the plan, repo facts already in
   ADRs/handoffs/CHANGELOGs, and filler do NOT qualify. **If nothing clears the
   bar, write nothing** — no empty entries, no placeholders. A skipped write is
   conformant; a padded one is not.
3. **Resolve the note path.** Let `NOTE` = `knowledge_capture.note` with a
   leading `~` expanded against `$HOME`.
4. **Create the note on first write.** If `NOTE` does not exist, create it from
   the skeleton at
   `${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/obsidian-learnings-note.md`
   (fill the `<...>` fields and the dates; `hosts:` starts as `[opencode]`).
5. **Prepend a Log entry** at the TOP of `## Log` (append-only — NEVER edit or
   delete existing entries) under a heading of EXACTLY this shape, with
   `opencode` as the host tag:
   `### YYYY-MM-DD — <handoff|plan|phase> — <short title> (opencode)`
   where the second field is the trigger that fired (`handoff`, `plan`, or
   `phase`), and the learnings as bullets beneath it.
6. **Curate `## Key Learnings`:** dedupe, merge related items, promote log
   entries that earned it, demote or remove stale ones. Target ~10–20
   highest-value items — each a bolded short title plus one to three sentences
   carrying the transferable insight, not the status.
7. **Update frontmatter:** set `updated:` to today's date; ensure `opencode`
   appears in the `hosts:` list (add it, preserving any hosts already listed —
   e.g. `[claude]` becomes `[claude, opencode]`).
8. **Report** in one or two lines what was written (or why the step skipped).

Vault safety (hard rules): touch ONLY the configured note — never other repos'
notes, the folder's `CLAUDE.md`, or anything else in the vault. Never write
secrets, tokens, URLs with embedded credentials, or client-confidential data;
redact before writing.

<!-- END: agentic-apps-workflow sections -->

## Code Intelligence

This repo is indexed by GitNexus. To find *where* something lives, query the graph
first — `gitnexus_query` for a concept, `gitnexus_context` for a known symbol,
`gitnexus_impact` before you change one — rather than grepping blind. Fall back to
text search when the graph has no answer or you want a literal string.

<!-- gitnexus:skip -- The generated block is deliberately absent: a background
     `analyze` rewriting it churned this file and collided with the §11 block
     (ADR-0009). The freshness hooks now pass --skip-agents-md. Do not restore
     it by running a bare `gitnexus analyze`. -->

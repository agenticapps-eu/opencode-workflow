---
name: setup-opencode-agenticapps-workflow
version: 0.3.0
implements_spec: 0.4.0
description: |
  Bootstrap a fresh project with the opencode-workflow scaffolding by
  installing the LATEST snapshot directly — no migration replay. Lays
  down the current end-state project-side artifacts (AGENTS.md sections,
  .planning/config.json, .opencode/workflow-config.md, docs/decisions/,
  .opencode/workflow-version.txt) in one shot and stamps the current
  scaffolder version. Use when a project is freshly cloned or
  initialized and the user asks to "set up the workflow", "add
  agenticapps workflow", "enable opencode-workflow", "install the
  discipline layer", "scaffold this project", or anything else that
  means "I want this project to use opencode-workflow from this point
  forward". Idempotent — refuses to re-run on a project that already has
  `.opencode/workflow-version.txt` and routes to
  `$update-opencode-agenticapps-workflow` instead.
---

# setup-opencode-agenticapps-workflow

This skill bootstraps a fresh project with the opencode-workflow
scaffolding. It installs the **latest snapshot** of the project-side
artifacts directly and stamps the current scaffolder version. It does
**not** replay the migration chain.

## Why snapshot, not replay (ADR-0007)

`codex-workflow` (and core spec ADR-0013) route both setup and update
through the same migration files: setup applies `0000-baseline` then
every incremental migration forward. That keeps one code path but means
a brand-new project needlessly re-executes the entire history.

`opencode-workflow` diverges (see `docs/decisions/0007-snapshot-install.md`):

- **Fresh install → snapshot.** Lay down the current end-state from
  `snapshot/` and stamp the latest version. One step, no history.
- **Existing install → migrations.** `$update-opencode-agenticapps-workflow`
  still applies only *pending* migrations (`from_version >` the
  project's installed version) to move a project forward.

The snapshot is kept honest by a drift guard
(`migrations/check-snapshot-parity.sh`): replaying `0000`→latest onto an
empty fixture must produce the same files as `snapshot/`. CI fails if
they diverge, so "skip replay on fresh install" never silently ships a
stale baseline.

## When to invoke

User asks to set up the workflow on a project that does not yet have a
`.opencode/workflow-version.txt` file. The trigger skill
`agentic-apps-workflow` does NOT auto-route to setup — setup is an
explicit, user-driven act because it modifies project-side files
(`AGENTS.md`, `.planning/config.json`, `.opencode/`) the user expects
to review.

## What this skill does

### Stage A — Pre-flight

1. **Verify opencode.** `opencode --version` should succeed (soft check
   — warn but continue if absent; skills are still written to disk).
2. **Verify scaffolder install.** Confirm
   `${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/agentic-apps-workflow/SKILL.md`
   exists. If not, instruct the user to clone opencode-workflow and run
   `bash install.sh` from its root before retrying.
3. **Verify project state.**
   - Project must be a git repo (`test -d .git`).
   - Project must NOT already have `.opencode/workflow-version.txt`. If
     it does, route to `$update-opencode-agenticapps-workflow` and stop.
4. **Resolve scaffolder version.** Read the single source of truth:
   `cat "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/VERSION"`
   (the scaffolder ships `VERSION` at its root; `install.sh` makes it
   resolvable next to the snapshot). Call this `$LATEST`.
5. **Option A vs B.** Detect whether the user wants a global AGENTS.md
   section (`test -w "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/AGENTS.md"`,
   Option A) or a per-project install only (Option B).

### Stage B — Gather placeholder values

6. **Ask the user** the workflow-config questions:
   - Project name (prefill from `package.json::name` /
     `pyproject.toml::project.name` / `Cargo.toml::package.name` /
     repo dir name)
   - Repo URL (autofill `git remote get-url origin`, else prompt)
   - Client (internal / external name)
   - Budget tier (free / paid / enterprise)
   - Backend language
   - Frontend stack (or "none")
   - Database (or "none")
   - LLM provider (anthropic / openai / google / zai / other / none)

   Optional values default if skipped: design-critique bar (90),
   impeccable-audit bar (90), QA viewports (1280, 390), DB blocking
   severity (Critical, High).

### Stage C — Lay down the snapshot (no migration replay)

The snapshot lives at
`${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/snapshot/`.
Resolve it to `$SNAP`. Each step is idempotent (skip if already
present); in interactive mode show the diff before writing.

7. **`.opencode/workflow-config.md`** — `mkdir -p .opencode`, copy
   `$SNAP/workflow-config.md`, substitute every `{{PLACEHOLDER}}` with
   the Stage B values. Fail if any `{{...}}` remains.

8. **`.planning/config.json`** — `mkdir -p .planning`, copy
   `$SNAP/planning-config.json`. This is the **latest** hook config
   (all migrations already folded in), so no incremental edits follow.

8b. **Seed the `knowledge_capture` block (spec §15)** — the vault note
    destination is per-repo config, with `<repo-name>` written out
    literally at config time (never a runtime placeholder). It is NOT
    baked into `$SNAP/planning-config.json` (that snapshot is generic;
    the note path is repo-specific), so seed it here with the repo name
    resolved. Idempotent — skip if the block already exists (a co-installed
    codex/claude host may have seeded it):

    ```bash
    TPL="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/config-knowledge-capture.json"
    if ! jq -e '.knowledge_capture' .planning/config.json >/dev/null 2>&1; then
      REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
      KC="$(jq -c --arg name "$REPO_NAME" \
              '.knowledge_capture.note |= gsub("<repo-name>"; $name) | .knowledge_capture' \
              "$TPL")"
      jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' \
         .planning/config.json > .planning/config.json.tmp \
        && mv .planning/config.json.tmp .planning/config.json
    fi
    ```

    The block is host-neutral (`enabled` + `note` only); `enabled: true`
    by default. A machine without the vault folder is handled at trigger
    time by the skill's graceful skip (spec §15.3) — do NOT create the
    folder here.

9. **`AGENTS.md` workflow section** — if `AGENTS.md` lacks the marker
   pair, insert (at top, after any existing title):

   ```
   <!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
   …contents of $SNAP/agents-block.md…
   <!-- END: agentic-apps-workflow sections -->
   ```

   If the markers already exist, replace the content between them with
   `$SNAP/agents-block.md` (this is also how `update` refreshes the
   section). Never duplicate the block.

10. **`docs/decisions/`** — `mkdir -p docs/decisions`, copy
    `$SNAP/docs-decisions-README.md` to `docs/decisions/README.md` if
    absent.

11. **Global section (Option A only)** — append
    `$SNAP/global-agents-additions.md` to
    `${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/AGENTS.md`. Skip
    entirely for Option B.

12. **Stamp the version** — write `$LATEST` to
    `.opencode/workflow-version.txt`. This is the snapshot's version,
    so the project starts current; `update` will only ever apply
    migrations newer than `$LATEST`.

### Stage D — Post-checks and commit

13. **Post-checks:**
    - `.opencode/workflow-config.md` exists, no unsubstituted `{{...}}`
    - `.planning/config.json` is valid JSON with the expected `hooks`
      keys, and a `knowledge_capture` block whose `note` has the
      `<repo-name>` placeholder resolved (no literal `<repo-name>`)
    - `AGENTS.md` contains exactly one `BEGIN/END: agentic-apps-workflow`
      marker pair, and the body contains the §11 "Coding Discipline"
      heading (proves the latest snapshot, not the v0.1.0 baseline) and
      the "Knowledge Capture — Ritual Tail (spec §15)" heading
    - `docs/decisions/README.md` exists
    - `.opencode/workflow-version.txt` reads `$LATEST`

14. **Atomic commit:**

    ```bash
    git add .opencode/ .planning/ AGENTS.md docs/decisions/
    git commit -m "chore: install opencode-workflow v$LATEST (snapshot)"
    ```

15. **Surface follow-ups:**
    - Project is now at `opencode-workflow v$LATEST`
     - Next: `/gsd-discuss-phase 1` to start the first phase
    - Future updates: `$update-opencode-agenticapps-workflow` reads
      `.opencode/workflow-version.txt` and applies pending migrations

## Required evidence (per spec/06)

- `.opencode/workflow-version.txt` exists, content == scaffolder `VERSION`
- `.planning/config.json` valid JSON with all `hooks` keys
- `AGENTS.md` has the marker pair and the §11 heading inside it
- `docs/decisions/README.md` exists
- The atomic commit is on the current branch with the expected files

## Failure modes

- **Re-running on an installed project.** Pre-flight catches the version
  file; never auto-overwrite. Route to `$update-opencode-agenticapps-workflow`.
- **Scaffolder not installed.** Surface the install path; do not write
  partial artifacts.
- **Unsubstituted placeholder.** Post-check fails the install rather
  than committing a `{{...}}`.
- **Stale snapshot.** Not possible to ship silently: the drift guard
  (`check-snapshot-parity.sh`) fails CI if `snapshot/` ≠ replay(0000→latest).

## Notes for the opencode host

- Default config dir is `~/.config/opencode`; honor `$OPENCODE_CONFIG_DIR`.
- opencode auto-discovers skills under `~/.config/opencode/skills`,
  `~/.claude/skills`, and `~/.agents/skills`; `install.sh` targets the
  first.
- opencode loads `~/.config/opencode/AGENTS.md` (home) plus
  `<repo>/AGENTS.md` (project) at session start — the same root-down
  concat Codex uses, so the workflow section is picked up natively.

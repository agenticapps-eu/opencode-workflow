<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Development Workflow

This project uses the AgenticApps spec-first workflow on the OpenAI
opencode host. The trigger skill `agentic-apps-workflow` activates
on every code-touching task and emits the canonical commitment
ritual before any tool call. See
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
for the spec, [`opencode-workflow`](https://github.com/agenticapps-eu/opencode-workflow)
for the host-specific binding.

The version of `opencode-workflow` this project was set up against is
recorded at `.opencode/workflow-version.txt`.

## Workflow Enforcement Hooks (MANDATORY)

The `agentic-apps-workflow` trigger skill binds every spec/02 gate
to a `opencode-*` skill. Project-specific gate bindings live in
`.planning/config.json`. Do not bypass a gate — accept-via-ADR is
the override path.

| Gate | Bound skill | Scope |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `opencode-brainstorming` | pre-phase |
| design-shotgun | `opencode-design-shotgun` | pre-phase |
| design-critique | `opencode-design-critique` | pre-phase |
| tdd | `opencode-tdd` | per-task |
| ui-preview | `opencode-qa` (preview mode) | per-task |
| verification | `opencode-verification` | per-task |
| spec-review | `opencode-spec-review` | post-phase |
| code-review | `opencode-code-review` | post-phase |
| security | `opencode-cso` | post-phase |
| database-security | `opencode-database-sentinel-audit` | post-phase |
| qa | `opencode-qa` | post-phase |
| impeccable-audit | `opencode-impeccable-audit` | post-phase |
| db-pre-launch-audit | `opencode-database-sentinel-audit` | finishing |
| branch-close | `opencode-finishing-branch` | finishing |

## Skill routing

For any task, route through the trigger skill's task-size table:

- **Tiny** (typo, comment, README) → `opencode-verification`
- **Small** (single-file logic) → `opencode-tdd` → `opencode-verification` → `opencode-finishing-branch`
- **Medium** (multi-file feature) → `$gsd-discuss-phase` → `$gsd-plan-phase` → `$gsd-execute-phase`
- **Large** (cross-cutting) → same as medium plus `opencode-cso`,
  `opencode-database-sentinel-audit`, `opencode-impeccable-audit` per
  applicable gates

Bug reports route through `$gsd-debug` (the four-phase
Observe → Hypothesize → Test → Conclude protocol).

## Session handoff

At the start of every session, check for `session-handoff.md` in
the project root. If it exists and was modified in the last 7
days, read it before doing anything else and confirm what was
found.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write a
`session-handoff.md` in the project root. Format:

```markdown
# Session Handoff — YYYY-MM-DD

## Accomplished
- ...

## Decisions
- decision — why

## Files modified
- path — what changed

## Next session: start here
One paragraph on exactly where to pick up and what the first
action should be.

## Open questions
- ...
```

Keep it under 150 lines. Write the file directly — do not print
it to the terminal. This file survives session boundaries and is
the primary continuity mechanism across sessions.

<!-- END: agentic-apps-workflow sections -->

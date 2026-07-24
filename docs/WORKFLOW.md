# The AgenticApps Workflow on opencode (v1 — OpenSpec + Superpowers)

*An explainer for the opencode host. This is orientation, not a contract.
The normative text lives in the `agenticapps-workflow-core` spec (§16–§19)
and its ADR-0021; this file tells you how the pieces fit on opencode and
where the concrete commands, plugins, and paths are.*

## One sentence

Product work moves through an **OpenSpec change** — propose it with
`/opsx:propose`, validate and multi-AI review it *before* writing code,
execute it with **Superpowers** discipline (TDD, evidence, independent
review), then `/opsx:archive` it into the durable spec and ship — while a
`tool.execute.before` plugin refuses to let you edit code until the change
has validated and been reviewed.

## The two layers

The workflow has two layers, and v1 keeps one and replaces the other.

- **Execution discipline — Superpowers (kept).** The commitment ritual,
  the rationalization table, the red flags, the pressure test, TDD,
  on-disk evidence, and independent code review. On opencode these come
  from the upstream `obra/superpowers` plugin (see `docs/BINDING.md`), not
  from hand-authored `opencode-*` copies. This is the machinery that stops
  an agent under deadline pressure from rationalizing its way out of tests
  and reviews.
- **Planning discipline — OpenSpec (new, replacing the GSD engine).**
  Instead of `.planning/` phases that record *how the product was built*,
  an **OpenSpec spec slot** records *what the product guarantees now*, and
  changes are proposed and validated against it.

## The spec slot (§16)

`openspec init --tools opencode --profile core` (the OPSX **Core**
profile, from `@fission-ai/openspec` v1.6.0+) generates the slot into the
target project. It holds three things with three lifespans:

```
openspec/
  config.yaml            # schema: spec-driven
  specs/                 # durable current truth — one spec.md per capability
    analysis-pipeline/
      spec.md            #   what the pipeline guarantees TODAY
  changes/               # in-flight deltas — proposed, not yet true
    add-model-to-log/
      proposal.md  design.md  <delta>  tasks.md  REVIEWS.md
  changes/archive/       # history — shipped changes, dated
    2026-07-24-add-model-to-log/
```

To learn what the system does, read `specs/`. To see what's being
changed, read `changes/`. To see how a requirement came to be, read
`changes/archive/`. A change is **done** when its delta is folded into
`specs/` **and** `openspec validate --all` is green.

The same `init` drops six `opsx` slash commands into the project's local
`.opencode/` — `/opsx:propose`, `/opsx:apply`, `/opsx:archive`,
`/opsx:explore`, `/opsx:sync`, `/opsx:update` — plus the `openspec-*`
skills. There is **no** `/opsx:validate` command: validation is the
`openspec validate --all` CLI, which the change-gate calls.

**Bind-upstream (§16).** The OpenSpec CLI *generates* this whole opsx
surface; `opencode-workflow` does not vendor or hand-author it. The
installed CLI is authoritative — where its file names or command shapes
differ from any prose here, the CLI wins.

## The lifecycle (§17)

```
   propose ─────▶ validate ─────▶ Superpowers-execute ─────▶ archive
   (/opsx:propose (validate green   (TDD, evidence,            (/opsx:archive
    — proposal +   AND ≥2-reviewer   independent code review,   folds delta
    design +       multi-AI review   security/design/db/qa/     into specs/)
    delta +        BEFORE code)      lint gates as triggered)       │
    tasks)                                                          ▼
                                                              ship (git)
```

Two things about this picture matter most:

1. **Review happens before code.** The old `plan-review` and
   `spec-review` gates collapse into the **validate** stage: `openspec
   validate --all` checks the delta against the spec slot, and the
   `opencode-openspec-change-review` skill has ≥2 distinct external-vendor
   reviewer CLIs (gemini + codex, via `bin/reviewer-cli.sh`, each wrapped
   `</dev/null` + timeout) adversarially review the *proposed change*
   before a line of implementation exists. That review is the retargeted
   0.x plan-review — but under v1 it is **not** a standalone gate; it is
   stage 2, enforced by the change-gate below.
2. **`archive ≠ ship`.** `/opsx:archive` folds the delta into `specs/` —
   a spec-slot operation that produces no commit. Shipping is the separate
   git step, gated by branch-close / the PR.

### What happened to the old gates (§17 mapping)

| Old gate | Now |
|---|---|
| `plan-review`, `spec-review` | **collapse into `validate`** (review before code) |
| `code-review` | **retained** — validate doesn't read code |
| `tdd`, `verification` | **retained** — Superpowers execution |
| `security` | **retained, always** on triggering changes |
| design / database / qa / impeccable | **conditional** — fire on their triggers |
| `ts-declare` | **→ CI lint gate** |

`impeccable` and any Go skills stay behind the ADR-0021 measured trial —
not promoted into the always-on set until the data supports it.

## The gate that enforces it (§18)

On opencode the §18 change-gate is a plugin at
`~/.config/opencode/plugin/openspec-change-gate.ts`, hooking
`tool.execute.before` and **throwing** to block a code-editing tool call.
The plugin is thin: it delegates to the host-agnostic script
`~/.agenticapps/bin/openspec-change-gate.sh`, which is the real
enforcement surface. The gate's decision is that script's exit code:

- no active change → **allow** (0)
- writing under `openspec/**` (the change itself) → **allow, exempt** (0)
- active change, validate green + `REVIEWS.md` with ≥2 `## Reviewer:`
  headings → **allow** (0)
- active change lacking *either* a green `openspec validate --all` *or* the
  ≥2-reviewer `REVIEWS.md` → **block** (2)
- escape hatch `GSD_SKIP_REVIEWS=1` → allow (0)
- garbage stdin → allow (fail-open)

**Floor.** A plugin loads at session start, so it cannot gate the very
session that installed it. That gap is covered by a **floor**: a git
pre-commit hook and CI both call the *same* `openspec-change-gate.sh`, so
even the installing session — and anything that bypasses the TUI — is
still gated at commit and in CI.

## Where prose lives (§19)

Once a spec slot exists, ask of any line: **is this a product guarantee,
or a way of working?**

- **Product guarantee** (a scoring weight, an API field, an access rule) →
  the **spec slot** (`openspec/specs/`), as a requirement.
- **Way of working** (use TDD, run the security gate, boot the dev server
  before a screenshot) → the **instruction file** (`AGENTS.md`), as
  process.
- **Record of past effort** (the phases that built it) →
  **`docs/legacy-planning/`**, as history — moved, never deleted.

The roadmap stays in **Linear**, coupled loosely — a change *should*
reference a Linear ID for traceability, but nothing syncs and nothing
requires it.

## Adopting it — and this repo's own role

`opencode-workflow` is the **scaffolder**: it ships this workflow *onto*
opencode via `install.sh` plus the setup/update skills, and packages the
migration recipe for target repos. A target repo adopts v1 by applying
`recipe 0001` (planning → OpenSpec), which reconstructs `specs/` from an
existing `.planning/` tree and wires the change-gate.

This repo does **not** migrate itself with recipe 0001 — its own
`.planning/` history stays intact as a guardrail. The recipe is packaged
here to run *elsewhere*, not turned on the scaffolder.

## Further reading

- `agenticapps-workflow-core` spec §16–§19 — the normative contracts.
- `agenticapps-workflow-core` ADR-0021 — why, and what it supersedes.
- `docs/BINDING.md` — how opencode binds to upstream GSD + Superpowers.
- `docs/ENFORCEMENT-PLAN.md` — the gate/floor implementation on opencode.

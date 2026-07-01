# Port plan — GSD + gstack + superpowers → opencode

> **⚠️ SUPERSEDED by `docs/BINDING.md`.** We chose to **bind** to the upstream
> opencode ports (GSD via `npx gsd-opencode`, Superpowers via the `opencode.json`
> plugin) instead of re-porting. The `gsd-*` forks and the Superpowers-duplicate
> `opencode-*` gates have been removed; their gate bindings now point at the
> upstream skills. Only the AgenticApps + gstack-only gates remain in this repo.
> This document is kept for the capability-parity analysis below, but the
> "author the missing skills / wrap the CLI" actions are no longer the plan —
> upstream provides them.

## TL;DR — most of this is already done

The opencode fork re-authored the **capabilities** of superpowers and gstack as
native `opencode-*` SKILL.md skills when it was forked from codex-workflow. So
"porting" is **not** re-implementing them. What remains is:

1. A few **missing skills** (worktrees, subagent-driven dev, browse).
2. The **CLI / slash-command glue** (GSD runtime + `/gsd-*` commands, gstack CLI
   umbrella) re-expressed for opencode's `commands/` + skill model.
3. **Wiring + verification** (GSD runtime reachable; phase-dir convention — done
   in the cross-host reconciliation).

> Source caveat: superpowers (`~/.claude/plugins/.../superpowers`), gstack
> (`~/.claude/skills/gstack`), and GSD (`~/.claude/get-shit-done`) live under the
> protected `~/.claude` and can't be mounted. The parity below is derived from
> how `claude-workflow` *references* them. For exact file-level diffs of the
> plugin/CLI internals, copy those three dirs into a mounted folder (e.g.
> `workflow-testbed/_vendor/`) and I'll produce per-file steps.

---

## 1. superpowers → opencode (capability parity)

| superpowers skill | opencode equivalent | status |
|---|---|---|
| `brainstorming` | `opencode-brainstorming` | ✅ done |
| `writing-plans` | `gsd-plan-phase` | ✅ done |
| `executing-plans` | `gsd-execute-phase` | ✅ done |
| `test-driven-development` | `opencode-tdd` | ✅ done |
| `systematic-debugging` | `opencode-systematic-debugging` | ✅ done |
| `verification-before-completion` | `opencode-verification` | ✅ done |
| `requesting-code-review` | `opencode-code-review` | ✅ done |
| `finishing-a-development-branch` | `opencode-finishing-branch` | ✅ done |
| `using-git-worktrees` | — | ❌ **GAP** — author `opencode-worktrees` |
| `subagent-driven-development` | partial (`opencode-code-review` spawns `opencode run`) | ⚠️ **GAP** — author `opencode-subagent` or fold into a skill |

**Port work:** author the two missing skills. They're host-agnostic discipline
skills (git worktree mechanics; subagent/child-process delegation) — write them
as `skills/opencode-worktrees/SKILL.md` and `skills/opencode-subagent/SKILL.md`,
mirroring the superpowers prose but using opencode's subagent mechanism
(`opencode run` child process, already used by `opencode-code-review`).

---

## 2. gstack → opencode (gate parity)

gstack is the umbrella that ships the gate skills. Its gates are already
re-authored:

| gstack gate | opencode equivalent | status |
|---|---|---|
| `gstack:cso` | `opencode-cso` | ✅ done |
| `gstack:review` | `opencode-code-review` + `opencode-spec-review` | ✅ done |
| `gstack:qa` | `opencode-qa` | ✅ done |
| `gstack:design-shotgun` | `opencode-design-shotgun` | ✅ done |
| `gstack:browse` | — | ❌ **GAP** — see below |
| gstack CLI umbrella (`gstack <cmd>`, `gstack-upgrade`, `gstack/VERSION`) | — | ⚠️ glue |
| `gstack/security-reports/` output | `opencode-cso` writes reports? verify | ⚠️ verify |

**Port work:**
- `gstack:browse` is a web/preview capability. Decide: re-home as
  `skills/opencode-browse/SKILL.md` driving opencode's browser/preview path, or
  drop if `opencode-qa` preview already covers it.
- The gstack **CLI** is host-agnostic — it operates on the repo. Two options:
  (a) keep gstack as an external dependency and call `gstack <cmd>` from bash
  inside opencode skills (lightest), or (b) re-home its command surface as
  opencode `commands/gstack-*.md`. Recommend (a) first; only re-home if you want
  opencode self-contained.
- Confirm where security reports land (`opencode-cso` should write the
  `gstack/security-reports/`-equivalent).

---

## 3. GSD → opencode (lightest — already opencode-aware)

GSD is `~/.claude/get-shit-done/`: a Node runtime (`bin/gsd-tools.cjs`),
`workflows/` (execute-plan, review), `commands/` (the `/gsd-*` slash commands),
`templates/`.

| GSD piece | opencode status | work |
|---|---|---|
| Entry skills (discuss/plan/execute/debug/quick) | ✅ in `skills/gsd-*` | none (phase-dir convention reconciled) |
| Runtime `gsd-tools.cjs` | host-agnostic Node | install + ensure on PATH for opencode to shell out |
| `/gsd-*` slash commands | Claude commands | re-express as opencode `commands/gsd-*.md` |
| `gsd-patches` (survives `gsd update`) | already opencode-aware | apply: `patches/workflows/review.md` strips `2>/dev/null` from `opencode run` |
| Reviewer integration | **already supports opencode** | `/gsd-review-opencode-*` exists; GSD calls `opencode run` as a reviewer CLI |

**Key finding:** GSD is already opencode-aware — `claude-workflow` carries
`/gsd-review-opencode-*` commands and a gsd-patch that fixes `opencode run`
output handling. So GSD treats opencode as a first-class reviewer CLI today.

**Port work:** (1) ensure `gsd-tools.cjs` is installed and on PATH; (2) port the
`/gsd-*` slash commands to opencode `commands/`; (3) ship the `gsd-patches`
`bin/sync`+`bin/check` so the opencode-run fix survives `gsd update`; (4) phase
dir convention — **done**.

---

## Suggested order

1. **GSD glue** (smallest, highest leverage): install runtime, port `/gsd-*` →
   `commands/`, ship gsd-patches. Everything else routes through GSD.
2. **superpowers gaps**: `opencode-worktrees`, `opencode-subagent`.
3. **gstack**: wrap the CLI (option a) + decide on `opencode-browse`.

## What I need to go file-level

Copy these into a mounted folder and I'll produce exact per-file ports:
- `~/.claude/get-shit-done/` (runtime + commands + workflows)
- `~/.claude/skills/gstack/` (CLI + gate sources)
- `~/.claude/plugins/.../superpowers/` (the two gap skills' originals)

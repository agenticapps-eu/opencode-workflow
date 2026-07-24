# opencode-workflow as a binding (not a re-port)

As of this change, `opencode-workflow` no longer re-implements GSD or
Superpowers for opencode. It **binds** to the maintained upstream opencode
ports and ships only the genuinely-AgenticApps layer on top.

## Why

GSD and Superpowers already support opencode and move fast (GSD ≈48k★ upstream,
Superpowers ≈124k★). Re-authoring them as `opencode-*`/`gsd-*` skills meant
tracking two upstreams by hand. `claude-workflow` was never a re-port either —
it consumes public GSD (`~/.claude/get-shit-done`) + the Superpowers plugin and
adds the AgenticApps glue. This change makes the opencode host symmetric.

## The three layers

| Layer | Source | How it's installed |
|---|---|---|
| **GSD** (discuss/plan/execute/verify, `/gsd-*`, model profiles) | [`rokicool/gsd-opencode`](https://github.com/rokicool/gsd-opencode) (tracks TÂCHES upstream) | `npx gsd-opencode --global` |
| **Superpowers** (TDD, brainstorming, code-review, verification, finishing-branch, systematic-debugging, worktrees, subagents) | [`obra/superpowers`](https://github.com/obra/superpowers) | `plugin` entry in `opencode.json` |
| **AgenticApps** (spec-first trigger, gstack gates, spec/QA/DB/security gates, snapshot install) | this repo | `bash install.sh` + `$setup-opencode-agenticapps-workflow` |

## What this repo still ships (the AgenticApps layer)

- `agentic-apps-workflow` — the spec-first trigger/router.
- gstack + AgenticApps gates with **no GSD/Superpowers equivalent**:
  `opencode-cso`, `opencode-qa`, `opencode-design-shotgun`,
  `opencode-design-critique`, `opencode-database-sentinel-audit`,
  `opencode-impeccable-audit`, `opencode-spec-review`,
  `opencode-ts-declare-first`.
- `setup-` / `update-opencode-agenticapps-workflow` + the snapshot install.

What was **removed** (now provided by upstream): the `gsd-*` skills (GSD) and
`opencode-brainstorming`, `opencode-code-review`, `opencode-finishing-branch`,
`opencode-verification`, `opencode-tdd`, `opencode-systematic-debugging`
(Superpowers). Gate bindings for these now point at the upstream skills.

## Model routing — GLM 5.2 via opencode Zen

GLM 5.2 is reached through **opencode Zen** (the managed gateway), not a custom
z.ai provider. Zen serves it under the built-in id **`opencode/glm-5.2`**
(endpoint `https://opencode.ai/zen/v1/chat/completions`). So `opencode.json`
provides only:

- `"model": "opencode/glm-5.2"` (the Zen id),
- the Superpowers `plugin` entry.

**Auth (this is what causes "token expired or incorrect"):** the Zen key is not
a z.ai key and must be registered through opencode's auth, *not* an env var:

```bash
opencode auth login        # choose "OpenCode Zen", paste the key from https://opencode.ai/auth
#   or, inside the TUI:  /connect  -> OpenCode Zen -> paste key
```

Do **not** put the Zen key in `ZAI_API_KEY` and do **not** point the model at a
`zai-coding-plan` provider — that routes to `api.z.ai`, which rejects the Zen
token. (BYO z.ai Coding Plan is a *different* path: a `zai-coding-plan` provider
with `baseURL https://api.z.ai/api/coding/paas/v4` + a real z.ai key in
`ZAI_API_KEY`, model `zai-coding-plan/glm-5.2`. Use one or the other.)

**GSD + model routing.** GSD-opencode can manage per-stage model profiles
(`/gsd-set-profile`) and write `agent` keys into `opencode.json`. When its
preset wizard runs `opencode models`, pick **`opencode/glm-5.2`** for the
stages. Re-check that `plugin`/`mcp`/`model` survived GSD's generation.

## Install order

```bash
# 1. AgenticApps layer (skills + slash commands + this repo)
bash install.sh                      # symlinks skills AND commands into ~/.config/opencode
#   -> gives you /setup-agenticapps-workflow and /update-agenticapps-workflow
#   restart opencode so the TUI picks up the new commands

# 2. GSD (model routing + /gsd-* commands)
npx gsd-opencode --global            # installs to ~/.config/opencode/
#   then inside opencode: /gsd-set-profile  -> pick GLM 5.2 for the stages

# 3. Superpowers (already in opencode.json `plugin`) — restart opencode to load
#    verify: ask opencode "tell me about your superpowers"

# 4. Per-project: /setup-agenticapps-workflow            (snapshot install)
#    (or just tell opencode: "set up the AgenticApps workflow" — the skill
#     triggers by description once installed)
```

> **Note:** `setup-opencode-agenticapps-workflow` is a *skill*, not a slash
> command — opencode invokes skills via its skill tool / natural language, not
> as `/…`. The `/setup-agenticapps-workflow` and `/update-agenticapps-workflow`
> **commands** (in `commands/`, installed by `install.sh`) are thin wrappers
> that invoke those skills, giving you the familiar `/name` entry point like
> GSD's `/gsd-*`.

## Open verification

- GSD-opencode's `.planning/` phase-dir layout vs `claude-workflow`'s
  `NN-slug/` — both descend from TÂCHES GSD, so they likely match, but confirm
  before relying on cross-host plan portability.
- Whether GSD's `opencode.json` generation preserves `plugin`/`mcp`/`provider`.

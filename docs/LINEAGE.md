# Lineage

`opencode-workflow` is a host fork of
[`codex-workflow`](https://github.com/agenticapps-eu/codex-workflow),
the OpenAI Codex CLI binding of the host-agnostic
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
spec.

## The binding layer (what the fork changes)

| Concern | codex-workflow | opencode-workflow |
|---|---|---|
| Skill install root | `~/.codex/skills` | `~/.config/opencode/skills` |
| Project marker dir | `.codex/` | `.opencode/` |
| Env var | `CODEX_HOME` | `OPENCODE_CONFIG_DIR` |
| Host instructions | `AGENTS.md` | `AGENTS.md` (opencode reads it natively) |
| Model / MCP wiring | Codex `config.toml` | `opencode.json` |
| Skill prefix | `codex-*` | `opencode-*` |
| Independent reviewer | `codex exec` | `opencode run` |
| Fresh install | replays migration chain | snapshot install (see `docs/decisions/0007`) |
| GSD / Superpowers | re-ported as `codex-*`/`gsd-*` skills | **bound to upstream** (gsd-opencode + Superpowers plugin) — see `docs/BINDING.md` |

> **Binding update:** the `gsd-*` forks and the Superpowers-duplicate gates
> (`opencode-{brainstorming,code-review,finishing-branch,verification,tdd,systematic-debugging}`)
> were removed and now bind to upstream. Only the AgenticApps spec-first trigger
> and the gstack-only gates (`opencode-{cso,qa,design-shotgun,design-critique,database-sentinel-audit,impeccable-audit,spec-review,ts-declare-first}`)
> remain custom in this repo.

## Inherited provenance

`docs/decisions/0001`–`0006`, `CHANGELOG.md`, and `.planning/phases/**`
are inherited verbatim from `codex-workflow` and describe the **Codex**
host reasoning and build history. They are kept as provenance. Where
opencode diverges, a newer ADR (starting at `0007`) supersedes them.

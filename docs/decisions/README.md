# Architecture decision records

ADRs for `opencode-workflow`. Numbered sequentially: `NNNN-slug.md`.

The shape follows the AgenticApps workflow's ADR convention —
status, date, context, decision, consequences, references.

When an `opencode-database-sentinel-audit` finding is accepted rather
than fixed (in projects USING this scaffolder), the accepting ADR
uses the
[`adr-db-security-acceptance.md`](../../skills/setup-opencode-agenticapps-workflow/templates/adr-db-security-acceptance.md)
template shape — risk owner, re-audit date, compensating controls.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-codex-skill-naming.md) | Codex skill naming, layout, and packaging | Accepted |
| [0002](0002-stage2-independent-reviewer-on-codex.md) | Stage 2 independent reviewer mechanism on Codex | Accepted |
| [0003](0003-gsd-entry-points-as-prompts.md) | GSD entry points are skills, not prompts | Accepted |
| [0004](0004-observability-strategy.md) | §10 observability — delegate to agenticapps-observability via a Codex installer | Accepted |
| [0005](0005-adopt-observability-architecture.md) | Adopt core ADR-0014 observability architecture (generator layer via delegation) | Accepted |
| [0006](0006-secret-scanner-gitleaks.md) | Secret scanner: stay on gitleaks (adopt core ADR-0015) | Accepted |
| [0007](0007-snapshot-install.md) | Fresh installs use a snapshot, not migration replay | Accepted |
| [0008](0008-knowledge-capture.md) | Knowledge capture ritual tail — spec §15 on the opencode host | Accepted |
| [0009](0009-region-aware-spec-11-placement.md) | §11 is anchored region-aware: first `## ` or `gitnexus:start`, whichever comes first | Accepted |

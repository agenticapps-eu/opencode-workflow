# ADR-0011: Re-vendor the §18 change-gate from core's reference implementation

**Status**: Accepted  **Date**: 2026-07-25  **Linear**: — (repo issue #15; core #32/#33/#34)

## Context

This host shipped its own hand-authored `bin/openspec-change-gate.sh` (164 lines).
Core then published the §18 change-gate as a normative **reference
implementation** (`agenticapps-workflow-core` PR #33 / ADR-0022, merged as
`ae90483`) plus an executable conformance harness
(`tools/change-gate-conformance.sh`). Scored against that harness, this host's copy
was **16/28** — every failure an *under-enforcement* (returns allow where §18
requires block), so none surfaced as friction:

- `--pre-commit` / `--ci` modes were unrecognized → fell through to hook mode →
  fail-open → **the git pre-commit and CI floors enforced nothing**.
- the `openspec/` exemption matched any path containing `openspec/`
  (`src/openspec/…`, `/tmp/openspec/…`, `..`-escape all slipped through);
- reviewer counting accepted duplicates, fenced examples, YAML `reviewers:`, and a
  host's own `## Reviewer: <self>` headings;
- `GSD_SKIP_REVIEWS=1` + a RED validate wrongly allowed.

Filed as this repo's issue #15 and core #32/#34. The prescribed remedy is
explicit: **re-vendor from core, do not hand-patch** — five copies diverged
precisely because each host fixed its own.

## Decision

Vendor core's gate **logic** byte-for-byte and keep only thin opencode wiring
host-local, injecting host config through the environment (never by editing a
vendored file):

- **Byte-identical from core `ae90483`**: `bin/openspec-change-gate.sh`
  (gate-version 1.2.0) and `tools/change-gate-conformance.sh`.
- **Host-local wiring** (explicitly not byte-identical): the opencode
  `tool.execute.before` plugin (`bin/openspec-change-gate.ts`), `bin/reviewer-cli.sh`,
  the `bin/git-hooks/pre-commit` wrapper (converged to core's `--pre-commit` mode),
  and `.github/workflows/openspec-gate.yml` (adapted to this repo's action
  versions and paths).
- `OPENSPEC_GATE_SELF=opencode` is exported at each invocation point (plugin spawn
  env, pre-commit, CI job env) so this host's own reviews do not count.
- `install.sh` gained `# gate-version:` arbitration: before writing the shared
  `~/.agenticapps/bin/openspec-change-gate.sh` it refuses to downgrade (installed
  `>=` incoming → keep; installed `<` incoming → replace; unmarked/malformed →
  `0.0.0`; a portable pure-bash comparator, since macOS `sort` lacks `-V`).

Result: the vendored gate scores **28/28**; `run-tests.sh` (131 PASS/1 SKIP,
including the §18 truth-table suite) and `check-snapshot-parity.sh` stay green.

## Alternatives Rejected

- **Hand-patch the 164-line gate to 28/28.** The exact anti-pattern #32/#34/#15
  name; re-vendoring is a one-way consume of upstream (§16), not a fork.
- **Adopt only the enforcement-floor fix, defer the rest.** Leaves reviewer and
  exemption bypasses under a second PR and re-introduces a hand-authored
  divergence; vendoring the whole file lands at 28/28 in one step.
- **Rename the wrapper to core's `bin/pre-commit`.** Churns `install.sh`, the
  setup-skill snapshot, and the parity guard for zero conformance benefit; the
  wrapper resolves the gate by path fallback, so the filename is immaterial.

## Consequences

- This host stops owning gate *logic*; upgrades are a re-vendor + harness re-run,
  not a review of bespoke bash. `bin/openspec-change-gate.ts` and the
  `opencode-openspec-change-review` producer must stay in lockstep with core's
  reviewer-count format (`## Reviewer: <name>`, matched case-insensitively).
- The installer's downgrade-refusal removes *this* host as a source of silent
  downgrades at the shared path. It does **not** by itself make a mixed-version
  machine converge upward — a co-installed host whose installer lacks the same
  arbitration can still overwrite the path. Fleet-wide monotonicity is tracked in
  core#34.
- **Deviation inherited from core** (pinned by a harness row, not a local choice):
  `GSD_SKIP_REVIEWS` is applied *after* the validate check, so a RED validate plus
  the hatch still blocks. Documented in core's gate README §Deviations.

## References

- Repo issue #15; core #32 (defect), #33 / ADR-0022 (reference impl), #34 (fleet
  adoption tracker).
- The change: `openspec/changes/archive/*-revendor-openspec-change-gate/`.
- Supersedes this host's hand-authored gate introduced with [0010].

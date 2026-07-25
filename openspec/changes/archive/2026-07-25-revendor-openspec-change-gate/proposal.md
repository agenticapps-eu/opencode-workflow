## Why

Core published the §18 change-gate as a normative reference implementation
(`agenticapps-workflow-core` PR #33 / ADR-0022, merged to `main` as `ae90483`),
plus an executable conformance harness (`tools/change-gate-conformance.sh`).
Hosts are now expected to **vendor** that file, not maintain their own.

This host still ships its own hand-authored `bin/openspec-change-gate.sh`
(164 lines). Scored against core's harness it is **16/28** — every failure is
*under-enforcement* (returns `0`/allow where §18 requires block), so none of it
surfaces as friction. The material defects:

- **The agent-agnostic floor is a no-op.** `--pre-commit` and `--ci` are
  unrecognized: they fall through to hook mode, read empty stdin, parse no path,
  and fail-open to `0`. §18 makes the shell script the real enforcement surface
  ("including against a human editor"); today this host's git pre-commit hook and
  CI floor enforce nothing.
- **`openspec/` exemption too broad** — `src/openspec/`, `/tmp/openspec/`, and a
  `..`-escape all wrongly count as artifact writes, so real code under such a path
  slips through.
- **Reviewer counting is loose** — duplicate reviewer headings, fenced examples,
  and YAML `reviewers:` all miscount; two `## Reviewer: <self>` headings satisfy a
  threshold of 2 (the §02 evidence verifier rejects exactly this).
- **`GSD_SKIP_REVIEWS=1` + `validate` RED wrongly allows.**

Filed as this repo's issue #15 and core #32/#34. The prescribed remedy is
explicit: **re-vendor from core, do not hand-patch** — host-local fixes are how
five divergent copies happened in the first place.

## What Changes

- Vendor core's `reference-implementations/openspec-change-gate/openspec-change-gate.sh`
  (gate-version 1.2.0) verbatim into `bin/openspec-change-gate.sh`, replacing the
  hand-authored copy.
- Vendor core's conformance harness `tools/change-gate-conformance.sh` (CI runs it
  against the vendored gate; a stale harness certifies a stale gate).
- Vendor core's `pre-commit` wrapper content so the git floor actually dispatches
  `--pre-commit` and blocks.
- Add the CI enforcement floor: an `openspec-gate` workflow that (a) proves the
  gate is conformant via the harness, then (b) runs `--ci` over open changes.
- Set `OPENSPEC_GATE_SELF=opencode` at every invocation point (plugin, pre-commit,
  CI) so this host's own reviews are excluded from the threshold.
- Teach `install.sh` to honour the `# gate-version:` marker at the shared
  `~/.agenticapps/bin/openspec-change-gate.sh` path and **refuse to downgrade** —
  this host's part of closing issue #15's cross-host propagation hazard. It makes
  *this* installer non-downgrading; machine-wide monotonicity requires every host
  to adopt the same arbitration (tracked in core#34), so the claim is scoped
  honestly rather than over-stated.
- Keep the thin per-host wiring unchanged: the opencode `tool.execute.before`
  plugin (`bin/openspec-change-gate.ts`) and `bin/reviewer-cli.sh`.

Target: the vendored gate scores **28/28** on the harness; `run-tests.sh` §18
truth-table suite and `check-snapshot-parity.sh` stay green.

## Capabilities

### Modified Capabilities
- `opencode-workflow-scaffold`: the change-gate requirement is strengthened — the
  reviewer count must be of *independent, de-duplicated, non-example* reviewers,
  and the gate is now vendored-from-core (not hand-authored) with an installer
  that refuses to downgrade the shared copy. A new requirement adds the
  agent-agnostic enforcement floor (`--pre-commit` / `--ci` must actually block).

## Impact

- `bin/openspec-change-gate.sh` (replaced), `tools/change-gate-conformance.sh`
  (new), `bin/git-hooks/pre-commit` (content from core), `.github/workflows/`
  (new gate workflow + syntax-check list), `install.sh` (gate-version
  arbitration + `OPENSPEC_GATE_SELF`), `bin/openspec-change-gate.ts` (pass
  `OPENSPEC_GATE_SELF`).
- Behavioural: edits/commits/CI that previously slipped through now block
  correctly. No currently-legitimate flow is newly blocked (all deltas are
  allow→block on inputs §18 already required to block).
- Cross-host: this host's installer will no longer *itself* downgrade the shared
  gate, and upgrades it when it ships a newer one. It cannot prevent another
  host's non-arbitrating installer from overwriting the path later — machine-wide
  monotonicity lands only when every host adopts this arbitration (core#34).

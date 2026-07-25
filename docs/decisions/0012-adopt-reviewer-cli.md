# ADR-0012: Adopt core's reviewer-cli 1.0.0 as a vendored shared artifact

**Status**: Accepted  **Date**: 2026-07-25  **Linear**: — (core #41 defect / #42 reference impl)

## Context

`bin/reviewer-cli.sh` is the defensive wrapper the §18 review *producer*
(`opencode-openspec-change-review`) calls once per vendor. It is installed at one
shared path, `~/.agenticapps/bin/reviewer-cli.sh`, written by the
claude / codex / opencode / pi installers alike. [ADR-0011](0011-revendor-change-gate.md)
classified this file as **host-local wiring, "explicitly not byte-identical"** —
correct at the time, because core shipped no canonical wrapper.

Core #41 changed that. Three divergent host copies existed at the one shared path
with no arbitration (codex: 4 arms; pi: 3; opencode: 2; claude: none). On
2026-07-25 a host installer delivered the correctly-arbitrated `1.2.2` change
gate and, **in the same run**, blind-installed a 3-arm wrapper over the 4-arm one
— because the wrapper, unlike the gate, carried no `# reviewer-cli-version:`
marker to arbitrate on. The next review that asked for `opencode` got
`unknown vendor`, was recorded as "reviewer unavailable", and §18 proceeded with
one fewer opinion. Core then published the wrapper as a normative reference
implementation at `# reviewer-cli-version: 1.0.0` (core #42, `60cd83f`), a
**merge** of pi's structure with codex's coverage, plus a conformance harness.

This host still shipped the 2-arm copy — scored **9/14** against core's harness
(missing `claude`+`opencode` arms, no version marker) and, worse, installed it
**unconditionally**, making this host a live #41 downgrader at the shared path.

## Decision

Vendor core's `reviewer-cli.sh` (`1.0.0`, `60cd83f`) and its conformance harness
**byte-for-byte**, keeping only the installer arbitration host-local — the exact
discipline ADR-0011 applied to the gate:

- **Byte-identical from core `60cd83f`**: `bin/reviewer-cli.sh`
  (sha256 `32718bb9…`) and `tools/reviewer-cli-conformance.sh` (sha256
  `4e45150a…`). Scores **14/14**. Every arm ships, including `opencode` and
  `claude` — vendor *exclusion* is the producer's job (this host's producer
  selects `gemini`+`codex`), and the wrapper is fleet-wide, so its own-host arm
  exists for the sibling hosts that call the shared path.
- **`install.sh` gained `# reviewer-cli-version:` arbitration**, a sibling region
  to the gate's, reusing the gate's `_gate_ver_ge` comparator (the compare is
  marker-agnostic; only the extraction differs). Before writing the shared path:
  nothing installed → install; installed `>=` incoming → keep; installed `<`
  incoming → replace. A durable `test_reviewer_cli_arbitration` (filter
  `arbitration`) sources the delimited region in isolation and asserts the truth
  table, including fresh-install, unmarked/`abc` → `0.0.0` → replace, equal
  no-op, and the partial-prefix `1.x` (compared as `1.0.0`) cases.
- **CI scores the wrapper** on every PR (`openspec-gate.yml`), sibling to the
  gate-conformance step; the harness joins `ci.yml`'s syntax-check list.
- **Producer skill doc synced**: `REVIEWER_TIMEOUT` default `180s` → `300s`,
  matching the vendored wrapper. Vendor selection unchanged.

This **supersedes ADR-0011's classification** of `bin/reviewer-cli.sh` as
host-local wiring: it is now a vendored shared artifact, on the same footing as
the gate. The change also carried a MODIFIED spec delta correcting the gate
requirement's malformed-marker scenario to the accurate two-stage parse rule and
syncing its stale `1.2.0` pin to the shipped `1.2.2` — surfaced by the Stage-2
reviewer because the new requirement asserts parity with that gate rule.

## Alternatives Rejected

- **Add the two missing arms to the hand-authored copy.** The exact anti-pattern
  #41 names — a per-host fix at a shared path. Re-vendoring reaches 14/14 in one
  step and removes this host as a drift source.
- **Invent a stricter version grammar** (reject `1.0.0junk`, define full marker
  syntax), as an adversarial reviewer pressed for. Declined: the arbitration must
  stay byte-parallel to the shipped `# gate-version:` block; diverging the two is
  itself a defect. The risky logic (the comparator) is shared; only the trivial
  extractor is duplicated.
- **Defer installer arbitration to a later PR.** Leaves this host a live #41
  downgrader while shipping the very wrapper whose point is to stop that. The
  arbitration is the load-bearing half.
- **Skip the OpenSpec change** ("core mandates no host action"). Core mandates no
  *spec-version* change; but this host's own `opencode-workflow-scaffold`
  capability asserts what the scaffolder installs, and that changed. The direct
  precedent (the #16 gate adoption) opened a full change with a spec delta and
  ≥2 reviewers; this is its structural twin.

## Consequences

- This host stops owning reviewer-cli *logic*; upgrades are a re-vendor + harness
  re-run. The `opencode-openspec-change-review` producer must stay in lockstep
  with the wrapper's vendor set and its `## Reviewer:` output contract.
- The installer's downgrade-refusal removes *this* host as a source of silent
  downgrades at the shared path. It does not by itself make a mixed-version
  machine converge upward — a co-installed host whose installer lacks the same
  arbitration can still overwrite the path (core #41's fleet dimension). The
  guarantee is scoped to non-concurrent invocations of *this* installer.
- Two shared `bin/` artifacts (gate, reviewer-cli) now follow one arbitration
  pattern; a future third should reuse `_gate_ver_ge` the same way.

## References

- Core #41 (defect — silent arm loss at the shared path), #42 / `60cd83f`
  (reference impl + harness).
- The change: `openspec/changes/archive/*-adopt-reviewer-cli/` (proposal, design,
  spec delta, REVIEWS.md — gemini + codex, both APPROVE over 7 rounds).
- Supersedes [ADR-0011](0011-revendor-change-gate.md)'s classification of
  `bin/reviewer-cli.sh` as host-local wiring; follows the same re-vendor
  discipline it established for the gate.

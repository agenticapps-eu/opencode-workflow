## Context

Core is a spec repo that now also ships the normative §18 implementation
(`reference-implementations/openspec-change-gate/`) and an executable conformance
harness. The doctrine (README + ADR-0022): **one host-agnostic gate, vendored,
never re-authored per host.** This host predates that doctrine and carries its
own copy.

## Decision

**Re-vendor core's gate logic verbatim; keep the thin opencode wiring host-local;
inject host config through the environment, never by editing a vendored file.**

The byte-identical boundary is drawn around the files that carry §18 *logic* —
consumed from core (§16), never edited locally:
- `openspec-change-gate.sh` → `bin/openspec-change-gate.sh` (byte-for-byte from
  the pinned core revision `ae90483`, gate-version 1.2.0)
- `tools/change-gate-conformance.sh` → `tools/change-gate-conformance.sh`
  (byte-for-byte; a stale harness certifies a stale gate)

Everything else is **host-local wiring**, explicitly NOT claimed byte-identical —
the "equivalent interposition point" §18 lets each host own:
- `bin/openspec-change-gate.ts` — opencode has no PreToolUse; its plugin
  `tool.execute.before` throws on exit 2. Thin: all policy lives in the `.sh`.
- `bin/reviewer-cli.sh` — the reviewer-CLI wrapper.
- `bin/git-hooks/pre-commit` — adapted from core's `pre-commit`: same resolution
  logic, plus this repo's path and an `OPENSPEC_GATE_SELF=opencode` export. Kept
  at the existing path so `install.sh`'s staging wiring is unchanged.
- `.github/workflows/openspec-gate.yml` — adapted from core's CI workflow to this
  repo's paths, with `OPENSPEC_GATE_SELF=opencode` in the job env.

`OPENSPEC_GATE_SELF=opencode` is injected **through the environment at each
invocation point** (plugin spawn env, pre-commit wrapper, CI job) — the vendored
`.sh` reads the var but is never edited to carry the value. This resolves the
tension the pre-code review raised: env injection lives in the host-local
wrappers, not in the byte-identical logic files.

Add `# gate-version:` arbitration to `install.sh`: before writing the shared
`~/.agenticapps/bin/openspec-change-gate.sh`, compare the incoming marker to the
installed one and refuse to downgrade (treat unmarked as `0.0.0`; semver compare
across older/equal/newer/unmarked/malformed). This makes **this** installer
non-downgrading — a bounded, honest guarantee. It does NOT make the shared path
machine-wide monotonic on its own: another host's older installer without the
same arbitration can still overwrite it later (the pre-code review's semantic
catch). Machine-wide monotonicity is a fleet property that lands only when every
host adopts the arbitration; core#34 tracks that. This host does its part and
says exactly that in the spec.

## Alternatives Rejected

1. **Hand-patch the existing 164-line gate to 28/28.** Rejected — this is exactly
   the anti-pattern core #32/#34 and issue #15 name: five copies diverged because
   each host fixed its own. The README is explicit: "If a host genuinely needs
   different behaviour, change it *here* and add a harness row, then re-vendor."
   Re-vendoring is a one-way consume of upstream (§16), not a fork.

2. **Adopt only the enforcement-floor fix (`--pre-commit`/`--ci`), defer the
   rest.** Rejected — it leaves the reviewer-counting and path-exemption bypasses
   open under a different PR, re-introduces a hand-authored divergence from
   core's bytes, and the harness would still be red. Vendoring the whole file is
   less work and lands at 28/28 in one step.

3. **Move the pre-commit to `bin/pre-commit` to match core's filename.** Rejected
   for this change — it churns `install.sh`, the setup-skill snapshot, and the
   parity guard for zero conformance benefit. The wrapper resolves the gate by
   content-independent path fallback, so the filename is immaterial. Tracked as a
   possible later tidy.

## Consequences

- This host stops owning gate *logic*; upgrades are a re-vendor + harness re-run,
  not a code review of bespoke bash.
- `bin/openspec-change-gate.ts` and the `opencode-openspec-change-review` producer
  skill must stay in lockstep with core's reviewer-counting format (the producer
  writes `## Reviewer:`; core counts `^##\s*reviewer` case-insensitively — verify
  before archiving).
- The installer's downgrade-refusal removes *this* host as a source of silent
  downgrades at the shared path. It does not by itself make a mixed-version
  machine converge upward: a co-installed host whose installer lacks the same
  arbitration can still overwrite the path last-writer-wins. Fleet-wide
  monotonicity is a property of all installers adopting this, tracked in core#34.
- Deviation inherited from core (pinned by a harness row, not a local choice):
  `GSD_SKIP_REVIEWS` is applied *after* the validate check, so a RED validate
  plus the hatch still blocks. Documented in core's README §Deviations.

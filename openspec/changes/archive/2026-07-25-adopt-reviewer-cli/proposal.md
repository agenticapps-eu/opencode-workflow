## Why

Core published the §18 review **producer** wrapper as a normative reference
implementation — `reference-implementations/reviewer-cli/reviewer-cli.sh` at
`# reviewer-cli-version: 1.0.0` — plus an executable conformance harness
(`tools/reviewer-cli-conformance.sh`), pinned at core `60cd83f` (PR #42,
closes core #41). Hosts are now expected to **vendor** that file, not maintain
their own. This is the exact pattern already applied to the change-gate itself
(ADR-0011 / PRs #16–#18): the gate **consumes** review evidence, this wrapper
**produces** it, and both live at the one shared path
`~/.agenticapps/bin/` that every host installer writes.

This host still ships a hand-authored `bin/reviewer-cli.sh`, which ADR-0011
explicitly classified as **host-local wiring, "explicitly not byte-identical."**
That classification is now the defect. Scored against core's harness, this
host's copy fails on three counts, all silent under-capability:

- **Only 2 vendor arms** (`gemini`, `codex`) against the canonical 4
  (`claude`, `gemini`, `opencode`, `codex`). The wrapper lives at a shared path
  every host calls; a sibling host asking for `claude` or `opencode` gets
  `unknown vendor` mid-review, recorded as "reviewer unavailable", and §18
  proceeds with one fewer opinion. Vendor exclusion is the **producer's** job,
  not the wrapper's — dropping an arm because "this host would never use it" is
  the direct cause of core #41.
- **No `# reviewer-cli-version:` marker** → every installer treats it as
  `0.0.0`, and `install.sh` writes it to the shared path **unconditionally**
  (no arbitration). This is precisely how core #41 happened: on 2026-07-25 a
  host installer delivered the correctly-arbitrated `1.2.2` change gate and, in
  the same run, blind-installed a 3-arm wrapper over a 4-arm one, because the
  wrapper — unlike the gate — carried no version marker to arbitrate on.
- **stdin pinned per call site**, not once inside `run_bounded`. Two of the
  three pre-1.0.0 host copies did this; it is one forgotten redirect away from
  reintroducing the `codex exec` hang the wrapper exists to prevent, and the
  omission is invisible until that specific vendor is next called.

The canonical 1.0.0 is a **merge, not a pick**: `pi`'s structure (stdin pinned
inside `run_bounded` in one place, explicit usage checks, the unbounded-run
warning) with `codex`'s coverage (four arms and the `opencode`-is-a-client
model-provenance note). Core's own CHANGELOG states there is **no spec-version
change and no host action mandated** — vendoring is offered, not required — but
until a host adopts, the fleet scores 58/70. This host adopts.

## What Changes

- Vendor core's `reference-implementations/reviewer-cli/reviewer-cli.sh`
  (`# reviewer-cli-version: 1.0.0`, core `60cd83f`) **byte-for-byte** into
  `bin/reviewer-cli.sh`, replacing the hand-authored 2-arm copy.
- Vendor core's `tools/reviewer-cli-conformance.sh` byte-for-byte (new file);
  CI runs it against the vendored wrapper — a stale harness certifies a stale
  wrapper.
- Teach `install.sh` to arbitrate on `# reviewer-cli-version:` before writing
  the shared `~/.agenticapps/bin/reviewer-cli.sh`, using the gate's existing
  extractor/comparator: **nothing installed → install; installed `>=` incoming →
  keep; installed `<` incoming → replace.** Version parsing is the gate's proven
  rule — the marker's leading dotted-numeric run, so a marker with no leading
  numeric run parses as `0.0.0` while a partial one keeps its numeric prefix
  (a partial marker such as `1.x` is compared as `1.0.0`); a malformed marker
  never crashes the installer. This is the
  same clause the gate already has for `# gate-version:` — the entire content of
  core #41 is that the wrapper lacked it.
- Add the conformance run to CI (`.github/workflows/openspec-gate.yml`) and the
  new harness to the shell-syntax-check list (`.github/workflows/ci.yml`).
- Record ADR-0012 (adopt reviewer-cli 1.0.0), superseding ADR-0011's
  classification of `bin/reviewer-cli.sh` as host-local wiring.
- Documentation sync: the `opencode-openspec-change-review` producer skill's
  stale `REVIEWER_TIMEOUT` default (`180s` → `300s`) is corrected to match the
  vendored wrapper. Vendor selection is unchanged (`gemini` + `codex` — both
  non-`opencode`, both distinct, satisfying §18 without this host reviewing
  itself).

## Impact

- Affected spec capability: `opencode-workflow-scaffold` — one ADDED requirement
  mirroring the gate's vendor-and-arbitrate requirement, plus one MODIFIED
  requirement: because the new requirement asserts parity with the gate's
  `# gate-version:` rule, the existing gate requirement's malformed-marker
  scenario is corrected from the imprecise blanket "malformed → `0.0.0`" to the
  same accurate rule (`abc` compared as `0.0.0`; `1.x` compared as `1.0.0`). This is
  a prose clarification only — the shipped gate extractor already behaves this
  way; it keeps the two parallel arbitration descriptions from contradicting in
  the merged spec.
- Affected code: `bin/reviewer-cli.sh`, `tools/reviewer-cli-conformance.sh`
  (new), `install.sh`, both CI workflows, ADR-0012, the producer skill's
  timeout note.
- No change to the §18 gate, the gate's version, or core's normative §18 text.
  In the *specific* core #41 incident — a 3-arm wrapper (dropping `opencode`)
  overwriting the 4-arm one — §18's `>= 2 distinct vendors` threshold still held,
  because a producer excluding its own host still had two; #41 was a silent
  capability loss beneath a satisfied threshold, not a bypass. That is not a
  general guarantee: this host's current 2-arm `{gemini, codex}` wrapper reaching
  a **codex** host would leave only `gemini` after self-exclusion — one reviewer,
  below the threshold. Adopting the 4-arm canonical is what closes *that* latent
  breach too, not merely the observed one.
- Reference: repo follows core #41 (defect) / #42 (reference impl); parallels
  this repo's ADR-0011 and issue #15 for the gate.

# Design — adopt reviewer-cli 1.0.0

## Context

`bin/reviewer-cli.sh` is the defensive wrapper the §18 review producer
(`opencode-openspec-change-review`) calls once per vendor. It is installed at
one shared path, `~/.agenticapps/bin/reviewer-cli.sh`, written by the
claude / codex / opencode / pi installers alike. Core has now published it as a
versioned reference implementation. The decision here is a straight application
of the re-vendor discipline established for the gate (ADR-0011): consume the
upstream logic byte-for-byte, keep only the installer arbitration host-local.

## Decisions

### D1 — Vendor byte-for-byte, do not hand-patch

Copy core's `reviewer-cli.sh` (core `60cd83f`, `1.0.0`) verbatim into
`bin/reviewer-cli.sh`; copy `tools/reviewer-cli-conformance.sh` verbatim. A
private edit to a file at a shared path is not a fork, it is a race — the exact
mechanism of core #41. If this host ever needs different wrapper behaviour, the
change goes **into core** with a matching harness row, then re-vendors.

Byte-parity is proven by `shasum -a 256` against the pinned core files:
- `reviewer-cli.sh` → `32718bb9…4b7ec6`
- `reviewer-cli-conformance.sh` → `4e45150a…9f6656`

### D2 — Every arm ships, including `opencode` — exclusion is the producer's job

The vendored wrapper carries all four arms even though this host is `opencode`
and must never review its own change. The wrapper is fleet-wide; the exclusion
is per-producer. This host's producer skill selects `gemini` + `codex` (two
distinct non-`opencode` vendors), so the `opencode` and `claude` arms exist
here **for the sibling hosts that call the shared path**. Removing them
"because this host wouldn't use them" is what core #41 forbids.

### D3 — Arbitrate `# reviewer-cli-version:` in `install.sh`, mirroring the gate

Today `install.sh` installs `reviewer-cli.sh` unconditionally (one `install`
line, no version check) while the gate right above it is downgrade-guarded.
Add the parallel guard: read the installed and incoming `# reviewer-cli-version:`
markers and refuse a downgrade — **nothing installed → install; installed `>=`
incoming → keep; installed `<` incoming → replace.** Parsing is the gate's
proven rule verbatim: the marker's leading dotted-numeric run, so a marker with
no leading numeric run parses as `0.0.0` and a partial one keeps its numeric
prefix — so a partial marker such as `1.x` is compared as `1.0.0`, not `0.0.0`
(only a marker with no leading numeric run becomes `0.0.0`); a malformed marker
must never crash the
installer. The artifacts here deliberately do **not** assert a stricter
"malformed → `0.0.0`" grammar than the shipped gate has — divergence between the
two parallel arbitration blocks is itself a defect (D1).

**Reuse the existing comparator, do not duplicate it.** The gate arbitration
block already defines `_gate_ver_ge` (a portable pure-bash dotted-version
compare, since macOS `sort` lacks `-V`) and `_gate_should_install`. The
version *comparison* is marker-agnostic; only the *extraction* is
marker-specific. So:
- add `_reviewer_cli_version_of()` — same shape as `_gate_version_of` but
  matching `^# reviewer-cli-version:` — and a `_reviewer_cli_should_install()`
  that calls the shared `_gate_ver_ge`;
- OR generalize `_gate_version_of` to take a marker-name argument.

Chosen: **a parallel `_reviewer_cli_version_of` + `_reviewer_cli_should_install`
reusing `_gate_ver_ge`.** Rationale: the gate block is a marker-delimited,
self-contained region (`>>> gate-version-arbitration >>>`) that the test suite
sources as a unit; generalizing `_gate_version_of`'s signature would churn that
region and its (implicit) contract for no behavioural gain. A sibling
`# reviewer-cli-version:` region keeps each artifact's arbitration independently
readable and independently vendored, at the cost of one duplicated 6-line
extractor. The comparator itself — the part with the subtle numeric-field
logic — is shared, so the duplication is confined to trivial `sed` extraction.

### D4 — Conformance in CI, next to the gate's

`.github/workflows/openspec-gate.yml` already has a "Prove the gate itself is
conformant" step running `tools/change-gate-conformance.sh`. Add a sibling
"Prove the reviewer-cli is conformant" step running
`tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh`. Both §18 artifacts —
consumer (gate) and producer (wrapper) — are then harness-scored on every PR.
Add the new harness path to `ci.yml`'s `bash -n` syntax-check loop, mirroring
how `change-gate-conformance.sh` was added in #16 (task 4.2).

The harness's `--family` mode walks sibling host clones; CI scores this host's
single copy by explicit path, matching the gate step's form exactly.

### D5 — No producer-skill behaviour change; one doc correction

The producer already writes `## Reviewer:` headings the gate counts, and picks
`gemini` + `codex`. Neither changes. The only edit to the producer skill is
correcting its `REVIEWER_TIMEOUT` default from the stale `180s` to the vendored
wrapper's `300s` (two mentions), so the doc does not misdescribe the artifact it
calls. This is a documentation sync, not a scope expansion — and it is required
by core's "keep the two in sync" vendoring rule.

## Alternatives rejected

- **Add the two missing arms to the existing hand-authored copy.** The exact
  anti-pattern core #41 names — a per-host fix at a shared path. Re-vendoring
  lands 5/5 sections conformant in one step and removes this host as a source of
  drift.
- **Generalize `_gate_version_of(marker, file)` and share one extractor.**
  Cleaner in isolation, but rewrites the delimited gate-arbitration region the
  test suite treats as a sourced unit, for the sake of removing a 6-line `sed`.
  The risky part (the comparator) is already shared. Rejected on
  churn-vs-benefit (D3).
- **Skip the OpenSpec change — "core says no host action mandated."** Core says
  no *spec-version* change and that vendoring is *offered*. But this host's own
  `opencode-workflow-scaffold` capability spec asserts what the scaffolder
  installs, and that assertion changes (a versioned, arbitrated, 4-arm wrapper).
  The direct precedent (#16, the first gate adoption) opened a full change with
  a spec delta and ≥2 reviewers; this is its structural twin.
- **Defer installer arbitration to a later PR.** Leaves this host as a live
  core-#41 downgrader at the shared path while shipping the very wrapper whose
  point is to stop that. The arbitration is the load-bearing half of the fix.

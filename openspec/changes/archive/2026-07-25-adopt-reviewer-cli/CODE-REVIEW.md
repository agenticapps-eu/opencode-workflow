# Stage-3 code review — adopt-reviewer-cli

Independent code review of the implementation diff (`git diff main...HEAD`), run
in a separate agent context per §17 (Stage 3, retained). Distinct from the
Stage-2 pre-code change review in REVIEWS.md — this reviews the CODE, that
reviewed the CHANGE. Scope: host-local code only (the vendored
`bin/reviewer-cli.sh` and `tools/reviewer-cli-conformance.sh` are byte-identical
to core and read for actual correctness defects only — none found).

## Verdict: no issues ≥ threshold. Host-local code is correct.

Verified by execution, not inspection alone:
- `bash migrations/run-tests.sh arbitration` → **8/8 PASS**
- `bash tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` → **14/14 PASS**, exit 0
- `bash -n` clean on all four touched scripts

## Findings by focus area

- **Version-comparison logic (install.sh) — correct.** Reuses the gate's
  `_gate_ver_ge` correctly (comparator is marker-agnostic; only the extraction
  sed differs). Definition order is safe: gate region → reviewer region → call
  site. All edge cases handled and proven by the test (absent → install;
  `>`/`<`/equal; unmarked/malformed installed → `0.0.0`; partial `1.x` → compared
  as `1.0.0`; malformed incoming → `0.0.0`, no crash).
- **Shell-quoting/robustness — clean.** All expansions quoted; `sed | head -1`
  guarded by the `case → 0.0.0` fallback; behaves correctly under `set -uo
  pipefail` (no `set -e`, so a `keep`/`return 1` does not abort the installer).
- **Test genuinely exercises the code.** `awk`-extracts the real marker-delimited
  regions from `install.sh` and sources them (does not reimplement); guards on
  `declare -F` so a vanished region fails loudly. Dispatcher wired under both
  no-filter and `FILTER=arbitration`.
- **Guarded install block — cannot silently skip or mis-report.** Fresh machine:
  absent dest → install. OK/KEEP echoes mirror the gate block line-for-line and
  report resolved versions.
- **CI edits — correct and consistent** with the sibling gate steps.
- **SKILL.md doc sync — accurate.** `180s → 300s` matches the vendored wrapper's
  `REVIEWER_TIMEOUT:-300`; no stale references remain outside ADR-0012.

## Non-blocking observation (below action threshold)

The reviewer arbitration region depends on the gate region defining
`_gate_ver_ge` (design D3, deliberate co-vendored reuse). Safe today — the
regions are co-located and the test would fail loudly if the comparator were
renamed. Noted for awareness, not a defect; accepted.

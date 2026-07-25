# Change review — revendor-openspec-change-gate

Producer: opencode-openspec-change-review v0.1.0 (driven from Claude Code, per the skill procedure)
Change: openspec/changes/revendor-openspec-change-gate/
Reviewed artifacts: proposal.md, design.md, specs/opencode-workflow-scaffold/spec.md, tasks.md
Vendors: gemini (Google), codex (OpenAI) — 2 distinct external vendors per §18.

The review ran four rounds. gemini APPROVE each round; codex REQUEST-CHANGES on
rounds 1–3, then APPROVE on round 4 against the amended change. The verdicts below
are the round-4 verdicts against the current (amended) artifacts; the iteration
log records what codex caught and how each finding was resolved — the value the
§18 pre-code review is protecting.

## Reviewer: gemini

Verdict: APPROVE

Round 1 (full): the spec delta correctly translates intent; the modification
precisely defines "independent reviewer"; the two new requirements
(enforcement-floor, vendored-from-core) correspond to the proposal's goals;
minimal (no incidental scope); complete (handles duplicate reviewers and installer
downgrade refusal); no semantic defects. "A clear improvement, replacing a faulty,
divergent implementation with a conformant, centrally-maintained one, and
enshrining that practice in the spec itself."

Rounds 2–4: APPROVE, no new findings.

## Reviewer: codex

Verdict: APPROVE (round 4)

Round 4 (verbatim): "Revision 3's ordering defect is resolved: plugin and
pre-commit propagation are tested and rerun within section 3, while CI propagation
is now verified in 4.3 only after the workflow and its environment exist in 4.1.
No new blocking defect is introduced. VERDICT: APPROVE."

codex's earlier rounds found real defects, all now resolved (see the iteration log
below). Its round-1 catch — that the "cannot be silently downgraded" claim was a
cross-host semantic impossibility because this installer cannot stop another
host's older installer — is exactly the class of defect this gate exists to catch
before code.

## Review iteration log

**Round 1 — codex REQUEST-CHANGES** (5 findings, all addressed):
1. Escape-hatch contradiction: requirement demanded validate AND 2 reviewers
   unconditionally, ignoring `GSD_SKIP_REVIEWS`. → Added escape-hatch clause +
   scenarios (waives reviews, never validate).
2. Root-anchored `openspec/` exemption missing from the delta. → Added the
   "exemption anchored to repository root" requirement + look-alike-path scenarios.
3. "Vendored from core" not testable (stale harness could pass). → Pinned to core
   rev `ae90483` / gate-version 1.2.0 + byte-parity, harness-must-pass scenario.
4. Design self-contradiction: byte-for-byte vs tasks editing pre-commit/CI. →
   Redrew the byte-identical boundary around gate+harness only; wrappers are
   host-local; env injected outside the vendored file.
5. Semantic defect: cross-host downgrade invariant impossible as written. →
   Scoped the guarantee to "this installer."

**Round 2 — codex REQUEST-CHANGES** (3/5 confirmed resolved; residuals addressed):
- Two residual cross-host overclaims (proposal Impact, design Consequences). →
  Both scoped to this installer.
- Escape-hatch/CI ambiguity. → Made the hatch explicitly mode-spanning; added
  CI-with-hatch and CI-without-hatch scenarios (grounded in core gate line 139).
- Comparator wording, equal-version no-op, malformed marker, pre-commit
  fail-open-when-no-gate, reviewer canonicalization (case-fold + dedup, matching
  core's `tolower`), TDD ordering, task 6.3 scope. → All added/reworded.

**Round 3 — codex REQUEST-CHANGES** (1 finding): task-ordering impossibility —
3.1 tested CI propagation before CI existed (4.1). → Scoped 3.1/3.3 to
plugin+pre-commit; moved the CI-slice assertion to new task 4.3.

**Round 4 — both APPROVE** against the amended change.

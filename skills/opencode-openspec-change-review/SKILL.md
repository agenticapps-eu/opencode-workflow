---
name: opencode-openspec-change-review
version: 0.1.0
implements_spec: 1.0.0
implements_gate: multi-ai-change-review
description: |
  Produce the independent multi-AI adversarial review of the active
  OpenSpec change BEFORE any code is written, at lifecycle stage 2
  (validate), per spec §17 stage 2 and §18. Reads the active change
  under `openspec/changes/<slug>/` (proposal.md, design.md, the spec
  delta, tasks.md), runs >= 2 DISTINCT external-vendor reviewer CLIs
  (default `gemini` + `codex`) via `bin/reviewer-cli.sh`, and writes
  `openspec/changes/<slug>/REVIEWS.md` with one `## Reviewer: <vendor>`
  heading per reviewer — the heading the §18 change-gate counts. Use
  when a change has been drafted and validated and needs its pre-code
  review, or when the change-gate (`openspec-change-gate.sh`) blocks an
  edit for `REVIEWS.md has <2 reviewers`. This is the review PRODUCER;
  the gate is the enforcer. It is NOT a plan-review gate (§17 forbids
  that under 1.0.0) and NOT a code review (that is the retained
  `code-review` gate at stage 3, in independent context).
---

# opencode-openspec-change-review — multi-AI change review producer (spec §18)

This skill produces the independent multi-AI adversarial review that the
OpenSpec v1.0.0 change-gate requires before code. It is the review
*producer*; the enforcer is `openspec-change-gate.sh`
([`bin/openspec-change-gate.sh`](../../bin/openspec-change-gate.sh)),
which blocks any code edit while an active change lacks a green
`openspec validate --all` AND a `REVIEWS.md` carrying `>= 2`
`## Reviewer:` headings.

The gate counts headings; this skill writes them. The two are one
mechanism split across producer and enforcer so that the review is a
real artifact on disk (auditable, re-runnable) rather than an ephemeral
in-session claim.

## What this is NOT

- **Not a plan-review gate.** Spec §17 removed standalone plan review
  under 1.0.0. Do not resurrect a `plan_review` / `gsd-review` step —
  the review of intent now happens against the *change* (proposal +
  spec delta), not against a phase plan.
- **Not a code review.** The `code-review` gate is retained at
  lifecycle stage 3 and runs in an independent agent context against the
  implementation diff. This skill runs at stage 2, before any code
  exists, and reviews the CHANGE. The two are distinct gates; producing
  one never discharges the other.

## When to invoke

At lifecycle stage 2 (validate), once the active change has been drafted
and `openspec validate --all` is green, and before any code edit. In
practice, two triggers:

- **Proactive.** The change author finishes proposal.md / design.md /
  the spec delta / tasks.md, validates, and invokes this skill to
  produce REVIEWS.md as the last stage-2 step.
- **Reactive.** The change-gate blocked an edit with
  `REVIEWS.md has <count> reviewer(s); need >= 2` — this skill is how
  that block is cleared (legitimately: by actually running the reviews).

## Inputs

The single active change directory under `openspec/changes/`. Determine
it the same way the gate does — the one open change directory, excluding
`archive/`:

```bash
active_change="$(
  for d in openspec/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in openspec/changes/archive/) continue ;; esac
    printf '%s' "${d%/}"; break
  done
)"
[ -n "$active_change" ] || { echo "no active change under openspec/changes/"; exit 1; }
```

The review reads, from that directory:

- `proposal.md` — the why and the what.
- `design.md` — the how (if present).
- the spec delta — the normative change to the spec.
- `tasks.md` — the intended breakdown.

## Procedure

### 1. Assemble the adversarial review prompt

Write a single prompt file that asks the reviewer to adversarially
critique the **proposed change** — not code, which does not yet exist.
The prompt MUST embed the full text of the change's artifacts (proposal,
design, spec delta, tasks) so the reviewer is judging the actual change,
not a summary. The reviewer is asked to answer, specifically:

- Is the spec delta **correct** — does it say what the proposal intends?
- Is it **minimal** — does it change only what the proposal requires,
  with no incidental scope?
- Is it **complete** — are there missing requirements, fallback paths,
  or edge cases the delta silently omits?
- Does it introduce a **semantic defect** — a rule that contradicts an
  existing requirement, an ambiguous MUST, an unreachable branch, an
  invariant the delta breaks?

The reviewer MUST end with an explicit verdict line:

- `VERDICT: APPROVE` — the change is correct, minimal, complete, no
  defect found; or
- `VERDICT: REQUEST-CHANGES` — followed by specifics (which requirement,
  which edge case, which contradiction).

This is not ceremony. In the cParX pilot this review caught a real
semantic defect in a spec delta **before any code was written** —
cheaper to fix in the delta than after an implementation had been built
on top of it. That is the value the gate is protecting.

Write the prompt to a scratch file, e.g.:

```bash
prompt_file="$(mktemp -t change-review-prompt.XXXXXX)"
# ...compose the prompt (instructions + embedded artifact text) into $prompt_file...
```

### 2. Run >= 2 DISTINCT external-vendor reviewers

The §18 requirement is **two different vendors**, not two runs of one.
Default vendors: `gemini` (Google) and `codex` (OpenAI). Call the
wrapper once per vendor:

```bash
# Wrapper resolves to ~/.agenticapps/bin/reviewer-cli.sh when installed,
# else the repo's bin/reviewer-cli.sh.
reviewer_cli="$HOME/.agenticapps/bin/reviewer-cli.sh"
[ -x "$reviewer_cli" ] || reviewer_cli="bin/reviewer-cli.sh"

# Run the two vendors in parallel; each writes its raw verdict to a file.
"$reviewer_cli" gemini "$prompt_file" >/tmp/review-gemini.txt 2>/tmp/review-gemini.err &
"$reviewer_cli" codex  "$prompt_file" >/tmp/review-codex.txt  2>/tmp/review-codex.err  &
wait
```

The wrapper already handles the hardening the skill must not re-implement:
each reviewer CLI is fed `</dev/null` on stdin and bounded by a hard
`timeout` (`REVIEWER_TIMEOUT`, default 180s). This exists because the
pilot found `codex exec "<prompt>"` reads stdin and hangs without
`</dev/null` (PILOT-REPORT friction #3, a 4-minute stall on first
attempt). The skill just calls the wrapper.

A **non-zero** exit from the wrapper means the reviewer was unavailable
(CLI missing, timed out, or errored). That vendor does NOT count as a
passing reviewer — report it and either retry, substitute a different
vendor, or (only if review genuinely cannot run) use the logged escape
hatch below. Never fabricate a verdict for an unavailable reviewer.

### 3. Write REVIEWS.md with one heading per reviewer

Write `openspec/changes/<slug>/REVIEWS.md` with **exactly one**
`## Reviewer: <vendor>` heading per reviewer that actually ran. This
heading is the literal string the gate counts
(`grep -cE '^##[[:space:]]+Reviewer:'`), so it must match — `## Reviewer: gemini`,
not `### Reviewer` or `## Reviewer (gemini)`.

Each section carries that reviewer's verdict and their raw critique:

```markdown
# Change review — <slug>

Producer: opencode-openspec-change-review v0.1.0
Change: openspec/changes/<slug>/
Reviewed artifacts: proposal.md, design.md, <spec delta path>, tasks.md

## Reviewer: gemini

Verdict: APPROVE | REQUEST-CHANGES

<gemini's raw critique, verbatim>

## Reviewer: codex

Verdict: APPROVE | REQUEST-CHANGES

<codex's raw critique, verbatim>
```

Paste the reviewers' output verbatim — the raw critique is the evidence.
Do not summarize away the specifics, especially on REQUEST-CHANGES.

### 4. Resolve REQUEST-CHANGES, then re-validate

If any reviewer returns REQUEST-CHANGES, the change is **not** ready for
code:

1. The change author resolves the finding by amending the affected
   artifact — the proposal, the design, or (most often) the spec delta.
2. Re-run `openspec validate --all` — it MUST be green.
3. Re-run this skill to regenerate REVIEWS.md against the amended change.

Only when **both** hold does the §18 change-gate allow code edits:

- `openspec validate --all` is green, AND
- REVIEWS.md carries `>= 2` `## Reviewer:` headings.

Two APPROVE verdicts on a stale (pre-amendment) change do not count — the
re-run against the amended change is what makes the review honest.

## Escape hatch

When review genuinely cannot run (e.g. no reviewer CLI on PATH in a CI
box, or an offline environment), the deliberate override is:

```bash
GSD_SKIP_REVIEWS=1 <the edit>
```

The change-gate handles this env var directly and **logs** the override
(`ALLOW (GSD_SKIP_REVIEWS=1 override)`) — it is a documented, logged
bypass, not a silent one. Use it only when review truly cannot be
produced, never as a shortcut around a REQUEST-CHANGES finding.

## Required evidence (per spec §18)

- `openspec/changes/<slug>/REVIEWS.md` exists in the active change dir.
- It contains `>= 2` `## Reviewer:` headings, one per DISTINCT vendor.
- Each section has an explicit `Verdict:` (APPROVE or REQUEST-CHANGES).
- Each reviewer's raw critique is present (not summarized to nothing).
- `openspec validate --all` is green for the active change.
- If any verdict was REQUEST-CHANGES, the change was amended and the
  review re-run — the on-disk REVIEWS.md reflects the amended change.

## Failure modes

- **Two runs of one vendor.** `gemini` twice is one vendor; the §18
  requirement is TWO DISTINCT vendors. Two headings from the same vendor
  do not satisfy the intent even though the gate counts two headings —
  do not game the count.
- **Reviewing code instead of the change.** At stage 2 there is no code.
  A reviewer that starts asking to see the implementation has been given
  the wrong prompt; the prompt must embed the change artifacts and ask
  about the delta.
- **Counting an unavailable reviewer as a pass.** A non-zero wrapper exit
  is "reviewer unavailable", not "reviewer approved". Never write an
  APPROVE section for a reviewer that did not run.
- **Silencing REQUEST-CHANGES by hand-editing the verdict.** The fix for
  REQUEST-CHANGES is amending the change and re-running — not editing the
  reviewer's verdict text to APPROVE.
- **Skipping the re-validate after amendment.** An amended delta can
  fail validate; a green REVIEWS.md over a red validate still blocks at
  the gate (validate-green is an independent condition).

## Notes for the opencode host

- The wrapper path resolves to `~/.agenticapps/bin/reviewer-cli.sh` when
  the workflow is installed, else the repo's `bin/reviewer-cli.sh`. Both
  take `<vendor> <prompt-file>` and emit raw verdict text on stdout.
- The gate's default is `>= 2` reviewers; `OPENSPEC_GATE_MIN_REVIEWERS`
  can raise it. If a project raised it, produce that many DISTINCT
  vendors.
- `REVIEWER_TIMEOUT` (default 180s) bounds each reviewer. A vendor that
  needs longer can be given a larger cap; a vendor that times out
  (`exit 124`) is treated as unavailable, not as a pass.

## References

- workflow-core spec §17 — the OpenSpec 1.0.0 lifecycle; stage 2
  (validate) is where this review is discharged, and §17 removes the
  standalone plan-review gate.
- workflow-core spec §18 — the change-gate contract this skill produces
  evidence for (validate-green AND `>= 2` `## Reviewer:` headings).
- [`bin/openspec-change-gate.sh`](../../bin/openspec-change-gate.sh) —
  the enforcer that counts the headings this skill writes.
- [`bin/reviewer-cli.sh`](../../bin/reviewer-cli.sh) — the hardened
  per-vendor wrapper (`</dev/null` + `timeout`) this skill calls.
- PILOT-REPORT.md — the cParX pilot that caught a real semantic spec
  defect pre-code (the value) and surfaced the codex stdin-hang
  (friction #3, why the wrapper exists).

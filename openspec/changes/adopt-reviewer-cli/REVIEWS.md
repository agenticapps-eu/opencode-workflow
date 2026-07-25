# Change review — adopt-reviewer-cli

Producer: opencode-openspec-change-review v0.1.0 (procedure followed manually)
Change: openspec/changes/adopt-reviewer-cli/
Reviewed artifacts: proposal.md, design.md, specs/opencode-workflow-scaffold/spec.md, tasks.md
Vendors: gemini (Google) + codex (OpenAI) — two DISTINCT external vendors, neither
this host (`opencode`), via `bin/reviewer-cli.sh`. Both APPROVE on the final
(revision-7) artifacts. Seven review rounds; every REQUEST-CHANGES was resolved by
amending the change and re-running against the amended text (stale approvals do not
count — §18 / producer-skill step 4).

## Reviewer: gemini

Verdict: APPROVE

Approved from revision 3 onward (revisions 3–7). Final (rev 7):

> VERDICT: APPROVE

Substantive contribution (rev 4): flagged that the two-stage version-parse phrasing
was inconsistent across artifacts (`1.x → 1` in proposal/design vs `1.x → 1.0.0` in
the spec) and that "the specification is the contract; it should adopt the most
precise phrasing." Resolved by harmonizing all four artifacts — ultimately to the
comparison-result-only form.

## Reviewer: codex

Verdict: APPROVE

Final (rev 7):

> Revision 7 is correct, minimal, and complete.
>
> - The `1.x → 1.0.0` and `abc → 0.0.0` comparison results match the shipped
>   extractor/comparator without asserting an internal token.
> - The gate pin now correctly matches shipped and upstream `1.2.2`.
> - Upstream commit and both SHA-256 abbreviations are accurate.
> - Installer behavior, concurrency limits, tests, CI, documentation, security
>   review, and lifecycle close-out are adequately specified.
> - No semantic contradiction or unintended grammar expansion remains.
> - `openspec validate --all` passes.
>
> VERDICT: APPROVE

codex ran an adversarial multi-round critique (REQUEST-CHANGES on revisions 1, 2, 3,
5, 6). Every finding was legitimate and is resolved in the artifacts — see the log.

## Review iteration log

Each round: amend artifacts → `openspec validate --all` green → re-run BOTH vendors.

- **Rev 1** — gemini APPROVE; codex REQUEST-CHANGES (7 points). Resolved:
  (1/#1) scoped the unmarked-upgrade scenario to "incoming well-formed > 0.0.0";
  (#3) added a fresh-install (absent-destination → install) scenario + task case;
  (#4) reworded the dispatch scenario to what the harness proves (dispatch to a
  success stub → 0; no `unknown vendor`) instead of "exit 0 when CLI present";
  (#5) added "byte-for-byte" to the spec requirement (CI kept in tasks, matching
  the shipped gate precedent);
  (#6) qualified the never-downgrade invariant as "never replaces a ≥ parseable
  marker" and noted the non-concurrent assumption;
  (#7) relabeled task 7.2 "Stage-2 code review" → **Stage-3** (the pre-code change
  review is stage 2; the independent code review is stage 3);
  (Correct-section) scoped the proposal's "≥2 threshold held throughout #41" claim
  to the specific incident, noting the 2-arm→codex-host breach this change prevents.
  Points #2 (invent a stricter version grammar) and locking for #6 were **declined
  with rationale**: the arbitration must stay byte-parallel to the already-shipped
  `# gate-version:` block; diverging it is itself a defect (design D1/D3).
- **Rev 2** — gemini APPROVE; codex REQUEST-CHANGES (2 points). Resolved:
  (1) narrowed proposal/design/tasks "malformed → 0.0.0" to the shipped extractor's
  actual rule (leading dotted-numeric run; only a no-leading-run marker → 0.0.0);
  (2) removed the dispatch scenario's "propagates exit status, proven by the harness"
  overclaim and stated the real exit contract incl. `124 → 3`.
- **Rev 3** — gemini APPROVE; codex REQUEST-CHANGES (1 point). Resolved: corrected the
  one remaining inconsistent scenario ("Malformed incoming marker") to the two-stage rule.
- **Rev 4** — codex APPROVE; gemini REQUEST-CHANGES (1 point). Resolved: harmonized the
  `1.x` phrasing across all four artifacts.
- **Rev 5** — gemini APPROVE; codex REQUEST-CHANGES (1 point). Resolved: added a
  **MODIFIED** delta correcting the *existing* gate requirement's malformed-marker
  scenario (ADDED-only would have left the merged spec describing the one shared rule
  two ways); updated proposal Impact to "ADDED + MODIFIED".
- **Rev 6** — gemini APPROVE; codex REQUEST-CHANGES (2 points). Resolved:
  (1) simplified all `1.x` wording to state only the comparison result (`1.x` → `1.0.0`),
  dropping the non-normative internal-token claim (the extractor actually yields `1.`,
  not `1`);
  (2) synced the MODIFIED gate requirement's stale `1.2.0` pin to the shipped `1.2.2`
  (pre-existing drift from #17/#18) — prose/spec sync, no gate-code change.
- **Rev 7** — gemini APPROVE; codex APPROVE. **Converged.**

Note: codex twice returned empty at `REVIEWER_TIMEOUT=300` (it uses ~107k tokens on
this prompt and needs longer); re-running at 420s completed cleanly. This is the exact
class of friction the wrapper's bounded-timeout hardening exists for — a slow reviewer
surfaces as a re-runnable non-result, never a silent pass.

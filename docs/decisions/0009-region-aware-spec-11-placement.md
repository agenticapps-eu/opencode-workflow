# ADR-0009 — §11 is anchored region-aware: first `## ` or `gitnexus:start`, whichever comes first

**Status:** Accepted
**Date:** 2026-07-15
**Applies to:** `opencode-workflow` (this repo)
**Relates to:** migration `0009`, ADR-0007 (snapshot install),
`claude-workflow`'s ADR-0041 / migration `0029` (the upstream of this decision).

## Context

Migration `0001` anchors the canonical spec §11 "Coding Discipline" block
immediately before the first `## ` heading in `AGENTS.md`, and `0004` re-injects
it the same way. The choice was deliberate: it guarantees the block is followed
by a `## ` line, which is what the replace and rollback logic uses to bound the
managed section.

That is only a safe boundary if the heading belongs to *project* content. In an
`AGENTS.md` that leads with a GitNexus block, the first `## ` is `## Always Do` —
inside `<!-- gitnexus:start -->…<!-- gitnexus:end -->`. `gitnexus analyze`
regenerates everything between those markers, so the block is silently destroyed
on the next run.

Recovery is closed. `update` marks a migration pending iff
`installed >= from_version && installed < to_version`; `0001`/`0004` are long
past and never replay, and their pre-flight version gates also abort the
`--migration NNNN` force path. Once eaten, the block needs a hand-paste.

A fleet scan on 2026-07-15 found **0 of 4** opencode-scaffolded `AGENTS.md` files
affected — no block is currently inside a region. The defect is **latent here**,
unlike `claude-workflow`, which had a live broken repo.

It is not, however, latent because every file has project `## ` headings above
its region — the reason this ADR originally gave. **`factiv/cparx` is genuinely
region-led**: region L1–43, first `## ` = `## Always Do` at **L8, inside it**. It
is safe only because its §11 landed *below* the region. Measured against its real
`AGENTS.md`, the naive anchor places §11 at L8 — inside the region — while this
decision's rule places it at L1, above. `cparx` is the repo this decision exists
for, and any future state-C re-inject there hits exactly that.

(The original scan covered only the `agenticapps/` family and counted `codex-*`
hosts this scaffolder does not install. Corrected 2026-07-15; the conclusion
survived, the stated reason did not.)

## Decision

> Insert immediately before the first line that is **either** a `## ` heading
> **or** a `<!-- gitnexus:start -->` marker — whichever comes first. If neither
> exists, append at EOF.

A one-alternation delta to `0001`'s awk, so its structural invariant survives:
the block is still always followed by a `## ` line or EOF.

Fixed forward in migration `0009`. `0001` and `0004` are immutable — they shipped
and their injection is real state in installed projects.

### Validation

The rule was validated **before** the migration was written. With any existing
block stripped, it re-derives the block's current position exactly in all six
real fleet files — zero churn. On a modelled region-led file it anchors above the
region where the naive rule anchored inside it. On a file with neither a `## `
nor a region, it falls to EOF.

## Alternatives rejected

### "Before `gitnexus:start` if a region exists, else the first `## `"

The obvious reading of "put it above the region", and wrong. Measured against
this repo's own `AGENTS.md`, whose region starts at L240: §11 would move from L17
to **L159**, violating §12's placement advisory ("near the top", "not below long
appendices"). The region is only the anchor when it comes *first* — which is what
`whichever comes first` encodes, and which is why `cparx` (region at L1) and this
repo (region at L240) both land correctly under a single rule. Rejected on
measurement, not on argument.

(Originally measured against `codex-workflow/AGENTS.md` — a real file with a late
region, but a **codex** host, not one this scaffolder installs. Re-measured
in-fleet; conclusion unchanged.)

### "Always immediately after the H1"

Simpler to state, but it moves the block in every healthy file for no benefit and
breaks the followed-by-`## ` invariant `0001`'s rollback depends on.

### Moving a healthy block that sits somewhere non-canonical

Not done. No failure mode motivates it, and it churns project files (Surgical
Changes). Only the in-region case is a defect.

## Why no anchor-parity guard

`claude-workflow`'s equivalent decision mandates an `anchor-parity` guard that
extracts the anchor awk from both its migration and its `setup/SKILL.md` step e2
and requires exactly one distinct value. That control does not transfer, and the
reason is structural.

**This host's setup path carries no anchor awk.** §11 is pre-baked at the *top*
of `snapshot/agents-block.md`, and setup inserts that whole marker-delimited
block; wherever the pair lands, §11 rides at its head. The first-`## `-anchor
defect cannot occur via setup, and there is no second copy of the rule to drift
against. Building the guard anyway would be a control with nothing to control.

§08 parity for the block's *content* is already enforced by
`check-snapshot-parity.sh`, which diffs `agents-block.md` against this repo's own
extracted block.

`0009` Step 2 does close the one residual in that path: step 9's prose said
"insert at top, after any existing title", and on a region-led file the first
title is GitNexus's own H1 *inside* the region. The prose now requires the pair
to sit above a leading region. Prose-only — it adds no anchor machinery to setup.

Rejected: giving setup a real region-aware anchor awk mirroring the migration so
the parity guard would have something to compare. Structurally strongest, but it
converts a simple marker insertion into anchor machinery it never had — a large
blast radius for a latent defect.

## Consequences

- Projects scaffolded into a gitnexus-led `AGENTS.md` no longer risk silent §11
  loss on the next `gitnexus analyze`.
- Six healthy fleet files take a version-stamp bump and no content change.
- The "is the block in a region" predicate closes each region as its end marker
  is reached rather than comparing against a single remembered start/end, and
  treats an unterminated region as open to EOF. Last-wins bounds report a block
  inside the *first* of two regions as "not in a region"; ignoring open regions
  reports a block inside one as healthy. Both skip the heal and leave the block
  to be eaten, which is the defect this ADR exists to prevent.
- **The heal fails closed when the block has no terminator (state E).** The strip
  is bounded by the block's closing line; with no such line it deleted
  provenance → EOF — region end markers and project content included — at `rc=0`
  with every post-check passing. A migration that silently destroys project
  content is strictly worse than the latent defect it repairs, so this refuses
  rather than guesses. It is state D's class by another route: a block outside
  this migration's management.
- **Fixtures assert preservation and canonicity, not just placement.** A strip
  that ran to EOF still leaves a correctly-placed, singular block, so placement
  assertions pass on total data loss; and §11 is canonical prose, so a
  paraphrasing injector must fail. Both assertions were verified to kill mutants
  that otherwise passed the entire suite. Asserting the *observable outcome*
  rather than the mechanism is what makes these fixtures load-bearing.
- Fixtures **extract and execute** the migration's own shell via `# step1:begin`
  / `# step1:end` sentinels (inert comments in both bash and awk) rather than
  copying it. The prior fixture inlined a copy of `0001`'s awk — a copy tests the
  copy and drifts silently — and is retired in the same change. `0001`/`0004`
  predate the sentinel convention and are immutable, so their shell is extracted
  positionally instead (`extract_fence_after`), always paired with a shape
  assertion so a mis-lock fails loudly rather than passing vacuously.
- `codex-workflow` shares this host's `agents-block.md` shape and carries the
  same naive anchor in its own `0001`/`0004`. Its propagation is tracked
  separately.

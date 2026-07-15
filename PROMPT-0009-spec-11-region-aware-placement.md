# Migration 0009 — make spec §11 block placement GitNexus-region-aware

This is an ADR-0037-pattern propagation of claude-workflow's migration 0029.
The reference design is at (in the claude-workflow repo):

    docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md

Read it first — but note this host's differences, listed at the bottom.

## The defect

The §11 injector anchors the canonical "Coding Discipline" block immediately
before the first `## ` heading in the project's AGENTS.md. That is only a safe
boundary if the heading belongs to project content. In an AGENTS.md that leads
with a GitNexus block, the first `## ` is `## Always Do` — inside
`<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The block is injected into the
region, and the next `gitnexus analyze` regenerates that region and destroys the
block silently.

Two naive-anchor sites in this repo (both `/^## / && !done`):

    migrations/0001-inject-spec-11-coding-discipline.md:91
    migrations/0004-revendor-spec-11.md:77

**Recovery is closed**, which is why this needs a new migration rather than an
edit. The update flow marks a migration pending iff
`installed >= from_version && installed < to_version`. 0001/0004's `to_version`
is long past, so they never replay. Their pre-flight version gate also aborts the
`--migration NNNN` force path. Once the block is eaten it is unrecoverable
without a hand-paste. 0001 and 0004 are immutable — fix forward.

## The anchor rule

> Insert immediately before the first line that is **either** a `## ` heading
> **or** a `<!-- gitnexus:start -->` marker — whichever comes first. EOF if
> neither.

It is a one-alternation delta to the existing awk, so the existing structural
invariant survives: the block is still always followed by a `## ` or EOF, which
is what bounds the managed section for replace/rollback.

**Do NOT use the tempting alternative** "anchor before `gitnexus:start` if a
region exists, else the first `## `". It is wrong. When the region starts late in
the file it drops §11 hundreds of lines down, violating §12's placement advisory
("near the top", "not below long appendices"). The region is only the anchor when
it comes FIRST. In claude-workflow this was caught empirically, not by review —
validate before you adopt.

**Validate the rule before writing the migration.** Strip any existing §11 block
from real AGENTS.md files, re-run the candidate anchor, and confirm it re-derives
the block's CURRENT position exactly (zero churn) on healthy files, and anchors
above the region on a gitnexus-led file. In claude-workflow this check is what
proved the rule safe across 6 repos.

## States to heal

| State | Condition | Behaviour |
|---|---|---|
| A | §11 present, correctly anchored | no-op |
| B | §11 present, **inside** a region | move above the region |
| C | §11 absent | inject at the anchor |
| D | heading present, **no** provenance comment | refuse, `exit 3` — inherit 0001's conflict rule; never overwrite a hand-pasted block |

Idempotency is provenance-based plus a region predicate: skip iff the
current-version provenance is present AND the block is not inside a region.

Do **not** move a healthy block that merely sits somewhere other than the
canonical anchor — no failure mode motivates it and it churns project files.

## This host's facts (verify them; do not trust this prompt)

- **Instruction file:** `AGENTS.md`. §11 currently at L17, GitNexus region
  L240–L282 ⇒ **this host is currently SAFE. The defect here is LATENT, not
  live.** This is a placement fix for projects scaffolded by this host, plus
  self-protection — there is no broken repo to repair (claude-workflow had one;
  you do not).
- **Next migration:** 0009. Last is `0008-fix-plan-review-binding-label.md` (from
  `0.4.0` → `0.4.1`), so use `from_version: 0.4.1`, `to_version: 0.5.0`, with a
  pre-flight gate accepting both.
- **Setup skill:** `skills/setup-opencode-agenticapps-workflow/`. **This host has
  more §11 payload surface than codex-workflow** — the block appears in all four
  of:
  - `snapshot/spec-mirrors/11-coding-discipline-0.4.0.md`
  - `snapshot/agents-block.md`
  - `templates/spec-mirrors/11-coding-discipline-0.4.0.md`
  - `templates/agents-md-additions.md`

  Work out which of these are shipped payload vs. which carry **placement**,
  because a pre-baked block in `agents-block.md` may make the setup path safe by
  construction, or may hardcode the wrong placement. This question is
  deliberately left open — determine it rather than inheriting an outside guess.
  If any setup-side placement logic exists it must carry the identical anchor
  rule and needs a parity guard (spec §08: setup end-state ≡ full replay).
  claude-workflow shipped exactly this drift once (an anchor fix landing in the
  migration but not in setup) and no fixture caught it, because the fixtures only
  ever execute the apply block.
- **Do NOT absorb any spec-version gap in this migration.** `implements_spec`
  appears in many files here with no single authoritative one; resolving that is
  separate work (cf. ADR-0019's "declared paths, not discovered"). Scope this
  strictly to §11 placement.

## Process

Follow this repo's own workflow. Brainstorm the design and get it approved before
writing anything. TDD: fixtures that fail against the naive anchor first (RED),
then the migration (GREEN). Fixtures should **extract the migration's own shell
out of the document** rather than copying it — a fixture that inlines a copy tests
the copy, and the two drift silently.

Cover: gitnexus-led inject, inside-region move, healthy no-op (proves zero
churn), absent instruction file, hand-pasted refusal, and no-heading-EOF.

Feature branch + PR to main; never commit to main. Retire any CHANGELOG "known
issues" entry this closes, and record the anchor decision (including the rejected
alternative above) in an ADR.

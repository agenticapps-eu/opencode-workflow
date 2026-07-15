---
id: 0009
slug: spec-11-region-aware-placement
title: Make spec §11 block placement GitNexus-region-aware (v0.4.1 -> 0.5.0)
from_version: 0.4.1
to_version: 0.5.0
applies_to:
  - AGENTS.md                                              # §11 placement heal
  - skills/setup-opencode-agenticapps-workflow/SKILL.md     # step 9 placement prose
  - skills/agentic-apps-workflow/SKILL.md                   # version bump 0.4.1 -> 0.5.0
  - .opencode/workflow-version.txt                          # record new project version
requires: []
optional_for: []
---

# Migration 0009 — Region-aware §11 placement (v0.4.1 → 0.5.0)

Migration `0001` anchors the canonical §11 "Coding Discipline" block immediately
before the first `## ` heading in `AGENTS.md` (`0001:91`), and `0004` re-injects
it the same way (`0004:77`). That placement was deliberate: it guarantees the
block is followed by a `## ` line, which is what the replace and rollback logic
depends on to bound the managed section.

**It is only a safe boundary if that heading belongs to project content.** In an
`AGENTS.md` that leads with a GitNexus block, the first `## ` is `## Always Do` —
inside `<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The block is injected
*into* the region, and the next `gitnexus analyze` regenerates everything between
the markers and destroys it silently.

Reproduced against a modelled region-led file: the naive anchor placed §11 at L6
of a region spanning L3–L90, and a modelled regeneration removed it with no
diagnostic.

## Why a new migration rather than an edit to 0001/0004

**Recovery is closed.** `$update-opencode-agenticapps-workflow` marks a migration
pending iff `installed >= from_version && installed < to_version`. `0001`'s and
`0004`'s `to_version` are long past, so they never replay for any live project.
Their pre-flight version gates also abort the `--migration NNNN` force path. Once
the block is eaten it is unrecoverable without a hand-paste.

`0001` and `0004` are immutable — they shipped, and their injection is real state
in installed projects. This fixes forward. (Same discipline `0008` applied to
`0007`.)

## Scope note — this host's defect is LATENT, not live

**Corrected 2026-07-15** — the original scan in this document was wrong twice:
it covered only the `agenticapps/` family, and it counted `codex-*` hosts that
this scaffolder does not install. See "Fleet scan — corrected" below. The
conclusion (latent, not live) survives; the reason given for it did not.

The real fleet is every project carrying `.opencode/workflow-version.txt`:

| Project | §11 | Region | Region-led? | Shape |
|---|---|---|---|---|
| `factiv/cparx` | L45 | L1–43 | **YES** | §11 sits **below** the region — outside it |
| `agenticapps/opencode-workflow` | L17 | L240–282 | no | project headings lead the file |
| `agenticapps/bench-opencode` | L5 | none | no | no region |
| `agenticapps/workflow-testbed` | L5 | none | no | no region |

**0 of 4 are affected** — no block is currently inside a region — so the defect is
latent and there is nothing to repair, unlike `claude-workflow`, whose equivalent
`0029` had a live broken repo.

But the reason is **not** "every file has project `## ` headings above its
region". `cparx` is genuinely region-led: its region occupies L1–43 and its first
`## ` is `## Always Do` at **L8, inside the region**. It is safe only because its
§11 landed *below* the region entirely.

`cparx` is therefore the repo this migration exists for. Measured against its
real `AGENTS.md`:

- the naive anchor would place §11 at **L8 — inside the region**, to be destroyed
  by the next `gitnexus analyze`;
- this migration's rule places it at **L1**, above the region.

Any future state-C re-inject in `cparx` hits exactly that. Healthy projects take
a version-stamp bump and no content change; `cparx` took precisely that on
2026-07-15 (state A no-op — §11 left at L45, only the stamp moved).

**Why a minor bump:** no gate is added, removed, or rebound, but the injection
rule that every future project inherits changes. `implements_spec: 0.9.1` is
**not** touched — this migration is scoped strictly to §11 placement, not to any
spec-version gap.

**Supported upgrade floor:** `0.4.1 → 0.5.0`. Projects below 0.4.1 replay the
chain through `0008` first.

## The anchor rule

> Insert immediately before the first line that is **either** a `## ` heading
> **or** a `<!-- gitnexus:start -->` marker — whichever comes first. If neither
> exists, append at EOF.

A one-alternation delta to `0001`'s awk, so `0001`'s structural reasoning
survives: the block is still always followed by a `## ` line or EOF, which is
what bounds the managed section for replace and rollback.

**Validated before this migration was written.** With any existing block
stripped, the rule re-derives the block's current position exactly in every real
fleet file — a true no-op, zero churn.

### Rejected: "before `gitnexus:start` if a region exists, else the first `## `"

The obvious reading of "put it above the region", and wrong. Measured against
this repo's own `AGENTS.md`, whose region starts at L240: §11 would move from L17
to **L159**, violating §12's placement advisory ("near the top", "not below long
appendices"). The region is only the anchor when it comes *first* — which is what
`whichever comes first` encodes, and which is why `cparx` (region at L1) and this
repo (region at L240) both land correctly under one rule.

(The original text measured this against `codex-workflow/AGENTS.md`. The number
was real but the file is a **codex** host, not installed by this scaffolder —
part of the same fleet-scan error corrected above. Re-measured in-fleet; the
conclusion is unchanged.)

## States healed

| State | Condition | Behaviour |
|---|---|---|
| A | §11 present, correctly anchored | no-op |
| B | §11 present, **inside** a region | move above the region |
| C | §11 absent | inject at the anchor |
| D | §11 heading present, **no** provenance comment | refuse, `exit 3` |
| E | provenance present, **no** terminator line | refuse, `exit 3` |

State D inherits `0001`'s conflict rule verbatim: a heading without provenance
means the block was hand-pasted outside this migration's management, and is
refused rather than silently overwritten.

State E is D's class reached by a different route. The strip is bounded by the
block's terminator; with no terminator that bound does not exist and the strip
deletes provenance → EOF — region end markers and project content included —
while every post-check still passes (the re-injected block is fresh, so the
verbatim check trivially holds, and the "not in a region" check passes *because*
the end marker was eaten). Reachable two ways: a hand-edit to the block's tail
that leaves provenance intact, and a future mirror whose closing prose changes —
`PROV_RE` is deliberately version-agnostic, but the terminator is `@0.4.0`'s
prose, so any state-B project would take this path. Refuse rather than destroy.

State B is handled rather than deferred because it is reachable *going forward*,
even though no repo is in it today.

Explicitly **not** handled: a healthy block that sits somewhere other than the
canonical anchor. No failure mode motivates moving it, and doing so would churn
project files gratuitously (Surgical Changes).

Idempotency is provenance-based, as in `0001`, with an added region predicate:
skip iff the current-version provenance is present **and** the block is not
inside a region. That keeps state A a no-op while letting state B re-run.

## Pre-flight

```bash
grep -qE '^version: 0\.(4\.1|5\.0)$' skills/agentic-apps-workflow/SKILL.md \
  || { echo "ABORT: expected scaffolder version 0.4.1 (or 0.5.0 if re-running); replay through 0008 first"; exit 1; }
MIRROR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -f "$MIRROR" || { echo "ABORT: §11 mirror not installed at $MIRROR"; exit 1; }
```

The mirror stays at `@0.4.0` — that is the block's **content** version, unchanged
since it was vendored. It is not the spec version (0.9.1).

## Steps

### Step 1: Heal the §11 block's placement in AGENTS.md

**Idempotency check:** provenance present AND block not inside a region (see the
`block_in_region` predicate below — the check is inlined in the apply block
because it is a two-part condition).
**Pre-condition:** mirror installed (pre-flight).
**Apply:**
```bash
# step1:begin
MIRROR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
# Anchored, and identical to the pattern the awk predicates below use. An
# unanchored matcher also matches prose that merely QUOTES the provenance line
# (e.g. indented inside a fenced example): the shell would then read "block
# present" while the awk predicates, which require a whole line, find nothing —
# so the heal is skipped and §11 is never injected. All three matchers must
# agree on exactly what counts as the provenance line.
PROV_RE='^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$'

if [ ! -f AGENTS.md ]; then
  echo "0009: no AGENTS.md in this project — nothing to place; skipping Step 1."
  exit 0
fi

# Conflict rule (inherited from 0001): a §11 heading with no provenance comment
# is hand-pasted prose outside this migration's management. Refuse it.
if grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md \
   && ! grep -qE "$PROV_RE" AGENTS.md; then
  echo "ABORT: AGENTS.md contains a '## Coding Discipline (NON-NEGOTIABLE)' heading"
  echo "       but no '<!-- spec-source: ... §11 -->' provenance comment. This"
  echo "       migration will not overwrite unmanaged prose."
  echo ""
  echo "  Resolve by hand, then re-run, in ONE of two ways:"
  echo "  (a) DELETE the existing section so this migration injects the managed,"
  echo "      verbatim block under provenance; or"
  echo "  (b) If your section is already byte-identical to the §11 mirror, add"
  echo "      '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->'"
  echo "      immediately above the heading to adopt it as managed."
  exit 3
fi

# Is the managed block currently inside ANY GitNexus-managed region?
# Closed per region as its end marker is reached, rather than comparing against
# a single remembered start/end: with more than one region, last-wins bounds
# would report a block inside the FIRST region as "not in a region", skip the
# heal, and leave it to be eaten — the very defect this migration fixes.
# An UNTERMINATED region counts as open to EOF: anything after its start marker
# is inside it. Treating it as no-region would report the file healthy while
# leaving the block exactly where the next `gitnexus analyze` eats it.
block_in_region() {
  awk '
    /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ { p=NR }
    /^<!-- gitnexus:start -->$/ { rs=NR; open=1 }
    /^<!-- gitnexus:end -->$/   { if (open && p && p > rs && p < NR) inreg=1; open=0 }
    END { if (open && p && p > rs) inreg=1; exit !inreg }
  ' AGENTS.md
}

# The strip below is bounded by the block's terminator line. If a block carries
# provenance but no terminator, that bound does not exist and the strip would
# delete provenance -> EOF, silently destroying the rest of the file (region end
# markers and project content included) while every post-check still passed.
# Fail closed instead: this is state D's class — a block outside this
# migration's management, which it must never silently overwrite.
if grep -qE "$PROV_RE" AGENTS.md && ! awk '
    /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ { f=1; next }
    f && /session-level discipline the model brings to every diff\.$/ { found=1; exit }
    END { exit !found }
  ' AGENTS.md; then
  echo "ABORT: AGENTS.md has a §11 provenance comment but no recognisable end to"
  echo "       the managed block (expected a line ending 'session-level discipline"
  echo "       the model brings to every diff.'). The block was edited by hand, or"
  echo "       the mirror's closing prose changed. Refusing to strip: without that"
  echo "       boundary this would delete everything from the provenance line to"
  echo "       the end of the file."
  echo ""
  echo "  Resolve by hand, then re-run: restore the block's closing line, or"
  echo "  delete the block (and its provenance comment) so it is re-injected."
  exit 3
fi

# Idempotency: skip iff provenance is present AND the block is not in a region.
# State A is a no-op; state B re-runs so the block can be lifted out.
if grep -qE "$PROV_RE" AGENTS.md && ! block_in_region; then
  echo "0009: §11 already present and correctly placed — Step 1 no-op."
  exit 0
fi

# Strip any existing managed block (provenance anchor -> closing line + one blank).
# No-op in state C; in state B this is the "move" half of the heal.
awk '
# strip-rule:begin
  /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ {inblk=1; next}
  inblk && /session-level discipline the model brings to every diff\.$/ {inblk=0; skipblank=1; next}
  inblk {next}
  skipblank && /^$/ {skipblank=0; next}
  {skipblank=0; print}
# strip-rule:end
' AGENTS.md > AGENTS.md.0009.tmp && mv AGENTS.md.0009.tmp AGENTS.md

# Inject at the region-aware anchor: the first '## ' heading OR the first
# '<!-- gitnexus:start -->' marker, WHICHEVER COMES FIRST; EOF if neither.
# The mirror is streamed byte-for-byte (no transcription), so the injected
# block is identical to core spec §11.
awk -v mirror="$MIRROR" '
# anchor-rule:begin
  (/^## / || /^<!-- gitnexus:start -->$/) && !done {
    print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
    while ((getline line < mirror) > 0) print line
    close(mirror)
    print ""
    done=1
  }
  { print }
  END {
    if (!done) {
      print ""
      print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
      while ((getline line < mirror) > 0) print line
      close(mirror)
    }
  }
# anchor-rule:end
' AGENTS.md > AGENTS.md.0009.tmp && mv AGENTS.md.0009.tmp AGENTS.md
# step1:end
```
**Verbatim assertion (post-apply):**
```bash
MIRROR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' AGENTS.md \
  | diff - "$MIRROR" || { echo "injected §11 block is NOT byte-identical to the mirror"; exit 1; }
```
**Rollback:** `git checkout AGENTS.md`.

### Step 2: Make the setup path's placement prose region-aware

The setup path is **structurally unlike `claude-workflow`'s**, and the difference
is load-bearing for this migration's design.

`claude-workflow`'s `setup/SKILL.md` step e2 carries the same naive first-`## `
anchor awk as its migration, which is why its design mandates an `anchor-parity`
guard extracting the awk from both files.

**This host's setup step 9 has no anchor awk at all.** §11 is pre-baked at the
*top* of `snapshot/agents-block.md` (lines 2–3), and setup inserts that whole
marker-delimited block. Wherever the marker pair lands, §11 is at its head, so
the first-`## `-anchor defect **cannot occur via setup**. No `anchor-parity`
guard is built here: there is no second copy of the anchor awk to drift against,
and §08 parity for the block's *content* is already covered by
`check-snapshot-parity.sh`.

**The residual this step closes.** Step 9's prose reads "insert (at top, after
any existing title)". On a region-led `AGENTS.md` the first title is GitNexus's
own `# GitNexus — Code Intelligence` H1 *inside* the region — so the prose admits
an insertion into the region. Same defect class, different mechanism.

**Idempotency check:** `grep -q 'gitnexus' skills/setup-opencode-agenticapps-workflow/SKILL.md`
**Pre-condition:** none — prose edit, inert for installed projects.
**Apply:** in step 9, state that the marker block is inserted at the top after
any existing title **but always above a leading `<!-- gitnexus:start -->` region**
— because a region-led file's first title belongs to GitNexus, not the project,
and anything placed after it is destroyed by the next `gitnexus analyze`.
**Rollback:** `git checkout -- skills/setup-opencode-agenticapps-workflow/SKILL.md`

### Step 3: Bump the scaffolder version

**Idempotency check:** `grep -q '^version: 0.5.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.4.1$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0009.bak -E 's/^version: 0\.4\.1$/version: 0.5.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0009.bak
```
(`implements_spec: 0.9.1` is unchanged — do NOT touch it. This migration fixes
placement, not a conformance claim.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.5\.0$/version: 0.4.1/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.5.0$' .opencode/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.opencode/` exists
**Apply:** `echo "0.5.0" > .opencode/workflow-version.txt`
**Rollback:** `echo "0.4.1" > .opencode/workflow-version.txt`

## Post-checks

```bash
# 1. §11 is present under provenance
grep -qE '<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->' AGENTS.md

# 2. §11 is NOT inside ANY GitNexus region (the whole point of this migration).
# An unterminated region counts as open to EOF — otherwise eating the end marker
# would make this check pass *because* the file was damaged.
awk '
  /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ { p=NR }
  /^<!-- gitnexus:start -->$/ { rs=NR; open=1 }
  /^<!-- gitnexus:end -->$/   { if (open && p && p > rs && p < NR) inreg=1; open=0 }
  END { if (open && p && p > rs) inreg=1
        if (inreg) { print "FAIL: §11 is inside a GitNexus region"; exit 1 } }
' AGENTS.md

# 2b. Region markers are balanced — a strip that ran past its bound would eat an
# end marker, and check 2 would then pass on the wreckage.
test "$(grep -c '^<!-- gitnexus:start -->$' AGENTS.md)" \
   = "$(grep -c '^<!-- gitnexus:end -->$' AGENTS.md)"

# 3. The block is byte-identical to the mirror (Step 1 verbatim assertion)
# 4. Exactly one managed block
test "$(grep -c 'spec-source: agenticapps-workflow-core' AGENTS.md)" -eq 1

# 5. Version stamps agree
grep -q '^version: 0.5.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^0.5.0$' .opencode/workflow-version.txt

# 6. The claim did NOT move — 0009 fixes placement, not conformance
grep -q '^implements_spec: 0.9.1$' skills/agentic-apps-workflow/SKILL.md
```

## Testing

`migrations/run-tests.sh 0009` — six fixtures plus a self-conformance guard. They
**extract and execute this document's own Step 1 shell** (via the
`# step1:begin` / `# step1:end` sentinels — inert comments in both bash and awk)
rather than copying it. A fixture that inlines a copy tests the copy, and the two
drift silently. The extractor carries a shape assertion so a mis-extraction fails
loudly instead of degrading into vacuously-passing fixtures.

| Fixture | Asserts |
|---|---|
| 01 gitnexus-led inject | state C on a region-led file → block above the region; survives a modelled region regeneration |
| 02 inside-region move | state B → block moved above the region, present exactly once |
| 03 healthy no-op | state A → this repo's **real** `AGENTS.md` byte-identical; proves zero churn |
| 04 no AGENTS.md | absent file → informational skip, exit 0 |
| 05 unmanaged conflict | state D → `exit 3`, file untouched |
| 06 no heading/region | no `## `, no region → EOF append |
| 07 two regions | §11 inside the **first** of two regions → lifted out (pins the region predicate against last-wins bounds) |
| 08 no terminator | state E → `exit 3`, file untouched (pins the strip's bound; without it the heal deletes provenance → EOF) |
| 09 unterminated region | §11 after an unclosed `gitnexus:start` → lifted above it, not reported healthy |
| self-conformance | this repo's own §11 sits above its own region |

Fixtures 01/02/07 additionally assert that **non-§11 content is preserved
byte-for-byte**, and 01/02 that the injected block is **byte-identical to the
mirror**. Placement assertions alone cannot see data loss — a strip that ran to
EOF still yields a correctly-placed, singular block — and §11 is canonical prose,
so a paraphrasing injector must fail. Both assertions were verified to kill
mutants that otherwise passed the whole suite.

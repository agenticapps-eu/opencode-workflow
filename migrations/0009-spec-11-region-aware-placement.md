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

RED PLACEHOLDER — this document currently carries the **naive** anchor on
purpose, so the new fixtures execute the pre-fix behaviour and fail. The GREEN
commit replaces the anchor rule and completes the prose.

## Steps

### Step 1: Heal the §11 block's placement in AGENTS.md

**Apply:**
```bash
# step1:begin
MIRROR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills/setup-opencode-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
PROV_RE='<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->'

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
  exit 3
fi

# Is the managed block currently inside a GitNexus-managed region?
block_in_region() {
  awk '
    /^<!-- gitnexus:start -->$/ { rs=NR }
    /^<!-- gitnexus:end -->$/   { re=NR }
    /^<!-- spec-source: agenticapps-workflow-core@[^ ]+ §11 -->$/ { p=NR }
    END { exit !(p && rs && re && p > rs && p < re) }
  ' AGENTS.md
}

# Idempotency: skip iff provenance is present AND the block is not in a region.
if grep -qE "$PROV_RE" AGENTS.md && ! block_in_region; then
  echo "0009: §11 already present and correctly placed — Step 1 no-op."
  exit 0
fi

# Strip any existing managed block (provenance anchor -> closing line + one blank).
awk '
# strip-rule:begin
  /^<!-- spec-source: agenticapps-workflow-core@[^ ]+ §11 -->$/ {inblk=1; next}
  inblk && /session-level discipline the model brings to every diff\.$/ {inblk=0; skipblank=1; next}
  inblk {next}
  skipblank && /^$/ {skipblank=0; next}
  {skipblank=0; print}
# strip-rule:end
' AGENTS.md > AGENTS.md.0009.tmp && mv AGENTS.md.0009.tmp AGENTS.md

# Inject at the anchor.
awk -v mirror="$MIRROR" '
# anchor-rule:begin
  /^## / && !done {
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

**Rollback:** `git checkout AGENTS.md`.

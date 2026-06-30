# ADR-0007 — Fresh installs use a snapshot, not migration replay

**Status:** Accepted (opencode-workflow fork)
**Supersedes (for the setup path):** the core ADR-0013 stance that
"both setup and update route through the same migration files."

## Context

`codex-workflow` and `agenticapps-workflow-core` deliberately use one
code path for both flows: `setup-*` applies `0000-baseline` and then
every incremental migration forward; `update-*` applies the pending
tail. The benefit is a single mechanism. The cost: a brand-new project
re-executes the *entire* migration history to arrive at the current
shape, and every historical migration must stay replayable against an
empty repo forever.

For a fresh project that history is pure overhead — there is no prior
state to migrate. The user reasonably expects "set up the workflow" to
install the **latest** version, not to replay a changelog.

## Decision

Split the two flows by mechanism:

- **Fresh install (`setup-*`) → snapshot.** Ship a `snapshot/`
  directory inside the setup skill holding the current end-state of
  every project-side artifact. Setup copies the snapshot, substitutes
  placeholders, and stamps the scaffolder `VERSION`. No migration is
  executed.
- **Existing install (`update-*`) → migrations.** Unchanged. Read
  `.opencode/workflow-version.txt` and apply only migrations whose
  `from_version >` the installed version.

The scaffolder version lives in a single root `VERSION` file; the
trigger skill frontmatter and the snapshot stamp both track it.

## How the snapshot stays correct

A snapshot can drift from the migration chain (someone adds a migration
but forgets to update `snapshot/`). The drift guard prevents that:

`migrations/check-snapshot-parity.sh` replays `0000-baseline` → latest
onto an empty fixture and diffs the result against `snapshot/`. They
must be byte-identical (modulo documented placeholder regions). CI runs
it on every PR; a mismatch fails the build. This is what makes "skip
replay on fresh install" safe — the snapshot is provably the same
end-state replay would produce.

## Consequences

- Fresh setup is one step and reviewable as a single diff.
- Adding a migration now has a second obligation: update `snapshot/`
  (or regenerate it) so parity holds. The guard enforces this.
- The migration chain is still the source of truth for *upgrades* and
  remains fully replayable; `0000-baseline` is retained as the parity
  anchor, not as the fresh-install path.
- Divergence from core is documented here and in `docs/LINEAGE.md`; if
  core later adopts snapshot installs, this ADR converges with it.

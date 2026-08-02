# ADR-0013: Publish core's artifacts from a pin, not from vendored copies

**Status**: Accepted  **Date**: 2026-07-31  **Linear**: — (core task 8.4; core PR #49 / spec 1.4.0 §20)

## Context

`install.sh` publishes two artifacts into `~/.agenticapps/bin/`, a directory
shared by every AgenticApps agent on the machine: the §18 change-gate and the
review-producer's vendor wrapper. Both are owned by
`agenticapps-workflow-core`. This repo carried byte-copies of them in `bin/`.

Nothing at runtime read those copies. Every consumer — the opencode
`tool.execute.before` plugin, the pre-commit hook, the review-producer skill —
resolves `~/.agenticapps/bin` first and only falls back to a repo-local path.
The copies existed for one reason: to give `install.sh` something to publish.

They drifted, which is what copies do. On 2026-07-31 this repo carried gate
**1.3.1** against core's **2.0.0** and wrapper **1.1.0** against **1.2.0**. It
had missed the release in which reviews stopped blocking, and nothing said so.
Version arbitration meant this was never *destructive* — the installer refuses
to publish a downgrade — but that only made the staleness silent. A fresh
machine installed from this host alone got the old, blocking gate.

The cost was also a re-vendor PR per core release. This repo has already merged
six of them: PRs #16, #17, #18, #19, #20 and #21, each a mechanical diff nobody
reads, each an opportunity to update the gate and forget its harness.

There was a second, sharper reason to move. This host owns
`tools/change-gate-conformance.sh --family`, the sweep that scores **every**
sibling's gate. Once `claude-workflow` stopped vendoring one, the old harness
filtered the missing path away with `[ -f ]` and reported success over one fewer
host — quietly narrower, not visibly broken. The same harness given a missing
path printed `SKIP (not found)`, `TOTAL: 0 passed, 0 failed`, and exited **0**.
A harness that scored nothing looked green.

## Decision

**`install.sh` resolves what it publishes.** `tools/core-vendor.manifest`
records one core commit and a sha256 per file;
`bin/resolve-core-artifact.sh` produces verified bytes from a local checkout at
that commit or from GitHub, and refuses anything that does not hash to the pin.

**It fails closed.** An installer that cannot verify what it is about to write
into a shared directory stops and says so. It does *not* fall back to a copy on
disk — that fallback, run on the day this was written, would have republished
gate 1.3.1 over 2.0.0 for every agent on this machine.

**`bin/` stays, as a CACHE.** This is where this host diverges from
`claude-workflow`, which deleted its copies outright. Six things here want the
artifacts at a stable repo-local path, and one of them is immutable:

| Consumer | Why deleting would break it |
|---|---|
| `migrations/0011-bind-openspec-v1.md` | a **shipped** migration that runs `install -m 0755 bin/openspec-change-gate.sh …`; a project below 1.0.0 would fail mid-replay on a missing file |
| `skills/opencode-openspec-change-review/SKILL.md` | documents `bin/reviewer-cli.sh` as the fallback when the shared path is absent |
| `.github/workflows/openspec-gate.yml` | scores both, then runs the gate |
| `.github/workflows/ci.yml` | `bash -n`s both |
| `migrations/run-tests.sh` | drives the gate through its exit-code truth table |
| `install.sh` | its arbitration regions read the incoming file's version marker |

`bin/materialise-core-artifacts.sh` regenerates those bytes from the pin and
they are **gitignored**. A cached byte cannot drift: a wrong one fails the
resolver's sha256 check and nothing lands. `claude-workflow`'s delete and this
cache are the same decision — core is the source of truth — differing only in
whether a stable path had callers worth keeping.

**Two categories of core-derived file, treated differently:**

| | Files | Committed? | Checked how |
|---|---|---|---|
| RESOLVED | gate, reviewer wrapper | no (cache) | resolved + hash-verified at the pin |
| VENDORED | resolver, 2 conformance harnesses | yes | bytes compared to the pin |

The resolver is the bootstrap and cannot resolve itself; the harnesses are
executed from the repo by CI. Both are pinned regardless, so the manifest's
claim to list *every* file this repo takes from core is true rather than
convenient.

**Five files, not seven.** `claude-workflow` pins two more. This host takes
neither, and pinning a file it does not use would be provenance for nothing:
`run-plan-review.sh` does not exist here — this host's review producer is a
skill that drives the wrapper itself — and `install-shared-artifact.sh` is not
adopted, because `install.sh` carries its own marker-delimited arbitration
regions which the test suite sources by name.

## Alternatives Rejected

**Re-vendor fresh bytes.** Copy core's current gate and wrapper in, bump the
provenance note, leave `install.sh` alone. Cheapest, offline-safe, and it is
what this repo did six times. Rejected because it fixes the bytes and keeps the
mechanism that made them wrong: the seventh PR would be due on the next core
release, and the eighth after that.

**Resolve with a fallback to the vendored copy.** Keeps `install.sh` working
offline with no core checkout. Rejected: the fallback is silent staleness
wearing a warning label. Run on the day this was written it publishes 1.3.1. It
also preserves two sources of truth, which is the condition being removed.

**Delete `bin/` as `claude-workflow` did.** Rejected on the evidence above —
it would require editing a shipped migration, which is the concession claude had
to make to its own migration 0032. A gitignored cache achieves the same
guarantee without touching migration 0011.

## Consequences

- A core release reaches this host by advancing `core_commit` and five sha256s
  — one file, one commit, no re-vendor PR.
- `install.sh` now requires a core checkout beside this repo, `CORE_CHECKOUT`,
  or network access. A real new dependency, accepted deliberately: publishing
  unverified bytes into a shared directory is worse than not publishing.
- **The gate this host installs is now 2.0.0, and reviews no longer block.**
  Only a failing `openspec validate --all` and a missing `openspec` CLI block;
  missing, stale and objecting review evidence are reported. Two rows of the
  truth-table test that pinned BLOCK for an unreviewed change now pin ALLOW.
  That is the adopted upstream behaviour, not a weakened test — the reviewer
  *counting* rows live in the conformance harness, which scores 71/71.
- The §20 harness rewrite arrives with the same pin. `--family` now declares
  `COVERAGE: scored N of M` and reports a pin-and-resolve host as *not
  vendored; resolvable from pin, not attempted*, instead of silently sweeping
  one host fewer.
- Suite went 126 pass / 0 fail → **137 pass / 0 fail**, the extra rows being the
  new pin test and the previously-untested missing-CLI blocking clause.

## Known limits

- **This host's own gate is now invisible to a `--family` sweep on a machine
  where it has not been materialised.** It reports as *resolvable from pin, not
  attempted*, exactly as `claude-workflow` does. That is honest and is what
  `--family --resolve` exists for; it does mean the default sweep scores fewer
  live copies as more hosts adopt the pin.
- **The wider "reviews are advisory" doc sweep is not in this change.**
  `skills/agentic-apps-workflow/SKILL.md`, `docs/ENFORCEMENT-PLAN.md` and
  `skills/update-opencode-agenticapps-workflow/SKILL.md` still describe the ≥2
  reviewer threshold as blocking. They are now wrong about gate 2.0.0. The
  surfaces edited here are the ones that sit beside the command whose behaviour
  changed; the rest is a documented follow-up, mirroring how `claude-workflow`
  split it into its own PR #110.
- **`openspec/specs/opencode-workflow-scaffold/spec.md` still says the gate and
  wrapper are vendored.** Correcting durable spec text is an OpenSpec change,
  not a side effect of this one. `codex-workflow` left the same text standing
  after its port.
- **`OPENSPEC_GATE_SELF=opencode` is left ambient over the conformance step.**
  Verified harmless — 71/71 with and without — because no harness fixture names
  `opencode` as a reviewer. `codex-workflow` must `env -u` it, since one fixture
  does name `codex`. If core ever adds an `opencode` fixture this becomes a
  false red; it is a latent measurement hazard, not a live one.

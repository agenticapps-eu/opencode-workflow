# opencode-workflow-scaffold

## Purpose

The capability this repository ships: installing the AgenticApps OpenSpec +
Superpowers (spec v1.0.0) workflow onto the opencode host, and keeping an
installed project current. This is the scaffolder's own product surface,
reconstructed as its first seed capability (§19).
## Requirements
### Requirement: Change-gate enforces review before code

In every mode (session hook, `--pre-commit`, `--ci`), the change-gate SHALL block
work under an active OpenSpec change until that change both passes
`openspec validate --all` and carries a `REVIEWS.md` with at least two
**independent** reviewer sections, EXCEPT when the documented `GSD_SKIP_REVIEWS=1`
escape hatch is set — which waives only the reviewer clause, never the validate
clause, and does so identically in all three modes (a change whose spec delta
does not validate still blocks even with the hatch set).

Independence is counted strictly: reviewer names are matched case-insensitively
and de-duplicated (so `gemini` and `Gemini` are one reviewer); reviewer headings
inside fenced code blocks (examples/templates) do not count; a YAML `reviewers:`
list does not count at all; and — when `OPENSPEC_GATE_SELF` names the implementing
host — that host's own reviews (name equal to, or prefixed `self-`/`self_`/`self `
against, the configured value) are excluded from the count.

#### Scenario: Edit blocked before review

- **WHEN** a code edit targets a file under an active change whose `REVIEWS.md`
  has fewer than two independent reviewers
- **THEN** the change-gate exits non-zero (block)

#### Scenario: Edit allowed after review

- **WHEN** the active change validates green and carries at least two independent
  reviewers
- **THEN** the change-gate exits zero (allow)

#### Scenario: Duplicate and example reviewers do not satisfy the threshold

- **WHEN** `REVIEWS.md` reaches two headings only by counting a duplicate name, a
  reviewer heading shown inside a fenced example, a bare YAML `reviewers:` list,
  or the implementing host's own review (with `OPENSPEC_GATE_SELF` set)
- **THEN** the change-gate treats the independent count as below two and exits
  non-zero (block)

#### Scenario: Escape hatch waives reviews but not validation

- **WHEN** `GSD_SKIP_REVIEWS=1` is set and the active change validates green but
  lacks two independent reviewers
- **THEN** the change-gate exits zero (allow, logged as an override)
- **AND WHEN** `GSD_SKIP_REVIEWS=1` is set but the active change does not validate
- **THEN** the change-gate exits non-zero (block)

### Requirement: Bind OpenSpec upstream per host

The scaffolder SHALL generate the OpenSpec slot and `/opsx:*` commands with the
upstream CLI (`openspec init --tools opencode --profile core`) rather than
vendoring a hand-maintained copy.

#### Scenario: Fresh install generates the slot

- **WHEN** `install.sh` runs with the openspec CLI available
- **THEN** an `openspec/` slot and the `/opsx:*` commands are generated

### Requirement: OpenSpec-artifact exemption is anchored to the repository root

The change-gate SHALL exempt only writes to artifacts under the repository's
**root** `openspec/` directory. A path is not exempt merely because the string
`openspec/` appears somewhere in it: a nested path (`src/openspec/...`), an
absolute path outside the repo (`/tmp/openspec/...`), and a traversal escape
(`openspec/../src/...`) SHALL each be treated as a normal code edit and gated.

#### Scenario: Root openspec artifact is exempt

- **WHEN** the edited path is under the repository-root `openspec/` (e.g.
  `openspec/changes/<slug>/proposal.md`)
- **THEN** the change-gate exits zero (allow) regardless of review state

#### Scenario: Look-alike paths are not exempt

- **WHEN** the edited path is `src/openspec/x.go`, `/tmp/openspec/x`, or
  `openspec/../src/x` under an unsatisfied active change
- **THEN** the change-gate exits non-zero (block)

### Requirement: Agent-agnostic enforcement floor blocks in pre-commit and CI

When the gate is present, the change-gate SHALL enforce §18 in a git `pre-commit`
invocation and in a CI invocation, not only as a session hook — because a
`PreToolUse`-style hook cannot gate the session that installed it and does not
exist for a human editor. The `pre-commit` wrapper fails **open** with a warning
when no gate is installed (a hard failure would train users to bypass the hook
with `--no-verify`); the floor therefore guarantees enforcement whenever a gate
is resolvable, which the installed workflow ensures.

#### Scenario: Pre-commit blocks unsatisfied change

- **WHEN** `openspec-change-gate.sh --pre-commit` runs with code staged under an
  active change that neither validates nor carries two independent reviewers
- **THEN** it exits non-zero (block the commit)

#### Scenario: Pre-commit allows an artifact-only commit

- **WHEN** `--pre-commit` runs with only root `openspec/**` artifacts staged
- **THEN** it exits zero (allow)

#### Scenario: Pre-commit wrapper fails open when no gate is installed

- **WHEN** the `pre-commit` wrapper runs and no gate is resolvable at the shared
  path or the repo `bin/`
- **THEN** it warns and exits zero (allow) rather than hard-failing — so users are
  never trained to bypass the hook with `--no-verify`

#### Scenario: CI blocks any unsatisfied active change

- **WHEN** `openspec-change-gate.sh --ci` runs, `GSD_SKIP_REVIEWS` is unset, and at
  least one active change does not validate-and-carry two independent reviewers
- **THEN** it exits non-zero (fail the check)

#### Scenario: CI honours the escape hatch identically to the other modes

- **WHEN** `--ci` runs with `GSD_SKIP_REVIEWS=1` and every active change validates
  green but some lack two reviewers
- **THEN** it exits zero (allow — the hatch waives reviews in CI too, validate
  still required)

### Requirement: Gate is vendored from core, and this installer never downgrades the shared copy

The scaffolder SHALL vendor the change-gate and its conformance harness from a
pinned `agenticapps-workflow-core` reference revision (gate-version `1.2.2`)
rather than maintaining a hand-authored copy, and the vendored gate SHALL pass
every row of the vendored conformance harness. Before writing the shared
`~/.agenticapps/bin/openspec-change-gate.sh`, this installer SHALL compare the
installed `# gate-version:` against the incoming one by the rule **installed `>=`
incoming → keep the installed copy; installed `<` incoming → replace it** (an
unmarked or unparseable marker counts as `0.0.0`, and a malformed incoming marker
must never crash the installer). This guarantees only that *this* installer never
downgrades the shared path; machine-wide monotonic upgrades require every host's
installer to implement the same arbitration.

#### Scenario: Vendored gate passes the conformance harness

- **WHEN** `tools/change-gate-conformance.sh bin/openspec-change-gate.sh` runs
- **THEN** every row passes (no `FAIL` rows)

#### Scenario: Installer refuses a downgrade at the shared path

- **WHEN** the installed `# gate-version:` is greater than the incoming one
- **THEN** the installer keeps the installed copy and does not downgrade it

#### Scenario: Installer is a no-op on an equal version

- **WHEN** the installed and incoming `# gate-version:` are equal
- **THEN** the installer leaves the installed copy in place (no downgrade, no
  needless rewrite)

#### Scenario: Installer upgrades an older or unmarked shared copy

- **WHEN** the installed shared gate is older than, or unmarked/unparseable
  relative to, the incoming `# gate-version:`
- **THEN** the installer replaces it with the incoming copy

#### Scenario: Malformed incoming marker does not crash the installer

- **WHEN** the incoming gate carries a malformed `# gate-version:` marker
- **THEN** the installer parses it by the same two-stage rule the reviewer-cli
  arbitration uses — the extractor captures the leading dotted-numeric run and
  the comparator evaluates it as a three-field version, so a marker with no
  leading numeric run (e.g. `abc`) is compared as `0.0.0` while a partial one
  (e.g. `1.x`) is compared as `1.0.0` — and completes without error in every
  case

### Requirement: Reviewer-CLI wrapper is vendored from core, and this installer never downgrades the shared copy

The scaffolder SHALL vendor the §18 review-producer wrapper and its conformance
harness **byte-for-byte** from a pinned `agenticapps-workflow-core` reference
revision (`# reviewer-cli-version: 1.0.0`) rather than maintaining a
hand-authored copy, and the vendored wrapper SHALL pass every row of the
vendored conformance harness. The vendored wrapper SHALL dispatch every vendor
in the canonical set (`claude`, `gemini`, `opencode`, `codex`) — vendor
exclusion is the review producer's responsibility, not the wrapper's, because
the wrapper is installed at the one shared path
`~/.agenticapps/bin/reviewer-cli.sh` that every host calls.

Before writing that shared path, this installer SHALL arbitrate on
`# reviewer-cli-version:` using the **same version extraction and comparison as
the change-gate's `# gate-version:` block** (the marker's leading dotted-numeric
run, compared as up to three numeric fields by a portable pure-bash comparator;
a marker that is absent or does not begin with such a run counts as `0.0.0`; a
malformed marker MUST NOT crash the installer). Applying that comparison, the
installer SHALL: install unconditionally when nothing exists at the destination;
otherwise **keep** the installed copy when its parsed version is `>=` the
incoming one, and **replace** it only when its parsed version is strictly `<` the
incoming one. The guarantee is therefore precisely *this installer never
replaces a copy carrying a greater-or-equal parseable `# reviewer-cli-version:`*,
assuming installers do not run concurrently against the shared path; machine-wide
monotonic upgrades additionally require every host's installer to implement the
same arbitration.

#### Scenario: Vendored wrapper passes the conformance harness

- **WHEN** `tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` runs
- **THEN** every row passes (no `FAIL` rows)

#### Scenario: Every canonical vendor arm is dispatchable

- **WHEN** the wrapper is invoked with each of `claude`, `gemini`, `opencode`,
  and `codex` and a readable prompt file, with that vendor's CLI resolvable on
  `PATH`
- **THEN** each arm dispatches to its vendor CLI without an `unknown vendor`
  error, returning `0` for a present, succeeding CLI — as proven by the
  conformance harness dispatching every arm to a success stub
- **AND** the wrapper's exit contract is `0` on success, `3` on a usage/lookup
  error, a missing prompt file, an absent CLI, or a timeout (`124` mapped to
  `3`, not passed through), and otherwise the vendor CLI's own exit code

#### Scenario: Installer installs when nothing exists at the shared path

- **WHEN** no file exists at `~/.agenticapps/bin/reviewer-cli.sh`
- **THEN** the installer writes the incoming wrapper unconditionally (a first
  install is never a downgrade)

#### Scenario: Installer refuses a downgrade at the shared path

- **WHEN** the installed `# reviewer-cli-version:` is greater than the incoming
  one
- **THEN** the installer keeps the installed copy and does not downgrade it

#### Scenario: Installer is a no-op on an equal version

- **WHEN** the installed and incoming `# reviewer-cli-version:` are equal
- **THEN** the installer leaves the installed copy in place (no downgrade, no
  needless rewrite)

#### Scenario: Installer upgrades an older or unmarked shared copy

- **WHEN** a file exists at the shared path whose parsed `# reviewer-cli-version:`
  is strictly less than the incoming one — including an installed copy that is
  unmarked or unparseable (parsed as `0.0.0`) while the incoming marker is a
  well-formed version greater than `0.0.0`
- **THEN** the installer replaces it with the incoming copy

#### Scenario: Malformed incoming marker is parsed by the leading-numeric-run rule and never crashes

- **WHEN** the incoming wrapper carries a malformed `# reviewer-cli-version:`
  marker
- **THEN** the installer parses it by the gate's two-stage rule — the extractor
  captures the leading dotted-numeric run and the comparator evaluates it as a
  three-field version — so a marker with no leading numeric run (e.g. `abc`) is
  compared as `0.0.0`, while a partial one (e.g. `1.x`) is compared as `1.0.0`;
  the installer completes without error in every case


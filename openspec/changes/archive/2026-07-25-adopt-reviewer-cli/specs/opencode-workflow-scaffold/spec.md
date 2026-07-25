## MODIFIED Requirements

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

## ADDED Requirements

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

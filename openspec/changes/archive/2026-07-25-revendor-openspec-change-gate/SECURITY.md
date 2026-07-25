# Security review — revendor-openspec-change-gate

Scope: this change re-vendors the §18 change-gate (a security control that prevents
unreviewed/invalidated code from landing) and wires its enforcement floors. Reviewed
as a change to a trust-boundary / request-handling surface.

## Net posture: strengthened

The change closes four **under-enforcement** bypasses that were live before it
(all "allow where §18 requires block"), and adds an integrity control at the shared
install path. No new attack surface is introduced.

| Area | Assessment |
|---|---|
| Enforcement floors (`--pre-commit`, `--ci`) | Previously no-ops (fail-open). Now actually block. Net **+**. |
| `openspec/` exemption | Was matchable by any path containing `openspec/` (`src/openspec/…`, `/tmp/openspec/…`, `..`-escape). Now root-anchored. Closes a path-confusion bypass. Net **+**. |
| Reviewer counting | Was gameable (duplicate/example/self headings). Now dedup + fence-skip + self-exclusion. Closes a review-forgery bypass. Net **+**. |
| Escape hatch (`GSD_SKIP_REVIEWS=1`) | Unchanged behaviour; documented and **logged** (`ALLOW (GSD_SKIP_REVIEWS=1 override)`), never silent. Still requires validate-green. No new exposure. |
| Shared-path integrity (`~/.agenticapps/bin/…`) | New downgrade-refusal in `install.sh` removes this host as a source of silent downgrade of a security control. Net **+** (bounded — see below). |

## Considered risks

- **Supply chain — vendored from a sibling checkout.** `bin/openspec-change-gate.sh`
  and `tools/change-gate-conformance.sh` are copied from a local
  `agenticapps-workflow-core` checkout. Integrity is defended in depth: a
  `# gate-version:` marker, a `cmp` byte-parity check recorded in the PR, and the CI
  `openspec-gate` workflow re-scores the gate with the harness on every push — a
  tampered or drifted gate fails CI before it can certify anything.
- **CI workflow injection.** `.github/workflows/openspec-gate.yml` runs only fixed
  scripts; no `github.event.*` / `head_ref` untrusted input reaches any `run:`.
  No injection surface.
- **`OPENSPEC_GATE_SELF` as awk regex (inherited constraint).** Core's gate
  interpolates this value into an awk regex; a host name with regex metacharacters
  would not anchor. This host sets it to the bare token `opencode` (no
  metacharacters) at every injection point, so the constraint cannot bite here.
  Documented in core's gate README §Known constraint.
- **Env-injection scope.** `OPENSPEC_GATE_SELF` carries no secret — it is a public
  host identifier. The plugin spreads `...process.env` before overriding only that
  one key, so no environment is dropped or leaked.

## Residual / disclosed

- **Downgrade-refusal is per-installer, not fleet-wide.** This installer will not
  itself downgrade the shared gate, but a co-installed host whose installer lacks
  the same arbitration can still overwrite the shared path. This is disclosed in the
  spec requirement, the proposal, and ADR-0011, and tracked fleet-wide in core#34.
  It is a *reduction* of the pre-existing hazard, not a full closure.
- **`--no-verify` / kill switches remain.** `git commit --no-verify`,
  `OPENSPEC_GATE_DISABLED=1` (plugin), and the missing-gate fail-open are retained
  by design — §18's stated posture is that a hard-failing floor trains users to
  disable it. The CI floor (which no local config bypasses) is the backstop.

Verdict: **APPROVE** — a security-positive change; residuals are disclosed and
tracked, none regress the prior posture.
